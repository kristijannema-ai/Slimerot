extends Node

var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("Slimerot PASS: ", description)
	else:
		failures += 1
		push_error("Slimerot FAIL: " + description)

func run(world: Node2D) -> void:
	print("Slimerot USER DATA: ", OS.get_user_data_dir())
	SaveManager.enabled = false
	GameState.reset()
	InventoryManager.inventory.clear()
	InventoryManager.equipped_copy_ids.clear()
	InventoryManager.next_copy_id = 1
	RollManager.cooldown_remaining = 0.0
	RollManager.variant_rng.seed = 1234
	WorldManager.travel(0)
	await get_tree().physics_frame
	await capture("Slimerot-bedroom")
	check(GameState.coins == 0 and GameState.rolls_balance == 0 and GameState.lifetime_rolls == 0, "fresh wallets")
	check(GameState.current_zone == 0 and world.player.position.distance_to(Vector2(500, 1190)) <= 110, "Bedroom spawn beside Backyard exit")
	var stats := SkillTreeManager.derived_stats()
	check(stats.luck == 1.0 and stats.roll_cooldown == 2.4 and stats.equipped_slots == 1 and not stats.auto_roll, "canonical derived stats")
	check(GameState.player_hp == 100 and stats.move_speed == 180 and stats.attack_interval == 1.0, "canonical HP, movement and attack interval")
	var start: Vector2 = world.player.position
	Input.action_press("move_right")
	for index in 30:
		await get_tree().physics_frame
	check(world.player.position.x > start.x + 70, "desktop movement at 180 px/s")
	var before_roll: Vector2 = world.player.position
	check(RollManager.request_roll(), "first roll accepted while moving")
	check(GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1, "exactly +1 Rolls and +1 Lifetime Roll")
	check(InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity == 1, "guaranteed Tung Tung Tung Sahur ownership")
	check(InventoryManager.equipped_copy_ids.size() == 1, "first slime auto-equipped")
	await capture("Slimerot-first-roll")
	check(not RollManager.request_roll() and GameState.lifetime_rolls == 1, "cooldown rejects duplicate completion")
	for index in 10:
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(world.player.position.x > before_roll.x + 15, "movement continues through reveal")
	world.player.position = Vector2(935, 1100)
	Input.action_press("move_right")
	for index in 20:
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(world.player.position.x <= 950, "solid world collision")
	world.player.position = SlimerotBalance.ENTRANCES[0]
	await get_tree().process_frame
	world._process(0.0)
	world.interact()
	await get_tree().process_frame
	check(GameState.current_zone == 1 and world.zone_root.name == "SlimerotBackyard", "context interaction enters real Backyard")
	check(world.get_tree().get_nodes_in_group("slimerot_enemies").size() == 4, "Backyard Laglings instantiated")
	await capture("Slimerot-backyard")
	# Touch index 0 stays held while index 1 presses the real ROLL button.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = world.hud.joystick.global_position + world.hud.joystick.center + Vector2(60, 0)
	touch.pressed = true
	get_viewport().push_input(touch, true)
	await get_tree().process_frame
	check(world.hud.joystick.direction.x > 0.5, "mobile joystick touch capture")
	RollManager.cooldown_remaining = 0.0
	var mobile_roll := InputEventScreenTouch.new()
	mobile_roll.index = 1
	mobile_roll.position = Vector2(550, 1120)
	mobile_roll.pressed = true
	get_viewport().push_input(mobile_roll, true)
	mobile_roll = mobile_roll.duplicate()
	mobile_roll.pressed = false
	get_viewport().push_input(mobile_roll, true)
	await get_tree().process_frame
	check(world.hud.joystick.touch_id == 0, "second touch does not steal movement finger")
	check(GameState.lifetime_rolls == 2, "second finger completes a roll through the real HUD")
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch, true)
	await get_tree().process_frame
	check(world.hud.joystick.direction == Vector2.ZERO, "touch release stops joystick")
	# Keep enemies in range without player input; the manager must perform the kill.
	var enemy: SlimerotEnemy = get_tree().get_nodes_in_group("slimerot_enemies")[0]
	world.player.position = enemy.position + Vector2(0, 140)
	var initial_coins := GameState.coins
	for index in 310:
		await get_tree().physics_frame
	check(GameState.coins >= initial_coins + 5 and int(GameState.zone_kill_counts.get("1", 0)) >= 1, "automatic combat grants direct Coins and zone kill")
	var coins := GameState.coins
	var rolls := GameState.rolls_balance
	CombatManager.damage_player(1000)
	check(GameState.player_hp == 100 and world.player.position.distance_to(SlimerotBalance.ENTRANCES[1]) < 1, "death respawns at current entrance")
	check(GameState.coins == coins and GameState.rolls_balance == rolls and InventoryManager.equipped_copy_ids.size() == 1, "death has no currency or slime loss")
	GameState.coins = 25
	check(WorldManager.repair("skill_tree_shrine") and GameState.coins == 0, "Shrine costs exactly 25 Coins")
	check(not WorldManager.repair("skill_tree_shrine"), "no repeat structure purchase")
	GameState.rolls_balance = 50
	GameState.lifetime_rolls = 50
	check(SkillTreeManager.purchase("auto_roll"), "Auto Roll purchase through shared derived stats")
	GameState.settings.auto_roll_state = true
	RollManager.cooldown_remaining = 0.0
	var lifetime := GameState.lifetime_rolls
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameState.lifetime_rolls == lifetime + 1, "Auto Roll uses the same completion path")
	GameState.settings.auto_roll_state = false
	GameState.structure_unlocked_flags.sell_terminal = true
	var key := SlimerotBalance.FIRST_SLIME + ":normal"
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.inventory[key].favorite = true
	check(InventoryManager.sell_duplicates() == 0, "favorited copies protected from selling")
	InventoryManager.inventory[key].favorite = false
	check(InventoryManager.sell_duplicates() > 0 and InventoryManager.inventory[key].quantity == 1, "duplicates sell while equipped copy remains")
	SaveManager.enabled = true
	GameState.active_potion_type = ""
	var saved := SaveManager.snapshot()
	check(SaveManager.validate(saved), "complete schema validates before writing")
	check(SaveManager.save_game(), "temporary write and atomic rename succeed")
	GameState.coins = 9999
	check(SaveManager.load_game() and GameState.coins == int(saved.coins), "save round-trip restores currencies and ownership")
	check(SaveManager.save_game(), "second generation creates backup")
	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_string("{corrupt")
	file.close()
	check(SaveManager.load_game(), "corrupt main recovers valid backup")
	var invalid := SaveManager.snapshot()
	invalid.inventory[key].copy_ids.append(invalid.equipped_copy_ids[0])
	invalid.inventory[key].quantity += 1
	check(not SaveManager.validate(invalid), "duplicate copy IDs rejected")
	SaveManager.enabled = false
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SaveManager.save_path + suffix)
	var rolling_tests := preload("res://tests/SlimerotRollingTests.gd").new()
	add_child(rolling_tests)
	await rolling_tests.run(world, self)
	await get_tree().process_frame
	await get_tree().process_frame
	print("Slimerot RESULT: %d checks; %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func capture(label: String) -> void:
	if "--slimerot-capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + label + ".png")
