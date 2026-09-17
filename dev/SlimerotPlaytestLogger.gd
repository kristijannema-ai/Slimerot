extends Node

# Slimerot optional developer observer. It never owns or changes gameplay state.
# Loaded dynamically only in explicitly opted-in debug builds; excluded from exports.
signal updated
signal exported(result: Dictionary)

const SCHEMA_VERSION := 1
const SAMPLE_SECONDS := 30.0
const MAX_EVENTS := 2048
const MAX_SAMPLES := 1024
const DEFAULT_DIRECTORY := "user://Slimerot-playtests"
const MODEL_SOURCES := [
	"res://scripts/data/SlimerotBalance.gd", "res://scripts/data/SlimerotCampaign.gd",
	"res://scripts/data/SlimerotRollTree.gd", "res://scripts/data/SlimerotCoinTree.gd",
	"res://scripts/data/SlimerotRoster.gd", "res://scripts/data/SlimerotEncounters.gd",
]

var active := false
var run_id := ""
var started_utc := ""
var output_directory := DEFAULT_DIRECTORY
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var dropped_events := 0
var dropped_samples := 0
var missed_sample_intervals := 0
var last_export: Dictionary = {}
var model: Dictionary = {}
var _sequence := 0
var _start_active := 0.0
var _last_active := 0.0
var _last_sample_active := 0.0
var _run_active := 0.0
var _segment := 0
var _seen_gates: Dictionary = {}
var _seen_bosses: Dictionary = {}
var _seen_structures: Dictionary = {}
var _seen_zones: Dictionary = {}
var _completed := false
var _strongest_owned := ""
var _strongest_equipped := ""
var _team: Array = []
var _blocker_signature := ""
var _boss_zone := 0
var _boss_started_active := 0.0
var _boss_damage := 0.0
var _boss_previous_hp := 0.0
var _boss_initial_hp := 0.0
var _boss_elapsed := 0.0
var _boss_tracking := false
var _boss_node: WeakRef

func _init() -> void:
	set_process(false)

func _ready() -> void:
	# Godot enables overridden _process at tree entry, after _init has run.
	set_process(active)

static func activation_allowed(debug_build: bool, explicit_opt_in: bool) -> bool:
	return debug_build and explicit_opt_in

func start(directory: String = DEFAULT_DIRECTORY, explicit_opt_in: bool = false) -> bool:
	if active: return true
	var opted_in := explicit_opt_in or "--slimerot-playtest" in OS.get_cmdline_user_args()
	if not activation_allowed(OS.is_debug_build(), opted_in) or not is_inside_tree(): return false
	output_directory = directory
	started_utc = Time.get_datetime_string_from_system(true) + "Z"
	run_id = "Slimerot-%s-%d-%d" % [started_utc.replace(":", "-"), OS.get_process_id(), Time.get_ticks_usec()]
	events.clear()
	samples.clear()
	dropped_events = 0
	dropped_samples = 0
	missed_sample_intervals = 0
	_sequence = 0
	_start_active = GameState.active_play_seconds
	_last_active = _start_active
	_last_sample_active = _start_active
	_run_active = 0.0
	_segment = 0
	_seen_gates = GameState.unlocked_gate_flags.duplicate(true)
	_seen_bosses = GameState.boss_defeated_flags.duplicate(true)
	_seen_structures = GameState.structure_unlocked_flags.duplicate(true)
	_seen_zones = {str(GameState.current_zone): true}
	_completed = GameState.campaign_completed
	_team = InventoryManager.equipped_copy_ids.duplicate()
	_strongest_owned = _identity(strongest(false))
	_strongest_equipped = _identity(strongest(true))
	_blocker_signature = ""
	_boss_tracking = false
	_boss_zone = 0
	_boss_elapsed = 0.0
	_boss_damage = 0.0
	model = _model_fingerprint()
	active = true
	GameState.changed.connect(_on_state_changed)
	GameState.critical_change.connect(_on_critical_change)
	SaveManager.snapshot_applied.connect(_on_snapshot_applied)
	RollManager.result_committed.connect(_on_roll)
	SkillTreeManager.purchased.connect(_on_purchase)
	WorldManager.zone_changed.connect(_on_zone)
	WorldManager.boss_requested.connect(_on_boss_started)
	WorldManager.completion_reached.connect(_on_completion)
	record_event("run_started", {"loaded_campaign": GameState.lifetime_rolls > 0, "initial_zone": GameState.current_zone})
	_record_sample("initial")
	if WorldManager.boss_active: _on_boss_started(GameState.current_zone)
	_observe_blocker()
	set_process(true)
	return true

