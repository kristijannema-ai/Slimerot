extends Node

signal save_failed(message: String)
var save_path := "user://Slimerot-save.json"
var elapsed := 0.0
var enabled := true
var last_error := ""
var last_saved_at := "Not saved yet"

func _ready() -> void:
	if "--slimerot-test" in OS.get_cmdline_user_args():
		# Test saves are isolated from player data and work in restricted CI sandboxes.
		save_path = "res://.godot/Slimerot-test-%d.json" % OS.get_process_id()
	load_game()
	GameState.critical_change.connect(func(_reason): save_game())
	get_tree().auto_accept_quit = false

func _process(delta: float) -> void:
	if GameState.is_paused():
		return
	elapsed += delta
	if elapsed >= SlimerotBalance.AUTOSAVE_SECONDS:
		elapsed = 0.0
		save_game()

func snapshot() -> Dictionary:
	return {
		"schema_version": SlimerotBalance.SCHEMA_VERSION,
		"coins": GameState.coins, "rolls_balance": GameState.rolls_balance,
		"lifetime_rolls": GameState.lifetime_rolls, "active_play_seconds": GameState.active_play_seconds,
		"highest_zone_unlocked": GameState.highest_zone_unlocked, "current_zone": GameState.current_zone,
		"zone_kill_counts": GameState.zone_kill_counts.duplicate(true),
		"boss_defeated_flags": GameState.boss_defeated_flags.duplicate(true),
		"structure_unlocked_flags": GameState.structure_unlocked_flags.duplicate(true),
		"purchased_skill_node_ids": GameState.purchased_skill_node_ids.duplicate(),
		"equipped_slot_count": SkillTreeManager.derived_stats().equipped_slots,
		"equipped_copy_ids": InventoryManager.equipped_copy_ids.duplicate(),
		"inventory": InventoryManager.inventory.duplicate(true), "next_copy_id": InventoryManager.next_copy_id,
		"active_potion_type": GameState.active_potion_type,
		"active_potion_remaining_seconds": GameState.potion_remaining_seconds,
		"settings": GameState.settings.duplicate(true),
		"roll_cooldown_remaining": RollManager.cooldown_remaining,
		"discoveries": InventoryManager.discoveries.duplicate(true),
		"active_potion_multiplier": GameState.active_potion_multiplier,
		"coins_earned": GameState.coins_earned, "coins_spent": GameState.coins_spent,
		"rarest_threshold_reached": GameState.rarest_threshold_reached,
		"highest_luck": GameState.highest_luck, "best_team_dps": GameState.best_team_dps,
	}

func save_game() -> bool:
	if not enabled:
		return false
	var temporary := save_path + ".tmp"
	var backup := save_path + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return fail("Slimerot could not open the temporary save.")
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return fail("Slimerot could not finish writing the save.")
	# Keep a previous valid generation through the Windows replacement sequence.
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return fail("Slimerot could not rotate the save backup.")
		if DirAccess.rename_absolute(save_path, backup) != OK:
			return fail("Slimerot could not preserve the previous save.")
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, save_path)
		return fail("Slimerot could not replace the main save.")
	last_error = ""
	last_saved_at = Time.get_time_string_from_system()
	return true

func fail(message: String) -> bool:
	last_error = message
	push_warning(message)
	save_failed.emit(message)
	return false

func load_game() -> bool:
	for path in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var parsed: Variant = parser.data
		if parsed is Dictionary and (parsed.get("schema_version") is float or parsed.get("schema_version") is int) and parsed.schema_version > SlimerotBalance.SCHEMA_VERSION:
			enabled = false
			return fail("This Slimerot save requires a newer version. Saving is disabled to protect it.")
		parsed = migrate(parsed)
		if validate(parsed):
			apply_snapshot(parsed)
			if path != save_path:
				# Restore the valid candidate without ever rotating corrupt data over the backup.
				DirAccess.copy_absolute(path, save_path)
			return true
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		enabled = false
		fail("Slimerot could not recover this save. Files were preserved; saving is disabled.")
	return false

