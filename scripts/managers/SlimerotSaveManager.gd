extends Node

signal save_failed(message: String)
signal snapshot_applied(previous_active_play_seconds: float)
signal offline_summary_ready(summary: Dictionary)
var save_path := "user://Slimerot-save.json"
var elapsed := 0.0
var enabled := true
var last_error := ""
var last_saved_at := "Not saved yet"
var generation := 0
var recovery_status := ""
var application_paused := false
var focus_lost := false
var writing := false
var offline_processing := false
var offline_commit_pending := false
var last_offline_summary: Dictionary = {}
var offline_retry_seconds := 0.0

func _ready() -> void:
	# Slimerot's standalone developer estimator must never load or write a player save.
	if OS.is_debug_build() and "--slimerot-estimate" in OS.get_cmdline_user_args():
		enabled = false
		set_process(false)
		return
	if OS.is_debug_build() and "--slimerot-test" in OS.get_cmdline_user_args():
		# Test saves are isolated from player data and work in restricted CI sandboxes.
		save_path = "res://.godot/Slimerot-test-%d.json" % OS.get_process_id()
	if OS.is_debug_build() and "--slimerot-restart-probe" in OS.get_cmdline_user_args():
		save_path = "res://.godot/Slimerot-restart.json"
	if OS.is_debug_build() and "--slimerot-offline-restart-probe" in OS.get_cmdline_user_args():
		save_path = "res://.godot/Slimerot-offline-restart.json"
	load_game()
	GameState.critical_change.connect(func(_reason):
		if not offline_processing: save_game())
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	# Only actual launches/resume perform catch-up. Explicit load/import remains a
	# pure restore operation, also making migration tools safe and deterministic.
	if enabled and not Array(OS.get_cmdline_user_args()).any(func(argument): return argument in ["--slimerot-test", "--slimerot-restart-probe", "--slimerot-offline-restart-probe"]):
		GameState.suspended = true
		resume_from_background.call_deferred()

func _process(delta: float) -> void:
	if offline_commit_pending:
		offline_retry_seconds += delta
		if offline_retry_seconds >= 1.0 and not application_paused and not focus_lost:
			offline_retry_seconds = 0.0
			commit_offline_progress()
		return
	if not enabled or GameState.is_paused():
		return
	elapsed += delta
	if elapsed >= SlimerotBalance.AUTOSAVE_SECONDS:
		elapsed = 0.0
		save_game()

func snapshot() -> Dictionary:
	var super_trigger := GameState.super_roll_next_trigger
	var stats := SkillTreeManager.derived_stats()
	# Older in-memory fixtures may not yet have initialized their schedule. Capture
	# the derived future boundary without changing live state during a save read.
	if super_trigger == 0 and stats.super_roll and GameState.lifetime_rolls <= SlimerotSaveFormat.MAX_EXACT_INTEGER - int(stats.super_roll_interval):
		super_trigger = RollManager.super_schedule_initial(GameState.lifetime_rolls, int(stats.super_roll_interval))
	return {
		"schema_version": SlimerotBalance.SCHEMA_VERSION,
		"best_ever_effective_rarity": maxi(GameState.best_ever_effective_rarity, discovered_power(InventoryManager.discoveries)),
		"rolls_since_last_power_improvement": GameState.rolls_since_last_power_improvement,
		"shrine_sacrifices": GameState.shrine_sacrifices.duplicate(true),
		"coins": GameState.coins, "rolls_balance": GameState.rolls_balance,
		"lifetime_rolls": GameState.lifetime_rolls, "active_play_seconds": GameState.active_play_seconds,
		"super_roll_next_trigger": super_trigger,
		"last_background_timestamp": GameState.last_background_timestamp,
		"offline_roll_remainder": GameState.offline_roll_remainder,
		"first_roll_completed": GameState.lifetime_rolls > 0,
		"highest_zone_unlocked": GameState.highest_zone_unlocked, "current_zone": GameState.current_zone,
		"dash_unlocked": GameState.dash_unlocked,
		"zone_kill_counts": GameState.zone_kill_counts.duplicate(true),
		"unlocked_gate_flags": GameState.unlocked_gate_flags.duplicate(),
		"potion_inventory": GameState.potion_inventory.duplicate(), "boss_brew_seconds": GameState.boss_brew_seconds,
		"completion_portal_unlocked": GameState.completion_portal_unlocked, "campaign_completed": GameState.campaign_completed,
		"boss_defeated_flags": GameState.boss_defeated_flags.duplicate(true),
		"structure_unlocked_flags": GameState.structure_unlocked_flags.duplicate(true),
		"purchased_skill_node_ids": GameState.purchased_skill_node_ids.duplicate(),
		"roll_skill_spend": GameState.roll_skill_spend.duplicate(),
		"equipped_slot_count": SkillTreeManager.derived_stats().equipped_slots,
		"equipped_copy_ids": InventoryManager.equipped_copy_ids.duplicate(),
		"inventory": InventoryManager.inventory.duplicate(true), "next_copy_id": InventoryManager.next_copy_id,
		"active_potion_type": GameState.active_potion_type if GameState.potion_remaining_seconds > 0 else "",
		"active_potion_remaining_seconds": GameState.potion_remaining_seconds,
		"settings": GameState.settings.duplicate(true),
		"roll_cooldown_remaining": RollManager.cooldown_remaining,
		"discoveries": InventoryManager.discoveries.duplicate(true),
		"coins_earned": GameState.coins_earned, "coins_spent": GameState.coins_spent,
		"rarest_threshold_reached": GameState.rarest_threshold_reached,
		"highest_luck": GameState.highest_luck, "best_team_dps": GameState.best_team_dps,
	}