func stop() -> void:
	if not active: return
	GameState.changed.disconnect(_on_state_changed)
	GameState.critical_change.disconnect(_on_critical_change)
	SaveManager.snapshot_applied.disconnect(_on_snapshot_applied)
	RollManager.result_committed.disconnect(_on_roll)
	SkillTreeManager.purchased.disconnect(_on_purchase)
	WorldManager.zone_changed.disconnect(_on_zone)
	WorldManager.boss_requested.disconnect(_on_boss_started)
	WorldManager.completion_reached.disconnect(_on_completion)
	active = false
	set_process(false)

func _exit_tree() -> void:
	stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and active: export_run()

func _process(_delta: float) -> void:
	if not active: return
	# The existing authoritative clock excludes menus and suspension. Never advance it.
	_sync_clock()
	var now := GameState.active_play_seconds
	_observe_boss()
	if now - _last_sample_active >= SAMPLE_SECONDS:
		# A long frame exports the current observation once, never invented old states.
		var intervals := floori((now - _last_sample_active) / SAMPLE_SECONDS)
		missed_sample_intervals += maxi(0, intervals - 1)
		_last_sample_active += intervals * SAMPLE_SECONDS
		_record_sample("interval")

func _sync_clock() -> void:
	var now := GameState.active_play_seconds
	if now < _last_active:
		_begin_segment("clock_reset", _last_active)
	else:
		_run_active += now - _last_active
		_last_active = now

func _on_snapshot_applied(previous_active_play_seconds: float) -> void:
	# Count only real time before the load, including a partial unsampled frame.
	_run_active += maxf(0.0, previous_active_play_seconds - _last_active)
	_begin_segment("save_load", previous_active_play_seconds)

func _begin_segment(reason: String, previous_active_play_seconds: float) -> void:
	_segment += 1
	_last_active = GameState.active_play_seconds
	_last_sample_active = _last_active
	_start_active = _last_active
	_seen_gates = GameState.unlocked_gate_flags.duplicate(true)
	_seen_bosses = GameState.boss_defeated_flags.duplicate(true)
	_seen_structures = GameState.structure_unlocked_flags.duplicate(true)
	_seen_zones = {str(GameState.current_zone): true}
	_completed = GameState.campaign_completed
	_team = InventoryManager.equipped_copy_ids.duplicate()
	_strongest_owned = _identity(strongest(false))
	_strongest_equipped = _identity(strongest(true))
	_blocker_signature = ""
	_boss_tracking = false
	_boss_node = null
	_boss_zone = 0
	_boss_started_active = 0.0
	_boss_initial_hp = 0.0
	_boss_previous_hp = 0.0
	_boss_damage = 0.0
	_boss_elapsed = 0.0
	record_event("active_clock_boundary", {"reason": reason, "previous_active_play_seconds": previous_active_play_seconds, "segment": _segment})

func strongest(equipped_only: bool = false) -> Dictionary:
	var best: Dictionary = {}
	if equipped_only:
		for copy_id in InventoryManager.equipped_copy_ids:
			var pair := InventoryManager.pair_for_copy(copy_id)
			if pair.is_empty() or int(pair.get("quantity", 0)) <= 0: continue
			best = _pick_stronger(best, pair)
	else:
		for pair in InventoryManager.inventory.values():
			if int(pair.get("quantity", 0)) <= 0: continue
			best = _pick_stronger(best, pair)
	return best

