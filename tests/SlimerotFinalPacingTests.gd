extends Node

# Accelerated elapsed-time checks call the real Auto Roll loop/commit backend.
# They do not estimate human playtime or emulate Android force-stop behavior.
var suite: Node
var world: Node
var benchmark: Dictionary = {}

func check(value: bool, label: String) -> void:
	suite.check(value, "Final pace · " + label)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	RollManager.reset()
	InventoryManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	WorldManager.travel(0)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var states := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	await test_equip_stress()
	await test_auto_stress()
	test_telemetry()
	test_model_policies()
	test_consumed_discovery_baseline()
	print("SLIMEROT_P16_BENCHMARK " + JSON.stringify(benchmark))
	fresh()
	GameState.set_process(states[0])
	RollManager.set_process(states[1])
	SaveManager.set_process(states[2])
	CombatManager.set_physics_process(states[3])
	await get_tree().process_frame

func test_equip_stress() -> void:
	fresh()
	GameState.purchased_skill_node_ids.assign(["C02", "C06", "C10", "C15"])
	for row in SlimerotRoster.ROWS:
		for mask in 8: InventoryManager.add_copies(row[0], mask, 1000000)
	check(InventoryManager.inventory.size() == 192 and InventoryManager.next_copy_id == 192000001, "all 24 bases × 8 masks hold 192 million compact identities")
	InventoryManager.auto_equip_strongest()
	await get_tree().process_frame
	var expected := InventoryManager.equipped_copy_ids.duplicate()
	var nodes := get_tree().get_node_count()
	var samples: Array[Dictionary] = []
	var start := Time.get_ticks_usec()
	for batch in 10:
		for iteration in 100: InventoryManager.auto_equip_strongest()
		samples.append({"calls": (batch + 1) * 100, "bytes": OS.get_static_memory_usage(), "nodes": get_tree().get_node_count()})
	var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
	check(expected == InventoryManager.equipped_copy_ids and expected.size() == 5, "Equip Best remains deterministic over 1000 huge-inventory calls")
	check(samples.all(func(sample): return sample.nodes == nodes), "1000 Equip Best calls add zero scene nodes")
	check(int(samples.back().bytes) - int(samples.front().bytes) < 1024 * 1024, "Equip Best steady-state memory growth stays below 1 MiB across ten batches")
	var compact := true
	for pair in InventoryManager.inventory.values():
		compact = compact and pair.copy_ids.is_empty() and pair.copy_ranges.size() == 1 and pair.quantity == 1000000
	check(compact and InventoryManager.copy_lookup_cache.size() <= InventoryManager.LOOKUP_CACHE_LIMIT, "huge quantity stress retains compact ranges and bounded copy lookup cache")
	benchmark.equip_best = {"calls": 1000, "stacks": 192, "quantity_per_stack": 1000000,
		"runtime_ms": elapsed, "per_call_ms": elapsed / 1000.0, "memory_node_samples": samples}

func test_auto_stress() -> void:
	fresh()
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL: GameState.purchased_skill_node_ids.append(row[0])
	GameState.highest_zone_unlocked = 8
	GameState.settings.auto_roll_state = true
	RollManager.rng.seed = 16001
	RollManager.variant_rng.seed = 16002
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	check(cooldown == 0.5, "fastest supported post-campaign Auto Roll cooldown is 0.50 seconds")
	await get_tree().process_frame
	var builds: int = world.hud.menu_build_count
	var initial_nodes := get_tree().get_node_count()
	var samples: Array[Dictionary] = []
	var max_pending := 0
	var commits := [0]
	var observe := func(_result: Dictionary): commits[0] += 1
	RollManager.result_committed.connect(observe)
	var start := Time.get_ticks_usec()
	for minute in 15:
		for tick in 120:
			GameState._process(cooldown)
			RollManager._process(cooldown)
			max_pending = maxi(max_pending, RollManager.reveal_queue.size())
		await get_tree().process_frame
		await get_tree().process_frame
		samples.append({"minute": minute + 1, "rolls": GameState.lifetime_rolls, "bytes": OS.get_static_memory_usage(),
			"nodes": get_tree().get_node_count(), "hud_nodes": world.hud.get_child_count(), "pending": RollManager.reveal_queue.size()})
	RollManager.result_committed.disconnect(observe)
	var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
	check(GameState.lifetime_rolls == 1800 and GameState.rolls_balance == 1800 and commits[0] == 1800, "900 accelerated seconds produce exactly 1800 real Auto Roll commits and +1/+1 each")
	check(samples.all(func(sample): return sample.nodes == initial_nodes), "15-minute Auto Roll has zero scene-node growth with Team closed")
	check(world.hud.menu_build_count == builds and not is_instance_valid(world.hud.menu), "1800 Auto Rolls do not rebuild hidden inventory UI")
	check(max_pending <= 32 and InventoryManager.inventory.size() <= 192, "reveal backlog and stack cardinality stay bounded during fastest Auto Roll")
	check(not GameState.is_paused() and not GameState.player_dead, "rare reveal backlog never pauses gameplay")
	benchmark.auto_roll = {"equivalent_seconds": 900, "real_commits": commits[0], "cooldown": cooldown,
		"runtime_ms": elapsed, "max_pending": max_pending, "memory_node_samples": samples,
		"scope": "real RollManager._process/commit; accelerated 0.5-second ticks, rendering settles twice per minute"}

