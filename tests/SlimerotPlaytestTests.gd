extends Node

# Slimerot observer tests use real manager transactions and isolated diagnostic files.
var suite: Node
var world: Node
var logger_script: Script
var logger: Node
var directory := ""

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Playtest · " + description)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	logger_script = load("res://dev/SlimerotPlaytestLogger.gd")
	directory = "res://.godot/Slimerot-playtest-tests-%d" % OS.get_process_id()
	var process_states := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	var save_enabled := SaveManager.enabled
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	fresh()
	test_activation()
	test_snapshots_and_time()
	test_load_boundaries()
	test_milestones()
	test_boss_observations()
	test_non_interference_and_export()
	test_bounds()
	await test_overlay()
	fresh()
	SaveManager.enabled = save_enabled
	GameState.set_process(process_states[0])
	RollManager.set_process(process_states[1])
	SaveManager.set_process(process_states[2])
	CombatManager.set_physics_process(process_states[3])
	await get_tree().process_frame

func fresh() -> void:
	if is_instance_valid(logger):
		logger.stop()
		remove_child(logger)
		logger.free()
	logger = null
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)

func begin() -> void:
	logger = logger_script.new()
	add_child(logger)
	check(logger.start(directory, true), "explicitly opted-in debug observer starts")
	logger.set_process(false)

func kinds() -> Array:
	return logger.events.map(func(event): return event.kind)

func events_of(kind: String) -> Array:
	return logger.events.filter(func(event): return event.kind == kind)

func runtime_state() -> Dictionary:
	return {"save": SaveManager.snapshot(), "rng": RollManager.rng.state, "variant_rng": RollManager.variant_rng.state,
		"rng_seed": RollManager.rng.seed, "variant_seed": RollManager.variant_rng.seed,
		"last_roll": RollManager.last_result.duplicate(true), "reveal": RollManager.active_reveal.duplicate(true),
		"reveal_queue": RollManager.reveal_queue.duplicate(true), "reveal_seconds": RollManager.reveal_remaining,
		"save_elapsed": SaveManager.elapsed, "save_generation": SaveManager.generation, "save_path": SaveManager.save_path,
		"attack_timers": CombatManager.attack_timers.duplicate(true), "projectiles": CombatManager.get_child_count(),
		"hp": GameState.player_hp, "dead": GameState.player_dead, "paused": GameState.is_paused()}

func test_activation() -> void:
	check(not logger_script.activation_allowed(false, false) and not logger_script.activation_allowed(false, true), "release activation rejects both normal and explicit opt-in")
	check(not logger_script.activation_allowed(true, false) and logger_script.activation_allowed(true, true), "debug activation requires explicit opt-in")
	var inactive: Node = logger_script.new()
	add_child(inactive)
	var before := runtime_state()
	check(not inactive.active and not inactive.is_processing() and inactive.events.is_empty(), "constructing the observer does not activate or gather player data")
	check(not inactive.export_run().ok and runtime_state() == before, "inactive export rejects without touching progression")
	remove_child(inactive)
	inactive.free()