func _pick_stronger(best: Dictionary, pair: Dictionary) -> Dictionary:
	var data := SlimeDatabase.get_slime(pair.slime_id)
	if data == null: return best
	var candidate := {"id": str(pair.slime_id), "name": data.display_name, "variant": str(pair.variant),
		"damage": InventoryManager.damage_for_pair(pair), "rarity_threshold": data.rarity_threshold}
	if best.is_empty() or candidate.damage > best.damage or (candidate.damage == best.damage and _identity(candidate) < _identity(best)):
		return candidate
	return best

func _identity(slime: Dictionary) -> String:
	return "" if slime.is_empty() else str(slime.id) + ":" + str(slime.variant)

func gate_status() -> Dictionary:
	var zone := GameState.current_zone
	if zone < 1 or zone > SlimerotBalance.MAX_ZONE: return {"zone": zone, "state": "hub"}
	var data := SlimerotCampaign.zone(zone)
	var kills := int(GameState.zone_kill_counts.get(str(zone), 0))
	var boss_required := not data.boss_id_or_null.is_empty() and not WorldManager.is_boss_zone_defeated(zone)
	var state := "open" if WorldManager.gate_open(zone) else "kills" if kills < data.kill_requirement else "boss" if boss_required else "coins" if GameState.coins < data.gate_coin_cost else "ready"
	return {"zone": zone, "state": state, "kills": kills, "kills_required": data.kill_requirement,
		"kills_remaining": maxi(0, data.kill_requirement - kills), "coins_required": data.gate_coin_cost,
		"coins_remaining": maxi(0, data.gate_coin_cost - GameState.coins), "boss_required": boss_required}

func snapshot() -> Dictionary:
	var stats := SkillTreeManager.derived_stats()
	var boss_team_damage := 0.0
	for copy_id in InventoryManager.equipped_copy_ids: boss_team_damage += InventoryManager.damage_for_copy(copy_id, true)
	return {"utc": Time.get_datetime_string_from_system(true) + "Z",
		"active_play_seconds": GameState.active_play_seconds,
		"run_active_seconds": _run_active + maxf(0.0, GameState.active_play_seconds - _last_active),
		"segment": _segment, "segment_active_seconds": maxf(0.0, GameState.active_play_seconds - _start_active),
		"lifetime_rolls": GameState.lifetime_rolls, "spendable_rolls": GameState.rolls_balance,
		"coins": GameState.coins, "coins_earned": GameState.coins_earned, "coins_spent": GameState.coins_spent,
		"team_dps": InventoryManager.team_dps(), "slots": stats.equipped_slots,
		"equipped_count": InventoryManager.equipped_copy_ids.size(), "effective_luck": RollManager.effective_luck(),
		"rolling_luck": RollManager.rolling_luck(), "luck_cap": GameState.settings.luck_cap,
		"next_roll_luck_breakdown": RollManager.get_luck_breakdown({"super_roll_multiplier": RollManager.next_roll_multiplier(), "apply_cap": true}),
		"super_roll_tier": stats.super_roll_tier, "super_roll_interval": stats.super_roll_interval,
		"super_roll_multiplier": stats.super_roll_multiplier, "rolls_until_super": RollManager.rolls_until_super(),
		"strongest_owned": strongest(false), "strongest_equipped": strongest(true),
		"equipped_copy_ids": InventoryManager.equipped_copy_ids.duplicate(),
		"current_zone": GameState.current_zone, "highest_zone_unlocked": GameState.highest_zone_unlocked,
		"zone_kill_counts": GameState.zone_kill_counts.duplicate(true),
		"purchased_skill_node_ids": GameState.purchased_skill_node_ids.duplicate(),
		"breakthrough_count": stats.breakthrough_count, "roll_cooldown": stats.roll_cooldown,
		"auto_roll": bool(GameState.settings.auto_roll_state), "auto_sell": GameState.settings.auto_sell_settings.duplicate(true),
		"active_potion": GameState.active_potion_type, "potion_seconds": GameState.potion_remaining_seconds,
		"boss_brew_seconds": GameState.boss_brew_seconds, "boss_active": WorldManager.boss_active,
		"boss_team_dps": boss_team_damage / stats.attack_interval, "observed_boss_zone": _boss_zone,
		"observed_boss_damage": _boss_damage, "observed_boss_active_seconds": _boss_elapsed,
		"observed_boss_dps": _boss_damage / _boss_elapsed if _boss_elapsed > 0.0 else 0.0,
		"paused": GameState.is_paused(), "player_dead": GameState.player_dead,
		"gate": gate_status(), "campaign_completed": GameState.campaign_completed}