func test_telemetry() -> void:
	fresh()
	var script: Script = load("res://dev/SlimerotPlaytestLogger.gd")
	var logger: Node = script.new()
	add_child(logger)
	check(logger.start("res://.godot/Slimerot-final-telemetry", true), "local debug logger explicitly opts in")
	logger.set_process(false)
	GameState.coins = 100000000
	GameState.coins_earned = GameState.coins
	GameState.lifetime_rolls = 100000
	GameState.rolls_balance = GameState.lifetime_rolls
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	GameState.highest_zone_unlocked = 8
	GameState.structure_unlocked_flags.sell_terminal = true
	for zone in [2, 4, 6, 8]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	GameState.changed.emit()
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL:
		SkillTreeManager.purchase(row[0])
	for row in SlimerotCoinTree.ROWS:
		SkillTreeManager.purchase(row[0])
	var milestones: Dictionary = logger.milestones
	var required := ["R03", "R08", "R13", "R18", "RO5", "RO8", "RO9", "C02", "C06", "C10", "C15", "C20", "C21", "C22"]
	check(required.all(func(id): return milestones.has("skill:" + id)), "Auto, every Breakthrough/Super/team slot/Fortune have timestamped milestones")
	GameState.structure_unlocked_flags.mutation_lab = true
	GameState.dash_unlocked = true
	for zone in [2, 4, 6, 8]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	GameState.changed.emit()
	logger._on_completion()
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, 3)
	logger._on_roll({"slime_id": SlimerotBalance.FIRST_SLIME, "variant_flags": 3, "variant": SlimerotVariants.key(3)})
	check(logger.milestones.has("first_multi_variant") and logger.milestones.has("structure_repaired:mutation_lab") and logger.milestones.has("final_boss"), "first multi-variant, Variant Shrine and final boss timestamps persist in finite index")
	check([2,4,6,8].all(func(zone): return logger.milestones.has("boss_defeated:zone_%d" % zone)), "every boss clear has a timestamp")
	InventoryManager.auto_equip_strongest()
	WorldManager.travel(1)
	logger._record_sample("throughput_baseline")
	GameState.active_play_seconds += 30.0
	GameState.coins_earned += 60
	GameState.lifetime_rolls += 15
	var state: Dictionary = logger.snapshot()
	check(state.current_zone_chaser_ttk_seconds != null and state.best_effective_rarity == 80000 and state.best_raw_damage == SlimerotRoster.damage(80000), "telemetry reports Chaser TTK and canonical best rarity/damage")
	check(state.coins_per_minute == 120 and state.rolls_per_minute == 30 and state.seconds_since_meaningful_unlock == 30, "30-second sample reports exact earned-Coin/Roll rates and time since meaningful unlock")
	logger.stop()
	remove_child(logger)
	logger.free()

func test_model_policies() -> void:
	var script: Script = load("res://tools/SlimerotPacingModel.gd")
	var model = script.new()
	for convenience in [false, true]:
		var purchased: Array[String] = []
		var valid := true
		for row in model._roll_sequence(convenience):
			var prerequisites: Array = row[2] if row[2] is Array else ([] if str(row[2]).is_empty() else [row[2]])
			for prerequisite in prerequisites: valid = valid and prerequisite in purchased
			valid = valid and row[0] not in purchased
			purchased.append(row[0])
		check(valid and purchased.has("RO5") and purchased.has("RO8") and purchased.has("RO9") and not purchased.has("RO7"), "estimator policy %s obeys prerequisites and includes all Super tiers before post-campaign speed" % str(convenience))
		check((purchased.find("RO5") > purchased.find("R18")) != convenience, "estimator explicitly distinguishes delayed and immediate optional branch purchases")

func test_consumed_discovery_baseline() -> void:
	fresh()
	var prior_copy: String = InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, 3)
	var prior_pair: Dictionary = InventoryManager.pair_for_copy(prior_copy)
	check(InventoryManager.remove_copy(prior_pair, prior_copy) and prior_pair.quantity == 0, "prior multi-variant copy can leave inventory while its collection history remains")
	var script: Script = load("res://dev/SlimerotPlaytestLogger.gd")
	var logger: Node = script.new()
	add_child(logger)
	check(logger.start("res://.godot/Slimerot-final-telemetry", true), "observer starts with a consumed historical discovery")
	logger.set_process(false)
	logger._on_roll({"slime_id": SlimerotBalance.FIRST_SLIME, "variant_flags": 3})
	check(not logger.milestones.has("first_multi_variant"), "reacquiring a previously consumed multi-variant is not a false first discovery")
	logger._on_snapshot_applied(GameState.active_play_seconds)
	logger._on_roll({"slime_id": SlimerotBalance.FIRST_SLIME, "variant_flags": 5})
	check(not logger.milestones.has("first_multi_variant"), "save-load segment uses historical discoveries when resetting the first-multi baseline")
	logger.stop()
	remove_child(logger)
	logger.free()