func save_game() -> bool:
	if not enabled or offline_processing: return false
	if not GameState.suspended and not offline_commit_pending:
		stamp_checkpoint(Time.get_unix_time_from_system())
	return write_snapshot(snapshot())

func stamp_checkpoint(now: float) -> void:
	# The timestamp accompanies every durable state, including an OS kill with no
	# pause callback. Never move the anchor backwards after a wall-clock correction.
	GameState.last_background_timestamp = maxf(GameState.last_background_timestamp, now)
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	GameState.offline_roll_remainder = cooldown - clampf(RollManager.cooldown_remaining, 0.0, cooldown) if RollManager.cooldown_remaining > 0.0 else 0.0

func enter_background(now: float = -1.0) -> bool:
	GameState.suspended = true
	if offline_processing: return false # The existing checkpoint still owns this batch.
	if offline_commit_pending: return commit_offline_progress()
	stamp_checkpoint(Time.get_unix_time_from_system() if now < 0.0 else now)
	return save_game()

func resume_from_background(now: float = -1.0) -> Dictionary:
	if offline_processing or RollManager.completing or application_paused or focus_lost: return {}
	if offline_commit_pending:
		commit_offline_progress()
		return last_offline_summary
	if not enabled:
		GameState.suspended = false
		return {}
	GameState.suspended = true
	var observed_time := Time.get_unix_time_from_system() if now < 0.0 else now
	if not is_finite(observed_time) or observed_time > SlimerotSaveFormat.MAX_EXACT_INTEGER:
		return reject_offline_resume()
	var anchor := GameState.last_background_timestamp
	var away := maxf(0.0, observed_time - anchor) if anchor > 0.0 else 0.0
	var stats := SkillTreeManager.derived_stats()
	var count := 0
	var remainder := GameState.offline_roll_remainder
	var auto_enabled: bool = GameState.settings.auto_roll_state and stats.auto_roll
	if anchor > 0.0 and away > 0.0 and auto_enabled:
		var total: float = away + remainder
		var cycles: float = floor(total / stats.roll_cooldown + 0.000000001)
		var capacity := mini(SlimerotSaveFormat.MAX_EXACT_INTEGER - GameState.lifetime_rolls, SlimerotSaveFormat.MAX_EXACT_INTEGER - InventoryManager.next_copy_id)
		if cycles > capacity: return reject_offline_resume()
		count = int(cycles)
		remainder = maxf(0.0, total - count * stats.roll_cooldown)
		RollManager.cooldown_remaining = stats.roll_cooldown - remainder
	last_offline_summary = {"seconds_away": away, "rolls": 0, "rolls_earned": 0, "new_discoveries": [], "best_drop": {}, "auto_sold_coins": 0, "pending": true}
	offline_processing = true
	if count > 0:
		offline_summary_ready.emit(last_offline_summary.duplicate(true))
		var results: Dictionary = await RollManager.process_offline_rolls(count)
		if int(results.get("rolls", 0)) != count: return reject_offline_resume()
		last_offline_summary.merge(results, true)
	GameState.last_background_timestamp = maxf(anchor, observed_time)
	GameState.offline_roll_remainder = remainder
	offline_processing = false
	offline_commit_pending = true
	commit_offline_progress()
	return last_offline_summary

func reject_offline_resume() -> Dictionary:
	# Preserve the original checkpoint if the clock/count cannot be represented.
	# Never consume an interval for which the complete batch was not committed.
	offline_processing = false
	offline_commit_pending = false
	enabled = false
	GameState.suspended = application_paused or focus_lost
	last_offline_summary.clear()
	fail("Slimerot could not safely calculate offline progress. The previous save was preserved; check the device clock and reopen.")
	return {}

func commit_offline_progress() -> bool:
	# Rewards and the consumed timestamp share one checksummed generation. If the
	# write fails, keep gameplay paused and retry this state, never re-roll the batch.
	if not enabled or not write_snapshot(snapshot()): return false
	offline_commit_pending = false
	last_offline_summary.pending = false
	GameState.suspended = application_paused or focus_lost
	GameState.changed.emit()
	if last_offline_summary.get("seconds_away", 0.0) >= 1.0 or last_offline_summary.get("rolls", 0) > 0:
		offline_summary_ready.emit(last_offline_summary.duplicate(true))
	return true

func write_snapshot(data: Dictionary) -> bool:
	if not enabled or writing:
		return false
	if not validate(data): return fail("Slimerot save state is invalid. Previous progress was preserved.")
	writing = true
	var result := commit_snapshot(data)
	writing = false
	return result