func record_event(kind: String, details: Dictionary = {}) -> void:
	if not active: return
	_sequence += 1
	if events.size() >= MAX_EVENTS:
		# Preserve the initial baseline while evicting the oldest later observation.
		events.remove_at(1)
		dropped_events += 1
	events.append({"sequence": _sequence, "kind": kind, "details": details.duplicate(true), "state": snapshot()})
	updated.emit()

func _record_sample(reason: String) -> void:
	if samples.size() >= MAX_SAMPLES:
		samples.remove_at(1)
		dropped_samples += 1
	samples.append({"reason": reason, "state": snapshot()})
	updated.emit()

func _on_roll(result: Dictionary) -> void:
	if bool(result.get("first_roll", false)): record_event("first_roll", result)
	_observe_inventory()

func _on_purchase(id: String, previous_luck: float, new_luck: float) -> void:
	var node: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(id)
	if node == null: return
	record_event("skill_purchased", {"id": id, "name": node.display_name, "currency": node.currency_type, "cost": node.cost})
	if node.effect_type == "checkpoint_luck":
		record_event("breakthrough", {"id": id, "name": node.display_name, "previous_luck": previous_luck, "new_luck": new_luck,
			"multiplier": new_luck / previous_luck if previous_luck > 0.0 else 0.0})
	_observe_inventory()

func _on_zone(zone: int) -> void:
	_sync_clock()
	if _boss_tracking and zone != _boss_zone:
		_observe_boss()
		_boss_tracking = false
		record_event("boss_attempt_ended", {"zone": _boss_zone, "reason": "travel"})
	if not _seen_zones.has(str(zone)):
		_seen_zones[str(zone)] = true
		record_event("zone_first_entry", {"zone": zone, "scope": "this_observer_run"})
	_observe_blocker()

func _on_state_changed() -> void:
	_sync_clock()
	_observe_flags(GameState.unlocked_gate_flags, _seen_gates, "gate_unlocked")
	_observe_flags(GameState.structure_unlocked_flags, _seen_structures, "structure_repaired")
	_observe_boss()
	_observe_flags(GameState.boss_defeated_flags, _seen_bosses, "boss_defeated")
	if _boss_tracking and WorldManager.is_boss_zone_defeated(_boss_zone):
		_boss_tracking = false
		record_event("boss_attempt_ended", {"zone": _boss_zone, "reason": "defeated"})
	_observe_blocker()

func _observe_flags(current: Dictionary, seen: Dictionary, kind: String) -> void:
	var keys := current.keys()
	keys.sort()
	for key in keys:
		if bool(current[key]) and not bool(seen.get(key, false)):
			seen[key] = true
			record_event(kind, {"id": str(key)})

func _on_critical_change(reason: String) -> void:
	if reason in ["team_change", "sale", "sell_duplicates", "mutation"]: _observe_inventory()
	if reason == "completion_portal": _on_completion()

func _observe_inventory() -> void:
	var owned := strongest(false)
	var equipped := strongest(true)
	if _identity(owned) != _strongest_owned:
		_strongest_owned = _identity(owned)
		record_event("strongest_owned_changed", {"slime": owned})
	if _team != InventoryManager.equipped_copy_ids:
		_team = InventoryManager.equipped_copy_ids.duplicate()
		record_event("team_changed", {"copy_ids": _team})
	if _identity(equipped) != _strongest_equipped:
		_strongest_equipped = _identity(equipped)
		record_event("strongest_equipped_changed", {"slime": equipped})