func test_snapshots_and_time() -> void:
	fresh()
	begin()
	var initial: Dictionary = logger.snapshot()
	var required := ["utc", "active_play_seconds", "run_active_seconds", "segment", "lifetime_rolls", "spendable_rolls", "coins", "team_dps", "slots", "effective_luck", "rolling_luck", "luck_cap", "strongest_owned", "strongest_equipped", "current_zone", "highest_zone_unlocked", "zone_kill_counts", "coins_earned", "coins_spent", "active_potion", "observed_boss_dps", "observed_boss_active_seconds"]
	check(required.all(func(key): return initial.has(key)), "snapshot exposes all required metrics and comparison context")
	check(initial.strongest_owned.is_empty() and initial.strongest_equipped.is_empty(), "empty inventory reports no strongest slime")
	check(logger.events[0].kind == "run_started" and logger.samples.size() == 1 and logger.samples[0].reason == "initial", "run begins with timestamped milestone and initial state")
	GameState._process(29.9)
	logger._process(1000.0)
	check(logger.samples.size() == 1 and is_equal_approx(logger.snapshot().active_play_seconds, 29.9), "observer delta cannot invent active time or early samples")
	GameState.menu_paused = true
	GameState._process(90.0)
	logger._process(90.0)
	check(logger.samples.size() == 1 and is_equal_approx(logger.snapshot().run_active_seconds, 29.9), "pause menu time does not advance observations")
	GameState.menu_paused = false
	GameState.suspended = true
	GameState._process(90.0)
	logger._process(90.0)
	check(logger.samples.size() == 1, "suspended time does not generate samples")
	GameState.suspended = false
	GameState._process(0.1)
	logger._process(0.0)
	check(logger.samples.size() == 2 and is_equal_approx(logger.samples[1].state.active_play_seconds, 30.0), "first interval records exactly thirty authoritative active seconds")
	GameState._process(90.0)
	logger._process(0.0)
	check(logger.samples.size() == 3 and logger.missed_sample_intervals == 2, "long frame reports skipped observations instead of fabricating historical samples")
	var previous_run: float = logger.snapshot().run_active_seconds
	GameState.reset()
	logger._process(0.0)
	check(events_of("active_clock_boundary").size() == 1 and logger.snapshot().segment == 1 and logger.snapshot().run_active_seconds == previous_run, "reset is an explicit segment boundary without negative or bridged time")
	GameState._process(3.0)
	logger._process(0.0)
	check(is_equal_approx(logger.snapshot().segment_active_seconds, 3.0) and is_equal_approx(logger.snapshot().run_active_seconds, previous_run + 3.0), "new segment time and accumulated observer time remain distinct")
	var saved := SaveManager.snapshot()
	saved.active_play_seconds += 1000.0
	SaveManager.apply_snapshot(saved)
	check(logger.snapshot().segment == 2 and is_equal_approx(logger.snapshot().run_active_seconds, previous_run + 3.0) and events_of("active_clock_boundary").back().details.reason == "save_load", "forward save load starts a segment without claiming imported time as played in this run")
	var empty_id := InventoryManager.add_copy("brainrot_singularity", "golden", false)
	var empty: Dictionary = InventoryManager.pair_for_copy(empty_id)
	empty.copy_ids.clear()
	empty.quantity = 0
	var real := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "shiny", false)
	InventoryManager.equip(real)
	var strongest: Dictionary = logger.snapshot().strongest_owned
	check(strongest.id == SlimerotBalance.FIRST_SLIME and strongest.variant == "shiny" and strongest.damage == InventoryManager.damage_for_copy(real), "zero-quantity historical rarest entries cannot become strongest owned")
	check(strongest.has("name") and logger.snapshot().strongest_equipped == strongest, "strongest summaries include stable id, content name, variant and actual damage")
	InventoryManager.add_copies("brainrot_singularity", "golden", 100000)
	check(logger.snapshot().strongest_owned.id == "brainrot_singularity" and logger.snapshot().strongest_equipped.id == SlimerotBalance.FIRST_SLIME, "compact offline stacks participate in strongest-owned instrumentation without changing equipment")
	var copied: Dictionary = logger.snapshot()
	copied.equipped_copy_ids.clear()
	copied.zone_kill_counts["1"] = 999
	copied.auto_sell.enabled = true
	check(InventoryManager.equipped_copy_ids.size() == 1 and GameState.zone_kill_counts.is_empty() and not GameState.settings.auto_sell_settings.enabled, "returned snapshot containers are detached from authoritative state")

