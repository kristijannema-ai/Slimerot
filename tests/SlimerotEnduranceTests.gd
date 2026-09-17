extends Node

# Slimerot allocation/lifetime stress uses real transactions and node teardown.
# Clock-driven minutes below are accelerated simulation, not a human/device soak.
const AUTO_ROLL_STEPS := 3600
const AUTO_ROLL_STEP_SECONDS := 0.5
const PROJECTILE_BATCHES := 60
const TRANSITION_CYCLES := 5

class SlimerotTarget:
	extends Node2D
	var dead := false
	var hp := 1000000.0
	func take_damage(amount: float) -> void:
		hp -= amount

var world: Node
var suite: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Endurance · " + description)

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += node_count(child)
	return count

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var started := Time.get_ticks_msec()
	var process_states := [GameState.is_processing(), RollManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	CombatManager.set_physics_process(false)
	fresh()
	await test_projectile_reclamation()
	await test_scene_reclamation()
	await test_auto_roll_and_reveal_reuse()
	await test_menu_reclamation()
	test_audio_reuse()
	fresh()
	await settled()
	GameState.set_process(process_states[0])
	RollManager.set_process(process_states[1])
	CombatManager.set_physics_process(process_states[2])
	print("Slimerot ENDURANCE: 30 accelerated Auto Roll minutes, 1800 projectile lifetimes, 45 zone loads, 20 arena resets; wall time %.2fs" % ((Time.get_ticks_msec() - started) / 1000.0))

func test_projectile_reclamation() -> void:
	await settled()
	var target := SlimerotTarget.new()
	target.position = Vector2(650, 900)
	world.add_child(target)
	var target_baseline := node_count(world)
	var all_released := true
	var no_retained_children := true
	var exact_hits := true
	for batch in PROJECTILE_BATCHES:
		var references: Array[WeakRef] = []
		var previous_hp := target.hp
		for index in 10:
			var shot: SlimerotProjectile = CombatManager.fire_slime_projectile(Vector2(500, 900), target, 7)
			shot.set_physics_process(false)
			references.append(weakref(shot))
			shot._physics_process(0.31)
			# Finishing twice must not repeat damage or schedule a surviving projectile.
			shot._physics_process(0.31)
		exact_hits = exact_hits and is_equal_approx(target.hp, previous_hp - 70)
		for index in 10:
			var shot: SlimerotProjectile = CombatManager.fire_enemy_projectile(Vector2(-5000, -5000), Vector2.RIGHT, 1)
			shot.set_physics_process(false)
			references.append(weakref(shot))
			shot._physics_process(6.01)
		target.dead = true
		for index in 10:
			var shot: SlimerotProjectile = CombatManager.fire_slime_projectile(Vector2(500, 900), target, 7)
			shot.set_physics_process(false)
			references.append(weakref(shot))
			shot._physics_process(0.01)
		target.dead = false
		await settled()
		for reference in references: all_released = all_released and reference.get_ref() == null
		no_retained_children = no_retained_children and CombatManager.get_child_count() == 0 and node_count(world) == target_baseline
	check(all_released, "all 1800 hit, expired and dead-target projectile instances are freed after deferred deletion")
	check(no_retained_children, "60 mixed projectile batches return both manager and world node counts to baseline")
	check(exact_hits, "600 committed friendly shots each deal damage once during allocation stress")
	target.queue_free()
	await settled()

func test_scene_reclamation() -> void:
	fresh()
	GameState.highest_zone_unlocked = 8
	for zone in [2, 4, 6, 8]: GameState.zone_kill_counts[str(zone)] = SlimerotCampaign.zone(zone).kill_requirement
	await settled()
	var hub_baseline := node_count(world)
	var world_baselines: Dictionary = {}
	var released := true
	var stable := true
	var clean_transitions := true
	var arena_released := true
	for cycle in TRANSITION_CYCLES:
		for zone in range(1, 9):
			var old_zone: WeakRef = weakref(world.zone_root)
			# Transitions must invalidate already-fired projectiles as well as scenery.
			var old_shot: WeakRef = weakref(CombatManager.fire_enemy_projectile(Vector2(-5000, -5000), Vector2.RIGHT, 1))
			WorldManager.travel(zone)
			for enemy in get_tree().get_nodes_in_group("slimerot_enemies"): enemy.set_physics_process(false)
			await settled()
			released = released and old_zone.get_ref() == null and old_shot.get_ref() == null
			clean_transitions = clean_transitions and CombatManager.get_child_count() == 0 and get_tree().get_nodes_in_group("slimerot_enemies").size() == 11
			if not world_baselines.has(zone): world_baselines[zone] = node_count(world)
			stable = stable and node_count(world) == world_baselines[zone]
			if zone in [2, 4, 6, 8]:
				var entered := WorldManager.start_boss(zone)
				if not entered:
					arena_released = false
					continue
				world.arena.boss.set_physics_process(false)
				var old_arena: WeakRef = weakref(world.arena)
				var old_boss: WeakRef = weakref(world.arena.boss)
				CombatManager.fire_enemy_projectile(Vector2(-5000, -5000), Vector2.RIGHT, 1)
				world.arena.end_fight(false, false)
				await settled()
				arena_released = arena_released and old_arena.get_ref() == null and old_boss.get_ref() == null and get_tree().get_nodes_in_group("slimerot_bosses").is_empty()
				stable = stable and node_count(world) == world_baselines[zone] and CombatManager.get_child_count() == 0
		WorldManager.travel(0)
		await settled()
		stable = stable and node_count(world) == hub_baseline
	check(released and clean_transitions, "45 zone loads release prior scene/projectiles and retain exactly the current enemy population")
	check(arena_released, "20 boss retreats release boss, arena walls, connections and projectiles")
	check(stable, "five complete Hub-to-Z8 cycles return every zone and Hub to their original node counts")

func test_auto_roll_and_reveal_reuse() -> void:
	fresh()
	GameState.highest_zone_unlocked = 8
	GameState.lifetime_rolls = 100000
	GameState.rolls_balance = 100000
	GameState.structure_unlocked_flags.sell_terminal = true
	for node in SkillTreeManager.nodes.values():
		if node.tree_type == "Roll": SkillTreeManager.purchase(node.id)
	# Seed a mature collection so real auto-sale can protect one of each pair.
	for row in SlimerotRoster.ROWS: InventoryManager.add_copy(row[0], "normal")
	InventoryManager.equip(InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].copy_ids[0])
	InventoryManager.set_auto_sell(true)
	InventoryManager.set_auto_sell_threshold(4000000)
	GameState.settings.auto_roll_state = true
	RollManager.rng.seed = 108010
	RollManager.variant_rng.seed = 108011
	GameState.changed.emit()
	await settled()
	var nodes_before := node_count(world)
	var reveal_nodes_before := node_count(world.hud.reveal)
	var rolls_before := GameState.rolls_balance
	var lifetime_before := GameState.lifetime_rolls
	var retained_max := 0
	for step in AUTO_ROLL_STEPS:
		RollManager._process(AUTO_ROLL_STEP_SECONDS)
		world.hud.reveal._process(AUTO_ROLL_STEP_SECONDS)
		retained_max = maxi(retained_max, RollManager.reveal_queue.size())
		if step % 120 == 0: await settled()
	check(GameState.rolls_balance - rolls_before == AUTO_ROLL_STEPS and GameState.lifetime_rolls - lifetime_before == AUTO_ROLL_STEPS, "30 accelerated minutes complete 3600 Auto Rolls with exact currency accounting")
	check(retained_max <= SlimerotPresentation.MAX_PENDING_REVEALS, "30-minute repeat feedback backlog remains within its configured bound")
	check(InventoryManager.collection().size() == 24 and InventoryManager.inventory.size() <= 96, "mature Auto Roll keeps the canonical 24-by-four collection namespace")
	GameState.settings.auto_roll_state = false
	while not RollManager.active_reveal.is_empty() or not RollManager.reveal_queue.is_empty(): RollManager._process(5.0)
	await settled()
	check(not world.hud.reveal.active and not world.hud.reveal.visible and RollManager.reveal_queue.is_empty(), "all pending feedback drains without a stuck reveal after Auto Roll stops")
	check(node_count(world.hud.reveal) == reveal_nodes_before and node_count(world) == nodes_before, "3600 reveals reuse the same world, portraits and procedural sparkle nodes")
	var protected := InventoryManager.equipped_copy_ids[0]
	check(not InventoryManager.pair_for_copy(protected).is_empty(), "equipped copy survives 30 minutes of automatic duplicate sales")