func _observe_blocker() -> void:
	var gate := gate_status()
	var signature := str(gate.zone) + ":" + str(gate.state)
	if signature != _blocker_signature:
		_blocker_signature = signature
		record_event("objective_gate_blocker", gate)

func _on_boss_started(zone: int) -> void:
	_boss_zone = zone
	_boss_started_active = GameState.active_play_seconds
	_boss_elapsed = 0.0
	_boss_damage = 0.0
	_boss_initial_hp = float(SlimerotEncounters.BOSSES.get(zone, {}).get("hp", 0.0))
	_boss_previous_hp = _boss_initial_hp
	_boss_node = null
	_boss_tracking = true
	record_event("boss_started", {"zone": zone, "hp": _boss_initial_hp})
	_observe_boss()

func _observe_boss() -> void:
	if not _boss_tracking: return
	_boss_elapsed = maxf(0.0, GameState.active_play_seconds - _boss_started_active)
	var boss: Node = _boss_node.get_ref() if _boss_node != null else null
	if not is_instance_valid(boss):
		for candidate in get_tree().get_nodes_in_group("slimerot_bosses"):
			if int(candidate.zone_id) == _boss_zone:
				boss = candidate
				_boss_node = weakref(boss)
				if not boss.tree_exiting.is_connected(_on_boss_exiting): boss.tree_exiting.connect(_on_boss_exiting)
				break
	if is_instance_valid(boss):
		var hp := maxf(0.0, float(boss.hp))
		_boss_damage += maxf(0.0, _boss_previous_hp - hp)
		_boss_previous_hp = hp
	elif WorldManager.is_boss_zone_defeated(_boss_zone):
		# The reward can remove the arena before this observer receives changed.
		_boss_damage += _boss_previous_hp
		_boss_previous_hp = 0.0
	if not WorldManager.boss_active and not WorldManager.is_boss_zone_defeated(_boss_zone):
		_boss_tracking = false
		record_event("boss_attempt_ended", {"zone": _boss_zone, "reason": "death_or_retreat"})

func _on_boss_exiting() -> void:
	# An observation hook only: no boss fields or gameplay signals are changed.
	if active: _observe_boss()

func _on_completion() -> void:
	if _completed: return
	_completed = true
	record_event("campaign_completed")

func _model_fingerprint() -> Dictionary:
	var source_hashes: Dictionary = {}
	for path in MODEL_SOURCES:
		if FileAccess.file_exists(path): source_hashes[path.get_file()] = FileAccess.get_sha256(path)
	return {"fingerprint_sha256": JSON.stringify(source_hashes, "", true).sha256_text(),
		"source_sha256": source_hashes, "godot": Engine.get_version_info().string,
		"save_schema": SlimerotBalance.SCHEMA_VERSION}

func export_summary() -> Dictionary:
	return {"schema": "Slimerot.playtest", "schema_version": SCHEMA_VERSION, "run_id": run_id,
		"started_utc": started_utc, "exported_utc": Time.get_datetime_string_from_system(true) + "Z",
		"model": model.duplicate(true), "sample_interval_active_seconds": SAMPLE_SECONDS,
		"limits": {"events": MAX_EVENTS, "samples": MAX_SAMPLES},
		"drops": {"events": dropped_events, "samples": dropped_samples, "missed_sample_intervals": missed_sample_intervals},
		"notes": ["Observed gameplay only; this logger never simulates progression.",
			"Active time is the saved game clock; run_active_seconds accumulates observations across explicitly numbered reset/load segments.",
			"Every applied save starts a segment before arena cleanup, including identical clocks; a backward clock also starts a reset segment. Imported progress is a baseline, not earned milestones.",
			"Boss DPS is observed HP loss divided by active encounter seconds, including movement and death downtime.",
			"Gate blocker describes objective requirements, not an assertion that the player is stuck."],
		"latest": snapshot(), "events": events.duplicate(true), "samples": samples.duplicate(true)}