func test_load_boundaries() -> void:
	fresh()
	begin()
	GameState._process(10.0)
	logger._process(0.0)
	var saved := SaveManager.snapshot()
	saved.highest_zone_unlocked = 3
	saved.current_zone = 3
	saved.unlocked_gate_flags = {"1": true, "2": true}
	saved.boss_defeated_flags = {"zone_2": true}
	saved.structure_unlocked_flags = {"skill_tree_shrine": true}
	SaveManager.apply_snapshot(saved)
	check(logger.snapshot().segment == 1 and is_equal_approx(logger.snapshot().run_active_seconds, 10.0), "identical-clock save load still starts a segment without inventing elapsed time")
	check(events_of("gate_unlocked").is_empty() and events_of("boss_defeated").is_empty() and events_of("structure_repaired").is_empty() and events_of("zone_first_entry").is_empty(), "loaded gates, bosses, structures and location are baselines rather than earned milestones")
	GameState._process(0.25)
	saved = SaveManager.snapshot()
	saved.active_play_seconds += 12.0
	SaveManager.apply_snapshot(saved)
	check(logger.snapshot().segment == 2 and is_equal_approx(logger.snapshot().run_active_seconds, 10.25) and is_zero_approx(logger.snapshot().segment_active_seconds), "small forward load counts only genuine unsampled time before applying the save")
	check(is_equal_approx(events_of("active_clock_boundary").back().details.previous_active_play_seconds, 10.25), "load boundary retains the previous authoritative clock")
	saved = SaveManager.snapshot()
	saved.active_play_seconds += 1000.0
	SaveManager.apply_snapshot(saved)
	check(logger.snapshot().segment == 3 and is_equal_approx(logger.snapshot().run_active_seconds, 10.25), "large forward load cannot add imported time to observer duration")
	saved = SaveManager.snapshot()
	saved.active_play_seconds = 0.5
	SaveManager.apply_snapshot(saved)
	check(logger.snapshot().segment == 4 and is_equal_approx(logger.snapshot().run_active_seconds, 10.25) and events_of("active_clock_boundary").size() == 4, "backward load creates exactly one explicit segment")
	GameState._process(35.0)
	WorldManager.travel(0)
	check(logger.snapshot().segment == 4 and is_equal_approx(logger.snapshot().run_active_seconds, 45.25), "ordinary travel after a long frame counts active time without inferring a save load")
	fresh()
	begin()
	GameState.highest_zone_unlocked = 2
	GameState.zone_kill_counts["2"] = SlimerotCampaign.zone(2).kill_requirement
	WorldManager.travel(2)
	check(WorldManager.start_boss(2), "load-boundary regression starts a real tracked boss")
	world.arena.boss.set_physics_process(false)
	GameState._process(4.0)
	world.arena.boss.take_damage(40.0)
	logger._process(0.0)
	GameState._process(0.5)
	saved = SaveManager.snapshot()
	saved.active_play_seconds += 1000.0
	SaveManager.apply_snapshot(saved)
	var loaded: Dictionary = logger.snapshot()
	check(loaded.segment == 1 and is_equal_approx(loaded.run_active_seconds, 4.5) and loaded.observed_boss_zone == 0 and is_zero_approx(loaded.observed_boss_active_seconds) and is_zero_approx(loaded.observed_boss_damage), "loading during a boss clears its observation before arena cleanup can consume imported time")
	check(events_of("boss_attempt_ended").is_empty() and events_of("boss_defeated").is_empty() and events_of("boss_started").size() == 1, "load-induced boss removal cannot create a false retreat or defeat milestone")
	check(WorldManager.start_boss(2), "a new boss attempt can start normally after the load")
	world.arena.boss.set_physics_process(false)
	GameState._process(2.0)
	world.arena.boss.take_damage(20.0)
	logger._process(0.0)
	check(is_equal_approx(logger.snapshot().observed_boss_dps, 10.0) and is_equal_approx(logger.snapshot().observed_boss_active_seconds, 2.0), "next boss attempt uses its own time and HP baseline")

func test_milestones() -> void:
	fresh()
	begin()
	check(RollManager.request_roll(), "first real roll transaction succeeds with observer attached")
	var order := kinds()
	check(order.find("first_roll") > order.find("run_started") and order.find("strongest_owned_changed") > order.find("first_roll") and order.find("team_changed") > order.find("first_roll"), "first roll precedes resulting strongest and team milestones")
	GameState.rolls_balance = 10000
	GameState.lifetime_rolls = 10000
	for row in SlimerotRollTree.MAINLINE:
		if row[0] == "R09": break
		check(SkillTreeManager.purchase(row[0]), "observed purchase %s uses the existing transaction" % row[0])
	var purchases := events_of("skill_purchased")
	var breakthroughs := events_of("breakthrough")
	check(purchases.size() == 8 and purchases[7].details.id == "R08" and breakthroughs.size() == 1 and is_equal_approx(breakthroughs[0].details.multiplier, 20.0), "every Roll node and exact x20 checkpoint are timestamped once")
	check(purchases[7].sequence < breakthroughs[0].sequence, "purchase milestone precedes its Breakthrough effect milestone")
	GameState.coins = 100000
	check(WorldManager.repair("skill_tree_shrine"), "observed structure repair uses the existing transaction")
	check(SkillTreeManager.purchase("C01"), "observed Coin node uses the existing transaction")
	check(events_of("structure_repaired").size() == 1 and events_of("skill_purchased").back().details.currency == "Coins", "structure and Coin-tree milestones preserve currency identity")
	WorldManager.travel(1)
	WorldManager.travel(0)
	WorldManager.travel(1)
	check(events_of("zone_first_entry").size() == 1 and events_of("zone_first_entry")[0].details.zone == 1, "repeated travel records first entry once within observer run")
	GameState.zone_kill_counts["1"] = SlimerotCampaign.zone(1).kill_requirement
	GameState.changed.emit()
	check(logger.snapshot().gate.state == "ready" and events_of("objective_gate_blocker").back().details.state == "ready", "objective gate blocker transitions when actual requirements become ready")
	check(WorldManager.unlock_gate(1) and events_of("gate_unlocked").size() == 1, "gate purchase milestone observes successful real unlock")
	var seq := 0
	var monotonic := true
	for event in logger.events:
		monotonic = monotonic and event.sequence > seq and str(event.state.utc).ends_with("Z")
		seq = event.sequence
	check(monotonic, "milestone sequence is strict and every milestone contains a UTC timestamp")