func commit_snapshot(data: Dictionary) -> bool:
	var temporary := save_path + ".tmp"
	var backup := save_path + ".bak"
	# Refuse to overwrite a newer schema, even if it appeared after startup.
	var reset_marker := read_candidate(save_path + ".reset")
	var main_valid := false
	for suffix in SlimerotSaveFormat.SUFFIXES:
		var existing := SlimerotSaveFormat.read(save_path + suffix)
		if is_future(existing) and not superseded_by_reset(existing, reset_marker):
			enabled = false
			return fail("This Slimerot save requires a newer version. Saving is disabled to protect it.")
		if not existing.is_empty(): generation = maxi(generation, int(existing.generation))
		if suffix == "": main_valid = not validated_candidate(existing).is_empty()
	var next_generation := generation + 1
	if not SlimerotSaveFormat.write(temporary, SlimerotSaveFormat.encode(data, next_generation)):
		return fail("Slimerot could not finish writing the save.")
	if read_candidate(temporary).is_empty(): return fail("Slimerot could not verify the temporary save.")
	# Only a validated main may replace the known-good backup. At every boundary
	# a complete main, temporary or backup remains available to recovery.
	if main_valid:
		if DirAccess.rename_absolute(save_path, backup) != OK:
			return fail("Slimerot could not preserve the previous save.")
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		return fail("Slimerot could not replace the main save.")
	generation = next_generation
	elapsed = 0.0
	last_error = ""
	last_saved_at = Time.get_time_string_from_system()
	return true

func fail(message: String) -> bool:
	last_error = message
	push_warning(message)
	save_failed.emit(message)
	return false

func load_game() -> bool:
	var best: Dictionary = {}
	var found := false
	var reset_marker := read_candidate(save_path + ".reset")
	for suffix in SlimerotSaveFormat.SUFFIXES:
		var path: String = save_path + suffix
		if not FileAccess.file_exists(path):
			continue
		found = true
		var candidate := SlimerotSaveFormat.read(path)
		if is_future(candidate) and not superseded_by_reset(candidate, reset_marker):
			enabled = false
			return fail("This Slimerot save requires a newer version. Saving is disabled to protect it.")
		candidate = validated_candidate(candidate)
		if not candidate.is_empty() and (best.is_empty() or candidate.generation > best.generation):
			best = candidate
			best.path = path
	if not best.is_empty():
		generation = int(best.generation)
		apply_snapshot(best.state)
		elapsed = 0.0
		last_error = ""
		last_saved_at = "Loaded local save"
		recovery_status = ""
		if best.path != save_path:
			recovery_status = "Recovered local save"
			# Copy to a separate staging file so the recovery source survives a crash.
			var recovery := save_path + ".recover"
			if best.path != recovery and DirAccess.copy_absolute(best.path, recovery) != OK:
				fail("Slimerot loaded recovered progress but could not restore the main file.")
			elif read_candidate(recovery).is_empty() or DirAccess.rename_absolute(recovery, save_path) != OK:
				fail("Slimerot loaded recovered progress but could not restore the main file.")
		return true
	if found:
		enabled = false
		fail("Slimerot could not recover this save. Files were preserved; saving is disabled.")
	return false

func is_future(candidate: Dictionary) -> bool:
	return not candidate.is_empty() and SlimerotSaveFormat.integer(candidate.state.get("schema_version")) and candidate.state.schema_version > SlimerotBalance.SCHEMA_VERSION

func superseded_by_reset(candidate: Dictionary, marker: Dictionary) -> bool:
	# Only the durable marker from an explicitly confirmed reset supersedes a newer
	# schema. Ordinary lower-version saves must never authorize such a downgrade.
	return not marker.is_empty() and not marker.state.first_roll_completed and marker.generation > candidate.generation

func read_candidate(path: String) -> Dictionary:
	return validated_candidate(SlimerotSaveFormat.read(path))