func test_menu_reclamation() -> void:
	fresh()
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	await settled()
	var baseline := node_count(world)
	var reclaimed := true
	for iteration in 12:
		for title in ["Inventory", "Team", "Collection", "Skills", "Roll Settings", "Stats", "Settings"]:
			world.hud.open_menu(title)
			var old_menu: WeakRef = weakref(world.hud.menu)
			world.hud.close_menu()
			await settled()
			reclaimed = reclaimed and old_menu.get_ref() == null and node_count(world) == baseline
	check(reclaimed, "84 menu open/close cycles release portrait, control and skill-connection nodes")

func test_audio_reuse() -> void:
	var sound := get_node("/root/SlimerotSound")
	var nodes_before := node_count(sound)
	# Warm the finite asset namespace before measuring repeat cache allocation.
	for cue in SlimerotAssets.AUDIO_IDS: SlimerotAssets.audio(cue)
	for cue in ["exploration", "boss"]: SlimerotAssets.audio(cue, true)
	SlimerotAssets.optional_texture("res://assets/Slimerot_endurance_missing.png")
	SlimerotAssets.optional_audio("res://assets/Slimerot_endurance_missing.ogg")
	var cache_before := [SlimerotAssets._textures.size(), SlimerotAssets._streams.size(), SlimerotAssets._paths.size()]
	for iteration in 1000:
		sound.play_cue(SlimerotAudio.CUE_IDS[iteration % SlimerotAudio.CUE_IDS.size()])
		sound.set_track("boss" if iteration % 2 else "exploration")
		SlimerotAssets.optional_texture("res://assets/Slimerot_endurance_missing.png")
		SlimerotAssets.optional_audio("res://assets/Slimerot_endurance_missing.ogg")
	check(node_count(sound) == nodes_before and sound.voices.size() == SlimerotAudio.MAX_VOICES, "1000 effect/track switches reuse the fixed audio voice pool")
	check(cache_before == [SlimerotAssets._textures.size(), SlimerotAssets._streams.size(), SlimerotAssets._paths.size()], "repeated cue and missing-asset lookups do not grow warmed resource caches")
	sound.set_track("exploration")