func test_boss_observations() -> void:
	fresh()
	begin()
	GameState.highest_zone_unlocked = 8
	GameState.zone_kill_counts["2"] = SlimerotCampaign.zone(2).kill_requirement
	WorldManager.travel(2)
	check(WorldManager.start_boss(2), "observed real boss encounter starts")
	var boss: Node = world.arena.boss
	boss.set_physics_process(false)
	GameState._process(10.0)
	boss.take_damage(100.0)
	logger._process(0.0)
	check(is_equal_approx(logger.snapshot().observed_boss_dps, 10.0) and logger.snapshot().observed_boss_zone == 2, "actual boss DPS uses observed HP loss over active encounter time")
	GameState.menu_paused = true
	GameState._process(100.0)
	logger._process(100.0)
	check(is_equal_approx(logger.snapshot().observed_boss_dps, 10.0), "paused boss encounter time does not dilute observed DPS")
	GameState.menu_paused = false
	GameState._process(10.0)
	boss.take_damage(100000000.0)
	logger._process(0.0)
	var defeated := events_of("boss_defeated")
	check(defeated.size() == 1 and defeated[0].details.id == "zone_2" and is_equal_approx(defeated[0].state.observed_boss_damage, float(SlimerotEncounters.BOSSES[2].hp)), "boss defeat captures final hit before arena cleanup and complete HP damage")
	check(is_equal_approx(logger.snapshot().observed_boss_active_seconds, 20.0), "completed boss duration stops at its defeat")
	GameState._process(5.0)
	logger._process(0.0)
	check(is_equal_approx(logger.snapshot().observed_boss_active_seconds, 20.0), "later exploration does not change completed boss DPS")
	GameState.zone_kill_counts["4"] = SlimerotCampaign.zone(4).kill_requirement
	WorldManager.travel(4)
	check(WorldManager.start_boss(4), "second actual boss attempt starts independently")
	GameState._process(6.0)
	world.arena.boss.take_damage(60.0)
	world.arena.end_fight(false, false)
	logger._process(0.0)
	var ended := events_of("boss_attempt_ended")
	check(ended.back().details.reason == "death_or_retreat" and is_equal_approx(logger.snapshot().observed_boss_active_seconds, 6.0) and is_equal_approx(logger.snapshot().observed_boss_damage, 60.0), "same-zone retreat records final observed HP loss and ends the attempt before arena removal")
	GameState._process(50.0)
	logger._process(0.0)
	check(is_equal_approx(logger.snapshot().observed_boss_active_seconds, 6.0), "retreated boss duration does not accumulate during later exploration")
	WorldManager.travel(8)
	GameState.completion_portal_unlocked = true
	check(WorldManager.complete_campaign() and events_of("campaign_completed").size() == 1, "campaign completion is recorded once despite both completion signals")