func validated_candidate(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty(): return {}
	var state: Variant = migrate(candidate.state)
	if not validate(state): return {}
	candidate.state = state
	return candidate

func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema_version") != SlimerotBalance.SCHEMA_VERSION:
		return false
	if not validate_rng_state(data): return false
	if not data.get("first_roll_completed") is bool: return false
	if not data.get("dash_unlocked") is bool: return false
	for key in ["last_background_timestamp", "offline_roll_remainder"]:
		if (not data.get(key) is float and not data.get(key) is int) or not is_finite(float(data[key])) or data[key] < 0: return false
	if data.offline_roll_remainder > SlimerotBalance.ROLL_COOLDOWN: return false
	if data.last_background_timestamp > SlimerotSaveFormat.MAX_EXACT_INTEGER: return false
	if not data.get("potion_inventory") is Dictionary or not data.get("completion_portal_unlocked") is bool or not data.get("campaign_completed") is bool: return false
	if (not data.get("boss_brew_seconds") is float and not data.get("boss_brew_seconds") is int) or not is_finite(float(data.boss_brew_seconds)) or data.boss_brew_seconds < 0 or data.boss_brew_seconds > 300: return false
	for id in data.potion_inventory:
		var count: Variant = data.potion_inventory[id]
		if not SlimerotEncounters.POTIONS.has(id) or (not count is float and not count is int) or not is_finite(float(count)) or count < 0 or count != floor(float(count)): return false
	for key in ["coins", "rolls_balance", "lifetime_rolls", "active_play_seconds", "highest_zone_unlocked", "current_zone", "next_copy_id", "active_potion_remaining_seconds", "roll_cooldown_remaining", "coins_earned", "coins_spent", "rarest_threshold_reached", "highest_luck", "best_team_dps"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
		if not is_finite(float(data[key])) or data[key] < 0:
			return false
	for key in ["coins", "rolls_balance", "lifetime_rolls", "highest_zone_unlocked", "current_zone", "next_copy_id", "coins_earned", "coins_spent", "rarest_threshold_reached"]:
		if not SlimerotSaveFormat.integer(data[key]):
			return false
	if data.highest_luck < 1.0 or data.next_copy_id < 1 or data.first_roll_completed != (data.lifetime_rolls > 0):
		return false
	if not data.get("active_potion_type") is String: return false
	if data.active_potion_remaining_seconds > SlimerotEncounters.POTION_SECONDS: return false
	if data.active_potion_remaining_seconds == 0:
		if data.active_potion_type != "": return false
	elif data.active_potion_type not in ["lucky_soda", "hyper_soda"]: return false
	if data.rolls_balance > data.lifetime_rolls or data.current_zone > data.highest_zone_unlocked or data.highest_zone_unlocked < 1 or data.highest_zone_unlocked > SlimerotBalance.MAX_ZONE:
		return false
	for key in ["zone_kill_counts", "boss_defeated_flags", "structure_unlocked_flags", "unlocked_gate_flags", "inventory", "settings", "discoveries", "roll_skill_spend"]:
		if not data.get(key) is Dictionary:
			return false
	for zone in data.zone_kill_counts:
		if zone not in ["1", "2", "3", "4", "5", "6", "7", "8"]: return false
	for zone in data.unlocked_gate_flags:
		if zone not in ["1", "2", "3", "4", "5", "6", "7", "8"]: return false
	for flag in data.boss_defeated_flags:
		if flag not in ["zone_2", "zone_4", "zone_6", "zone_8"]: return false
	for flag in data.structure_unlocked_flags:
		if not WorldManager.structures.has(flag): return false
	for count in data.zone_kill_counts.values():
		if (not count is float and not count is int) or not is_finite(float(count)) or float(count) < 0 or float(count) != floor(float(count)):
			return false
	for key in ["boss_defeated_flags", "structure_unlocked_flags", "unlocked_gate_flags"]:
		for flag in data[key].values():
			if not flag is bool:
				return false
	if not data.get("purchased_skill_node_ids") is Array or not data.get("equipped_copy_ids") is Array or not data.get("active_potion_type") is String:
		return false
	var unique_nodes: Array = []
	for id in data.purchased_skill_node_ids:
		if not id is String or id.is_empty() or id in unique_nodes:
			return false
		unique_nodes.append(id)
		# Unknown historical IDs remain inert, preserving progress and any recorded
		# spend without pretending that the current tree supplies their effects.
		if not SkillTreeManager.nodes.has(id): continue
		for prerequisite in SkillTreeManager.nodes[id].prerequisite_ids:
			if prerequisite not in data.purchased_skill_node_ids and not grandfathered_luck_i(data, id, prerequisite): return false
	var recorded_spend := 0
	for id in data.roll_skill_spend:
		if not id is String or id.is_empty() or id not in data.purchased_skill_node_ids: return false
		if SkillTreeManager.nodes.has(id) and SkillTreeManager.nodes[id].currency_type != "Rolls": return false
		var paid: Variant = data.roll_skill_spend[id]
		if not SlimerotSaveFormat.integer(paid): return false
		if int(paid) > SlimerotSaveFormat.MAX_EXACT_INTEGER - recorded_spend: return false
		recorded_spend += int(paid)
		if SkillTreeManager.nodes.has(id):
			var maximum_paid: int = maxi(SkillTreeManager.nodes[id].cost, 75 if id == "R03" else 0)
			if paid > maximum_paid: return false
	for id in data.purchased_skill_node_ids:
		if SkillTreeManager.nodes.has(id) and SkillTreeManager.nodes[id].currency_type == "Rolls" and not data.roll_skill_spend.has(id): return false
	if int(data.lifetime_rolls) != int(data.rolls_balance) + SkillTreeManager.rolls_spent(data.purchased_skill_node_ids, data.roll_skill_spend):
		return false
	if not validate_super_roll_state(data): return false
	if not InventoryManager.validate_saved_inventory(data.inventory, data.equipped_copy_ids, data.next_copy_id).is_empty(): return false
	for id in data.discoveries:
		if not SlimeDatabase.slimes.has(id) or not data.discoveries[id] is Array:
			return false
		for variant in data.discoveries[id]:
			if variant not in SlimerotBalance.VARIANTS:
				return false
	for pair in data.inventory.values():
		if pair.quantity > 0 and pair.variant not in data.discoveries.get(pair.slime_id, []):
			return false
	# Capacity is derived; identity/protection validation supports compact stacks.
	if data.equipped_copy_ids.size() > SkillTreeManager.derived_stats(data.purchased_skill_node_ids).equipped_slots: return false
	if data.lifetime_rolls == 0:
		for pair in data.inventory.values():
			if pair.quantity > 0: return false
	if not SlimerotSaveFormat.integer(data.get("equipped_slot_count")) or data.equipped_slot_count != SkillTreeManager.derived_stats(data.purchased_skill_node_ids).equipped_slots: return false
	for key in SlimerotBalance.SETTINGS:
		if not data.settings.has(key):
			continue
		if SlimerotBalance.SETTINGS[key] is float:
			if (not data.settings[key] is float and not data.settings[key] is int) or not is_finite(float(data.settings[key])): return false
		elif typeof(data.settings[key]) != typeof(SlimerotBalance.SETTINGS[key]): return false
	for key in ["master_audio", "music_audio", "sfx_audio"]:
		if data.settings.get(key, 1.0) < 0 or data.settings.get(key, 1.0) > 1: return false
	if data.settings.get("luck_cap", 0.0) not in SlimerotBalance.LUCK_CAPS.values():
		return false
	var filters: Variant = data.settings.get("auto_sell_settings", {})
	if not filters is Dictionary or not filters.get("enabled") is bool: return false
	if not filters.get("threshold") is int and not filters.get("threshold") is float: return false
	if not is_finite(float(filters.threshold)) or float(filters.threshold) != floor(float(filters.threshold)): return false
	if int(filters.threshold) not in InventoryManager.auto_sell_thresholds(data.purchased_skill_node_ids, data.discoveries): return false
	return true

func apply_snapshot(data: Dictionary) -> void:
	# Rebuild from authoritative fields; never multiply the previous runtime stats.
	var previous_active_play_seconds := GameState.active_play_seconds
	RollManager.reset()
	GameState.coins = int(data.coins)
	GameState.rolls_balance = int(data.rolls_balance)
	GameState.lifetime_rolls = int(data.lifetime_rolls)
	GameState.super_roll_next_trigger = int(data.super_roll_next_trigger)
	GameState.best_ever_effective_rarity = int(data.best_ever_effective_rarity)
	GameState.rolls_since_last_power_improvement = int(data.rolls_since_last_power_improvement)
	GameState.shrine_sacrifices = data.shrine_sacrifices.duplicate(true)
	GameState.active_play_seconds = float(data.active_play_seconds)
	GameState.last_background_timestamp = float(data.last_background_timestamp)
	GameState.offline_roll_remainder = float(data.offline_roll_remainder)
	offline_commit_pending = false
	last_offline_summary.clear()
	GameState.highest_zone_unlocked = int(data.highest_zone_unlocked)
	GameState.dash_unlocked = data.get("dash_unlocked", GameState.highest_zone_unlocked >= 2)
	GameState.current_zone = int(data.current_zone)
	GameState.zone_kill_counts = data.zone_kill_counts.duplicate(true)
	GameState.unlocked_gate_flags = data.unlocked_gate_flags.duplicate()
	GameState.potion_inventory = data.potion_inventory.duplicate()
	GameState.boss_brew_seconds = float(data.boss_brew_seconds)
	GameState.completion_portal_unlocked = data.completion_portal_unlocked
	GameState.campaign_completed = data.campaign_completed
	GameState.boss_defeated_flags = data.boss_defeated_flags.duplicate(true)
	GameState.structure_unlocked_flags = data.structure_unlocked_flags.duplicate(true)
	GameState.purchased_skill_node_ids.assign(data.purchased_skill_node_ids)
	GameState.roll_skill_spend = data.roll_skill_spend.duplicate()
	GameState.active_potion_type = data.active_potion_type
	GameState.potion_remaining_seconds = float(data.active_potion_remaining_seconds)
	GameState.settings = SlimerotBalance.SETTINGS.duplicate(true)
	GameState.settings.merge(data.settings, true)
	InventoryManager.inventory = data.inventory.duplicate(true)
	InventoryManager.compact_inventory()
	InventoryManager.invalidate_lookup_cache()
	InventoryManager.equipped_copy_ids.assign(data.equipped_copy_ids)
	InventoryManager.next_copy_id = int(data.next_copy_id)
	InventoryManager.discoveries = data.discoveries.duplicate(true)
	GameState.coins_earned = int(data.coins_earned)
	GameState.coins_spent = int(data.coins_spent)
	GameState.rarest_threshold_reached = int(data.rarest_threshold_reached)
	GameState.highest_luck = float(data.highest_luck)
	GameState.best_team_dps = float(data.best_team_dps)
	RollManager.cooldown_remaining = minf(float(data.roll_cooldown_remaining), SkillTreeManager.derived_stats().roll_cooldown)
	GameState.player_hp = SkillTreeManager.derived_stats().max_hp
	CombatManager.reset_combat()
	WorldManager.boss_active = false
	WorldManager.arriving_from_next = false
	# Slimerot observers baseline the loaded state before old arena nodes exit.
	snapshot_applied.emit(previous_active_play_seconds)
	WorldManager.zone_changed.emit(GameState.current_zone)
	GameState.changed.emit()

func migrate(value: Variant) -> Variant:
	var data: Variant = migrate_versioned(value)
	# Dash is an additive flag in schema 11. An older save that already reached
	# Espresso's zone receives the free tutorial ability without losing progress.
	if data is Dictionary and data.get("schema_version") == SlimerotBalance.SCHEMA_VERSION and not data.has("dash_unlocked"):
		if not SlimerotSaveFormat.integer(data.get("highest_zone_unlocked")): return {}
		data = data.duplicate(true)
		data.dash_unlocked = data.highest_zone_unlocked >= 2
	return data

func migrate_versioned(value: Variant) -> Variant:
	if not value is Dictionary or not SlimerotSaveFormat.integer(value.get("schema_version")): return value
	var version := int(value.schema_version)
	if version == 10: return migrate_progression(value)
	if version == 9: return migrate_progression(migrate_rng(value))
	if version not in [1, 2, 3, 4, 5, 6, 7, 8]: return value
	value = value.duplicate(true)
	value.schema_version = version
	# Guard every legacy container before any migration dereferences it.
	for key in ["inventory", "settings", "boss_defeated_flags", "structure_unlocked_flags"]:
		if not value.get(key) is Dictionary: return {}
	for key in ["discoveries", "roll_skill_spend", "zone_kill_counts", "unlocked_gate_flags", "potion_inventory"]:
		if value.has(key) and not value[key] is Dictionary: return {}
	if not value.get("purchased_skill_node_ids") is Array: return {}
	for id in value.purchased_skill_node_ids:
		if not id is String: return {}
	for key in ["coins", "rolls_balance", "lifetime_rolls", "highest_zone_unlocked"]:
		if not SlimerotSaveFormat.integer(value.get(key)): return {}
	for pair in value.inventory.values():
		if not pair is Dictionary or not pair.get("slime_id") is String or not pair.get("variant") is String or not pair.get("copy_ids") is Array: return {}
	var data: Dictionary = migrate_legacy(value).duplicate(true)
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
	data.first_roll_completed = data.lifetime_rolls > 0
	data.equipped_slot_count = SkillTreeManager.derived_stats(data.purchased_skill_node_ids).equipped_slots
	# Historical saves may contain stale expired potion labels. The recipe is authority.
	if data.get("active_potion_remaining_seconds") == 0: data.active_potion_type = ""
	data.erase("active_potion_multiplier")
	var settings: Dictionary = SlimerotBalance.SETTINGS.duplicate(true)
	settings.merge(data.settings, true)
	data.settings = settings
	data.last_background_timestamp = 0.0
	data.offline_roll_remainder = 0.0
	for pair in data.inventory.values():
		pair["copy_ranges"] = []
		pair["favorite_copy_ranges"] = []
	return migrate_progression(migrate_rng(data))

func migrate_legacy(value: Variant) -> Variant:
	if not value is Dictionary or value.get("schema_version") not in [1, 2, 3, 4, 5]:
		return value
	var data: Dictionary = value.duplicate(true)
	data.potion_inventory = {}
	data.boss_brew_seconds = 0.0
	data.completion_portal_unlocked = data.get("boss_defeated_flags",{}).get("zone_8",false)
	data.campaign_completed = false
	if data.schema_version == 5:
		data.schema_version = SlimerotBalance.SCHEMA_VERSION
		return data
	data.unlocked_gate_flags = {}
	var highest: Variant = data.get("highest_zone_unlocked",1)
	if highest is int or highest is float:
		for zone in range(1,clampi(int(highest),1,8)): data.unlocked_gate_flags[str(zone)] = true
	if data.schema_version == 4:
		data.schema_version = SlimerotBalance.SCHEMA_VERSION
		return data
	if not data.get("inventory") is Dictionary or not data.get("purchased_skill_node_ids") is Array:
		return data
	if data.schema_version == 3: return migrate_coin_tree(data)
	if data.schema_version == 2:
		return migrate_roll_tree(data)
	data.schema_version = 2
	data.discoveries = {}
	data.active_potion_multiplier = 1.0
	data.coins_earned = data.get("coins", 0)
	data.coins_spent = 0
	data.rarest_threshold_reached = 0
	data.highest_luck = 1.0
	data.best_team_dps = 0.0
	# Reconstruct stage-one spend counters from the only Coin sinks that existed.
	for structure in WorldManager.structures.values():
		if data.get("structure_unlocked_flags", {}).get(structure.unlock_flag, false):
			data.coins_spent += structure.coin_cost
	for id in data.purchased_skill_node_ids:
		if SlimerotCoinTree.LEGACY_COSTS.has(id): data.coins_spent += SlimerotCoinTree.LEGACY_COSTS[id]
		if SkillTreeManager.nodes.has(id) and SkillTreeManager.nodes[id].currency_type == "Coins":
			data.coins_spent += SkillTreeManager.nodes[id].cost
	data.coins_earned += data.coins_spent
	data.highest_luck = SkillTreeManager.derived_stats(data.purchased_skill_node_ids).luck
	for pair in data.inventory.values():
		if not pair is Dictionary or not pair.get("copy_ids") is Array or not pair.get("slime_id") is String or not pair.get("variant") is String:
			return data
		pair.favorite_copy_ids = pair.copy_ids.duplicate() if pair.get("favorite", false) else []
		if pair.copy_ids.size() > 0 and SlimeDatabase.slimes.has(pair.slime_id):
			if not data.discoveries.has(pair.slime_id): data.discoveries[pair.slime_id] = []
			data.discoveries[pair.slime_id].append(pair.variant)
			data.rarest_threshold_reached = maxi(data.rarest_threshold_reached, SlimeDatabase.get_slime(pair.slime_id).rarity_threshold)
	return migrate_roll_tree(data)

func migrate_roll_tree(data: Dictionary) -> Dictionary:
	if not data.get("purchased_skill_node_ids") is Array or not data.get("settings") is Dictionary: return data
	data = migrate_coin_tree(data)
	var purchased_ids: Array[String] = []
	var paid_costs: Dictionary = {}
	for old_id in data.purchased_skill_node_ids:
		if not old_id is String: return data
		var id: String = SlimerotRollTree.LEGACY_NODES.get(old_id, {}).get("id", old_id)
		if id not in purchased_ids: purchased_ids.append(id)
		if not SkillTreeManager.nodes.has(id):
			if data.get("roll_skill_spend", {}).has(old_id): paid_costs[id] = data.roll_skill_spend[old_id]
			continue
		if SkillTreeManager.nodes[id].currency_type == "Rolls":
			var historical_cost: int = 40 if id == "R02" else 75 if id == "R03" else SkillTreeManager.nodes[id].cost
			paid_costs[id] = SlimerotRollTree.LEGACY_NODES.get(old_id, {}).get("paid", data.get("roll_skill_spend", {}).get(id, historical_cost))
		if SlimerotRollTree.LEGACY_NODES.has(old_id):
			# Grandfather the required ancestors, preserving an already unlocked Auto Roll.
			# Neither wallet nor Lifetime Rolls changes; the ledger records historical spend.
			for number in range(1, int(id.trim_prefix("R"))):
				var prerequisite := "R%02d" % number
				if prerequisite not in purchased_ids: purchased_ids.append(prerequisite)
				if not paid_costs.has(prerequisite): paid_costs[prerequisite] = 0
	data.purchased_skill_node_ids = purchased_ids
	data.roll_skill_spend = paid_costs
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
	if not data.settings.get("auto_sell_settings", {}) is Dictionary: return data
	data.settings.auto_sell_settings = {"enabled": false, "threshold": SlimerotRollTree.DEFAULT_SELL_THRESHOLD}
	return data

func migrate_coin_tree(data: Dictionary) -> Dictionary:
	var ids: Array = []
	for old_id in data.purchased_skill_node_ids:
		var id: Variant = SlimerotCoinTree.LEGACY_SLOTS.get(old_id, old_id)
		if id not in ids: ids.append(id)
		if SlimerotCoinTree.LEGACY_SLOTS.has(old_id):
			# Preserve legacy team capacity without charging for newly added ancestors.
			var pending: Array = [id]
			while not pending.is_empty():
				var current: String = pending.pop_back()
				for prerequisite in SkillTreeManager.nodes[current].prerequisite_ids:
					if prerequisite not in ids:
						ids.append(prerequisite)
						pending.append(prerequisite)
	data.purchased_skill_node_ids = ids
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
	return data

func reset_save() -> bool:
	# Called only by the hold-to-confirm settings control; never by a roll or a load failure.
	if offline_processing or offline_commit_pending: return false
	# Commit a durable reset marker first. Recovery then cannot resurrect old progress
	# if the process dies between replacing the main and clearing its older backup.
	var previous := snapshot()
	var was_enabled := enabled
	enabled = false
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	last_offline_summary.clear()
	offline_retry_seconds = 0.0
	var fresh := snapshot()
	for suffix in SlimerotSaveFormat.SUFFIXES:
		var candidate := SlimerotSaveFormat.read(save_path + suffix)
		if not candidate.is_empty(): generation = maxi(generation, int(candidate.generation))
	generation += 1
	var marker := save_path + ".reset"
	if not SlimerotSaveFormat.write(marker, SlimerotSaveFormat.encode(fresh, generation)) or read_candidate(marker).is_empty():
		apply_snapshot(previous)
		enabled = was_enabled
		return fail("Slimerot could not commit the reset. Previous progress was preserved.")
	# The marker is now the authoritative new save even if later housekeeping fails.
	for suffix in ["", ".tmp", ".bak", ".recover"]:
		if FileAccess.file_exists(save_path + suffix):
			if DirAccess.remove_absolute(save_path + suffix) != OK:
				enabled = false
				WorldManager.travel(0)
				return fail("Slimerot reset was committed, but old save files could not be cleared. Restart to recover the reset.")
	enabled = true
	var saved := save_game()
	if saved:
		DirAccess.copy_absolute(save_path, save_path + ".bak")
		DirAccess.remove_absolute(marker)
	enabled = false
	WorldManager.travel(0)
	enabled = saved
	recovery_status = ""
	return saved

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		var was_inactive := application_paused or focus_lost
		if what == NOTIFICATION_APPLICATION_PAUSED: application_paused = true
		if what == NOTIFICATION_APPLICATION_RESUMED: application_paused = false
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT: focus_lost = true
		if what == NOTIFICATION_APPLICATION_FOCUS_IN: focus_lost = false
		var is_inactive := application_paused or focus_lost
		if is_inactive and not was_inactive:
			GameState.suspended = true
			for action in ["move_left", "move_right", "move_up", "move_down", "roll", "interact", "dash"]:
				if InputMap.has_action(action): Input.action_release(action)
			enter_background()
		elif was_inactive and not is_inactive:
			resume_from_background.call_deferred()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not offline_processing: enter_background()
		get_tree().quit()

func _exit_tree() -> void:
	if enabled:
		save_game()

func discovered_power(history: Variant) -> int:
	var best := 0
	if not history is Dictionary: return best
	for id in history:
		if (not id is String and not id is StringName) or not history[id] is Array: continue
		for variant in history[id]:
			if SlimerotVariants.mask(variant) >= 0: best = maxi(best, SlimeDatabase.get_effective_rarity(id, variant))
	return best

func migrate_rng(value: Dictionary) -> Dictionary:
	# Work on a copy. The existing candidate validator must succeed before any write.
	var data := value.duplicate(true)
	if not data.get("inventory") is Dictionary or not data.get("discoveries") is Dictionary: return {}
	for key in data.inventory:
		var pair: Variant = data.inventory[key]
		if not pair is Dictionary or pair.get("variant") not in ["normal", "shiny", "glitched", "golden"]: return {}
		var flags := SlimerotVariants.mask(pair.variant)
		if pair.has("variant_flags") and pair.variant_flags != flags: return {}
		pair.variant_flags = flags
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
	data.best_ever_effective_rarity = discovered_power(data.discoveries)
	# Legacy ownership can also repair an incomplete historical discovery baseline.
	for pair in data.inventory.values():
		if pair.get("quantity", 0) > 0 and pair.get("slime_id") is String:
			data.best_ever_effective_rarity = maxi(data.best_ever_effective_rarity, SlimeDatabase.get_effective_rarity(pair.slime_id, pair.variant))
	data.rolls_since_last_power_improvement = 0
	data.shrine_sacrifices = {"shiny": [], "glitched": [], "golden": []}
	return data

func validate_rng_state(data: Dictionary) -> bool:
	if not SlimerotSaveFormat.integer(data.get("best_ever_effective_rarity")) or not SlimerotSaveFormat.integer(data.get("rolls_since_last_power_improvement")): return false
	if data.best_ever_effective_rarity < 0 or data.best_ever_effective_rarity > SlimeDatabase.get_effective_rarity("brainrot_singularity", 7): return false
	if data.rolls_since_last_power_improvement < 0 or not SlimerotSaveFormat.integer(data.get("lifetime_rolls")) or data.rolls_since_last_power_improvement > data.lifetime_rolls: return false
	if data.best_ever_effective_rarity < discovered_power(data.get("discoveries")): return false
	if not data.get("shrine_sacrifices") is Dictionary or data.shrine_sacrifices.size() != 3: return false
	for category in ["shiny", "glitched", "golden"]:
		var ids: Variant = data.shrine_sacrifices.get(category)
		if not ids is Array or ids.size() > SlimerotRoster.ROWS.size(): return false
		var seen := {}
		for id in ids:
			if not id is String or not SlimeDatabase.slimes.has(id) or seen.has(id): return false
			seen[id] = true
	return true

func grandfathered_luck_i(data: Dictionary, id: String, prerequisite: String) -> bool:
	# Before Prompt 13, R02 cost 40 and followed R01 directly. Keep that purchased
	# effect and ledger through every future save without awarding or refunding R03.
	var paid: Variant = data.roll_skill_spend.get("R02")
	return id == "R02" and prerequisite == "R03" and "R01" in data.purchased_skill_node_ids and SlimerotSaveFormat.integer(paid) and paid <= 40

func migrate_progression(value: Dictionary) -> Dictionary:
	if value.is_empty() or not value.get("purchased_skill_node_ids") is Array or not SlimerotSaveFormat.integer(value.get("lifetime_rolls")): return {}
	for id in value.purchased_skill_node_ids:
		if not id is String: return {}
	var data := value.duplicate(true)
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
	# Prompt 12 used the upcoming 100th Lifetime Roll. Preserve that established
	# boundary even when RO5 was bought mid-cycle; never replay a past trigger.
	data.super_roll_next_trigger = RollManager.super_schedule_initial(int(data.lifetime_rolls), 100) if "RO5" in data.purchased_skill_node_ids else 0
	return data

func validate_super_roll_state(data: Dictionary) -> bool:
	if not SlimerotSaveFormat.integer(data.get("super_roll_next_trigger")): return false
	var stats := SkillTreeManager.derived_stats(data.purchased_skill_node_ids)
	if not stats.super_roll: return data.super_roll_next_trigger == 0
	if data.super_roll_next_trigger == 0:
		return data.lifetime_rolls > SlimerotSaveFormat.MAX_EXACT_INTEGER - int(stats.super_roll_interval)
	return data.super_roll_next_trigger > data.lifetime_rolls and int(data.super_roll_next_trigger) - int(data.lifetime_rolls) <= int(stats.super_roll_interval)