func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema_version") != SlimerotBalance.SCHEMA_VERSION:
		return false
	for key in ["coins", "rolls_balance", "lifetime_rolls", "active_play_seconds", "highest_zone_unlocked", "current_zone", "next_copy_id", "active_potion_remaining_seconds", "roll_cooldown_remaining", "active_potion_multiplier", "coins_earned", "coins_spent", "rarest_threshold_reached", "highest_luck", "best_team_dps"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
		if not is_finite(float(data[key])) or data[key] < 0:
			return false
	for key in ["coins", "rolls_balance", "lifetime_rolls", "highest_zone_unlocked", "current_zone", "next_copy_id", "coins_earned", "coins_spent", "rarest_threshold_reached"]:
		if float(data[key]) != floor(float(data[key])):
			return false
	if data.active_potion_multiplier < 1.0 or data.highest_luck < 1.0:
		return false
	if data.rolls_balance > data.lifetime_rolls or data.current_zone > 1 or data.highest_zone_unlocked < 1 or data.highest_zone_unlocked > SlimerotBalance.MAX_ZONE:
		return false
	for key in ["zone_kill_counts", "boss_defeated_flags", "structure_unlocked_flags", "inventory", "settings", "discoveries"]:
		if not data.get(key) is Dictionary:
			return false
	for count in data.zone_kill_counts.values():
		if (not count is float and not count is int) or float(count) < 0:
			return false
	for key in ["boss_defeated_flags", "structure_unlocked_flags"]:
		for flag in data[key].values():
			if not flag is bool:
				return false
	if not data.get("purchased_skill_node_ids") is Array or not data.get("equipped_copy_ids") is Array or not data.get("active_potion_type") is String:
		return false
	var unique_nodes: Array = []
	for id in data.purchased_skill_node_ids:
		if not id is String or not SkillTreeManager.nodes.has(id) or id in unique_nodes:
			return false
		unique_nodes.append(id)
	if int(data.lifetime_rolls) != int(data.rolls_balance) + SkillTreeManager.rolls_spent(data.purchased_skill_node_ids):
		return false
	var seen: Array = []
	for key in data.inventory:
		var pair: Variant = data.inventory[key]
		if not pair is Dictionary or not pair.get("slime_id") is String or not pair.get("variant") is String:
			return false
		if SlimeDatabase.get_slime(pair.slime_id) == null or pair.variant not in SlimerotBalance.VARIANTS or key != pair.slime_id + ":" + pair.variant:
			return false
		if not pair.get("copy_ids") is Array or not pair.get("favorite") is bool or pair.get("quantity") != pair.copy_ids.size():
			return false
		if not pair.get("favorite_copy_ids") is Array:
			return false
		for favorite_id in pair.favorite_copy_ids:
			if favorite_id not in pair.copy_ids:
				return false
		for copy_id in pair.copy_ids:
			if not copy_id is String or not copy_id.begins_with("slimerot_copy_") or copy_id in seen:
				return false
			var serial: String = copy_id.trim_prefix("slimerot_copy_")
			if not serial.is_valid_int() or int(serial) < 1 or int(serial) >= int(data.next_copy_id):
				return false
			seen.append(copy_id)
	for id in data.discoveries:
		if not SlimeDatabase.slimes.has(id) or not data.discoveries[id] is Array:
			return false
		for variant in data.discoveries[id]:
			if variant not in SlimerotBalance.VARIANTS:
				return false
	for pair in data.inventory.values():
		if pair.quantity > 0 and pair.variant not in data.discoveries.get(pair.slime_id, []):
			return false
	var equipped: Array = []
	for copy_id in data.equipped_copy_ids:
		if copy_id not in seen or copy_id in equipped:
			return false
		equipped.append(copy_id)
	# Slot count is derived from the saved purchases, never trusted as an independent stat.
	if equipped.size() > SkillTreeManager.derived_stats(data.purchased_skill_node_ids).equipped_slots or (data.lifetime_rolls == 0 and not seen.is_empty()):
		return false
	for key in SlimerotBalance.SETTINGS:
		if not data.settings.has(key):
			continue
		if typeof(data.settings[key]) != typeof(SlimerotBalance.SETTINGS[key]):
			return false
	if data.settings.get("luck_cap", 0.0) not in SlimerotBalance.LUCK_CAPS.values():
		return false
	return true

func apply_snapshot(data: Dictionary) -> void:
	GameState.coins = int(data.coins)
	GameState.rolls_balance = int(data.rolls_balance)
	GameState.lifetime_rolls = int(data.lifetime_rolls)
	GameState.active_play_seconds = float(data.active_play_seconds)
	GameState.highest_zone_unlocked = int(data.highest_zone_unlocked)
	GameState.current_zone = int(data.current_zone)
	GameState.zone_kill_counts = data.zone_kill_counts.duplicate(true)
	GameState.boss_defeated_flags = data.boss_defeated_flags.duplicate(true)
	GameState.structure_unlocked_flags = data.structure_unlocked_flags.duplicate(true)
	GameState.purchased_skill_node_ids.assign(data.purchased_skill_node_ids)
	GameState.active_potion_type = data.active_potion_type
	GameState.potion_remaining_seconds = float(data.active_potion_remaining_seconds)
	GameState.settings = SlimerotBalance.SETTINGS.duplicate(true)
	GameState.settings.merge(data.settings, true)
	InventoryManager.inventory = data.inventory.duplicate(true)
	InventoryManager.equipped_copy_ids.assign(data.equipped_copy_ids)
	InventoryManager.next_copy_id = int(data.next_copy_id)
	InventoryManager.discoveries = data.discoveries.duplicate(true)
	GameState.active_potion_multiplier = float(data.active_potion_multiplier)
	GameState.coins_earned = int(data.coins_earned)
	GameState.coins_spent = int(data.coins_spent)
	GameState.rarest_threshold_reached = int(data.rarest_threshold_reached)
	GameState.highest_luck = float(data.highest_luck)
	GameState.best_team_dps = float(data.best_team_dps)
	RollManager.cooldown_remaining = minf(float(data.roll_cooldown_remaining), SkillTreeManager.derived_stats().roll_cooldown)
	GameState.player_hp = SkillTreeManager.derived_stats().max_hp
	GameState.changed.emit()

func migrate(value: Variant) -> Variant:
	if not value is Dictionary or value.get("schema_version") != 1:
		return value
	var data: Dictionary = value.duplicate(true)
	if not data.get("inventory") is Dictionary or not data.get("purchased_skill_node_ids") is Array:
		return data
	data.schema_version = SlimerotBalance.SCHEMA_VERSION
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
	return data

func reset_save() -> bool:
	# Called only by the hold-to-confirm settings control; never by a roll or a load failure.
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix) and DirAccess.remove_absolute(save_path + suffix) != OK:
			return fail("Slimerot could not reset the local save.")
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	enabled = true
	WorldManager.travel(0)
	return save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()
		GameState.suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GameState.suspended = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _exit_tree() -> void:
	if enabled:
		save_game()