func text_summary(data: Dictionary) -> String:
	var lines := PackedStringArray(["Slimerot playtest | schema_version=%d" % SCHEMA_VERSION,
		"run_id=" + str(data.run_id), "started_utc=" + str(data.started_utc),
		"model_fingerprint_sha256=" + str(data.model.fingerprint_sha256),
		"drops=" + JSON.stringify(data.drops, "", true),
		"record\tsequence\tkind\tactive_play_seconds\trun_active_seconds\tsegment\tlifetime_rolls\tspendable_rolls\tcoins\tteam_dps\tslots\teffective_luck\tstrongest_owned\tstrongest_equipped\tcurrent_zone\tdetails"])
	for event in data.events: lines.append(_text_row("event", int(event.sequence), str(event.kind), event.state, event.details))
	for index in data.samples.size():
		var sample: Dictionary = data.samples[index]
		lines.append(_text_row("sample", index, str(sample.reason), sample.state, {}))
	lines.append(_text_row("latest", 0, "export", data.latest, {}))
	return "\n".join(lines) + "\n"

func _text_row(record: String, sequence: int, kind: String, state: Dictionary, details: Dictionary) -> String:
	return "%s\t%d\t%s\t%.3f\t%.3f\t%d\t%d\t%d\t%d\t%.3f\t%d\t%.6f\t%s\t%s\t%d\t%s" % [record, sequence, kind,
		state.active_play_seconds, state.run_active_seconds, state.segment, state.lifetime_rolls, state.spendable_rolls, state.coins,
		state.team_dps, state.slots, state.effective_luck, JSON.stringify(state.strongest_owned, "", true),
		JSON.stringify(state.strongest_equipped, "", true), state.current_zone, JSON.stringify(details, "", true)]

func export_run() -> Dictionary:
	if not active or not OS.is_debug_build(): return _export_result(false, "Slimerot playtest observer is not active.")
	if output_directory.is_empty(): return _export_result(false, "Slimerot playtest directory is empty.")
	var ancestor := ProjectSettings.globalize_path(output_directory)
	while not ancestor.is_empty():
		if FileAccess.file_exists(ancestor): return _export_result(false, "Slimerot playtest directory is blocked by a file: " + ancestor)
		var parent := ancestor.get_base_dir()
		if parent == ancestor: break
		ancestor = parent
	var error := DirAccess.make_dir_recursive_absolute(output_directory)
	if error != OK: return _export_result(false, "Cannot create Slimerot playtest directory: " + error_string(error))
	var data := export_summary()
	var json_path := output_directory.path_join(run_id + ".json")
	var text_path := output_directory.path_join(run_id + ".txt")
	# Only diagnostic files in the selected directory, never SaveManager.save_path.
	for item in [[json_path, JSON.stringify(data, "\t", true)], [text_path, text_summary(data)]]:
		var file := FileAccess.open(item[0], FileAccess.WRITE)
		if file == null: return _export_result(false, "Cannot write Slimerot playtest file: " + error_string(FileAccess.get_open_error()))
		file.store_string(item[1])
		file.flush()
		var write_error := file.get_error()
		file.close()
		if write_error != OK: return _export_result(false, "Cannot finish Slimerot playtest file: " + error_string(write_error))
	last_export = {"ok": true, "error": "", "json_path": ProjectSettings.globalize_path(json_path), "text_path": ProjectSettings.globalize_path(text_path)}
	exported.emit(last_export.duplicate())
	return last_export.duplicate()

func _export_result(ok: bool, message: String) -> Dictionary:
	last_export = {"ok": ok, "error": message, "json_path": "", "text_path": ""}
	exported.emit(last_export.duplicate())
	return last_export.duplicate()