func test_non_interference_and_export() -> void:
	fresh()
	RollManager.rng.seed = 91823
	RollManager.variant_rng.seed = 27182
	RollManager.request_roll()
	var before := runtime_state()
	begin()
	logger.snapshot()
	logger._process(123.0)
	var summary: Dictionary = logger.export_summary()
	var exported: Dictionary = logger.export_run()
	check(exported.ok and FileAccess.file_exists(exported.json_path) and FileAccess.file_exists(exported.text_path), "explicit export writes separate readable JSON and text diagnostics")
	check(runtime_state() == before, "start, observation, JSON/text building and export leave save data, currencies, RNG, cooldowns and combat unchanged")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(exported.json_path))
	check(parsed is Dictionary and parsed.schema == "Slimerot.playtest" and parsed.schema_version == 1 and parsed.run_id == summary.run_id, "JSON export reads back with stable schema and unique run identity")
	check(parsed.model.fingerprint_sha256.length() == 64 and parsed.model.source_sha256.has("SlimerotCampaign.gd"), "export includes a constants source fingerprint for comparing balance versions")
	check(parsed.latest.lifetime_rolls == GameState.lifetime_rolls and parsed.latest.spendable_rolls == GameState.rolls_balance, "JSON latest state preserves both Roll counters")
	var text := FileAccess.get_file_as_string(exported.text_path)
	var lines := text.split("\n", false)
	var table: PackedStringArray = lines[5].split("\t")
	var rows_parse := table.has("active_play_seconds") and table.has("strongest_equipped") and table.has("segment")
	for line in lines.slice(6): rows_parse = rows_parse and line.split("\t").size() == table.size()
	check(rows_parse and text.contains("model_fingerprint_sha256=") and text.contains(summary.run_id), "text export has consistent tabular labels and parseable equal-width rows")
	var captured_count: int = logger.events.size()
	summary.events.clear()
	summary.latest.equipped_copy_ids.clear()
	check(logger.events.size() == captured_count and runtime_state() == before, "export summaries cannot mutate retained telemetry or live inventory")
	var error_file := directory.path_join("Slimerot-blocked-directory")
	var blocker := FileAccess.open(error_file, FileAccess.WRITE)
	blocker.store_string("Slimerot export failure fixture")
	blocker.close()
	logger.output_directory = error_file.path_join("child")
	var failed: Dictionary = logger.export_run()
	check(not failed.ok and not failed.error.is_empty() and runtime_state() == before, "unwritable export reports failure without affecting progression")
	logger.output_directory = directory
	logger.stop()
	var event_count: int = logger.events.size()
	RollManager.cooldown_remaining = 0.0
	RollManager.request_roll()
	check(logger.events.size() == event_count and not logger.is_processing(), "stopped observer disconnects and does not gather later rolls")
	SaveManager.apply_snapshot(SaveManager.snapshot())
	check(logger.events.size() == event_count, "stopped observer also disconnects from save-load boundaries")

func test_bounds() -> void:
	fresh()
	begin()
	for index in logger.MAX_EVENTS + 7: logger.record_event("bounded_probe", {"index": index})
	check(logger.events.size() == logger.MAX_EVENTS and logger.events[0].kind == "run_started" and logger.dropped_events == 9, "event history stays bounded, retains baseline and reports every eviction")
	for index in logger.MAX_SAMPLES + 4:
		GameState.active_play_seconds += logger.SAMPLE_SECONDS
		logger._process(0.0)
	check(logger.samples.size() == logger.MAX_SAMPLES and logger.samples[0].reason == "initial" and logger.dropped_samples == 5, "snapshot history stays bounded with baseline and exact drop count")
	var data: Dictionary = logger.export_summary()
	check(data.drops.events == logger.dropped_events and data.drops.samples == logger.dropped_samples and data.limits.events == logger.MAX_EVENTS, "export discloses bounds and dropped observations")

func test_overlay() -> void:
	fresh()
	begin()
	var overlay: Node = load("res://dev/SlimerotPlaytestOverlay.gd").new()
	overlay.logger = logger
	overlay.hud = world.hud
	add_child(overlay)
	await get_tree().process_frame
	overlay.set_process(false)
	var safe := Rect2(12, 48, 696, 1208)
	overlay.apply_layout(safe)
	overlay.refresh()
	await get_tree().process_frame
	check(safe.encloses(overlay.panel.get_global_rect()) and safe.encloses(overlay.toggle_button.get_global_rect()) and safe.encloses(overlay.export_button.get_global_rect()), "portrait overlay and explicit touch buttons fit a 720px safe area")
	check(overlay.root.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.metrics.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.status.mouse_filter == Control.MOUSE_FILTER_IGNORE, "all diagnostic surfaces and labels pass pointer input through")
	check(overlay.toggle_button.focus_mode == Control.FOCUS_NONE and overlay.export_button.focus_mode == Control.FOCUS_NONE, "diagnostic controls cannot steal keyboard movement focus")
	var before := runtime_state()
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	get_viewport().push_input(key, true)
	check(not overlay.expanded and not overlay.panel.visible, "real F8 key hides diagnostic details")
	var touch := InputEventScreenTouch.new()
	touch.index = 11
	touch.position = overlay.toggle_button.get_global_rect().get_center()
	touch.pressed = true
	get_viewport().push_input(touch, true)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch, true)
	check(overlay.expanded, "explicit touch button restores diagnostic details")
	key.keycode = KEY_F9
	get_viewport().push_input(key, true)
	check(logger.last_export.get("ok", false) and overlay.status.text.begins_with("Exported"), "real F9 key exports and reports its result")
	check(runtime_state() == before, "overlay keyboard/touch/export controls preserve gameplay state and RNG")
	await suite.capture("Slimerot-stage-9-playtest-overlay")
	remove_child(overlay)
	overlay.free()
