extends Node

# Exercises the real room, CharacterBody collision, shared menus and save writer.
# --slimerot-test already isolates startup saves; this suite has its own file too.
var suite: Node
var world: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Bedroom Hub · " + description)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func blocked(at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 19.0
	query.shape = circle
	query.transform = Transform2D(0, at)
	query.collision_mask = 1
	return not world.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func use_station(id: String) -> void:
	world.hud.close_menu()
	world.player.position = world.zone_root.interaction_position(id)
	world.request_interaction()

func settled() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	SaveManager.enabled = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	world.hud.close_menu()
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	world.hud.joystick.reset()
	WorldManager.travel(0)
	await settled()
	var room: Node2D = world.zone_root
	check(room.name == "SlimerotBedroom" and room is SlimerotZone, "redesign uses the existing Bedroom scene and zone architecture")
	check(room.room_size.is_equal_approx(Vector2(1620, 1458)) and room.scale.is_equal_approx(Vector2(0.9, 0.9)), "room is exactly 10% smaller on both axes")
	check(room.spawn_position.is_equal_approx(Vector2(810, 990)) and is_equal_approx(room.camera_bottom, 1962.0), "spawn and camera garden bounds use the compact room's World coordinates")
	var player_shape := world.player.get_children().filter(func(node): return node is CollisionShape2D)[0] as CollisionShape2D
	check(world.player.global_scale.is_equal_approx(Vector2.ONE) and is_equal_approx(player_shape.shape.radius, 19.0), "room shrink preserves the original player size and collision radius")
	check(world.player.position == room.spawn_position and not blocked(world.player.position), "fresh spawn is on unobstructed floor")
	check(room.navigation.cell_size.is_equal_approx(Vector2(45, 45)), "navigation uses 45-world-pixel cells for the compact room")
	var bed: Vector2 = room.interaction_position("bed")
	var collection: Vector2 = room.interaction_position("collection")
	var shrine: Vector2 = room.interaction_position("skill_tree_shrine")
	var sell: Vector2 = room.interaction_position("sell_terminal")
	var backyard: Vector2 = room.interaction_position("backyard")
	check(bed.x < collection.x and collection.x < shrine.x and bed.y < room.room_size.y * 0.5 and shrine.y < room.room_size.y * 0.5, "bed, collection and shrine follow the reference's upper left/center/right layout")
	check(sell.x > room.room_size.x * 0.65 and sell.y > shrine.y, "Sell Terminal remains lower right")
	check(absf(backyard.x - room.room_size.x * 0.5) < 1 and backyard.y > room.room_size.y * 0.9, "exit anchor is low at bottom center")
	for id in ["bed", "collection", "skill_tree_shrine", "sell_terminal", "backyard"]:
		check(not blocked(room.interaction_position(id)), id + " is reachable by the existing player collider")
		var anchor := room.get_node(room.ANCHOR_PATHS[id]) as Node2D
		var expected_position: Vector2 = world.to_local(anchor.global_position)
		check(room.interaction_position(id).is_equal_approx(expected_position), id + " exposes its scaled World position")
		var matching_component: Array = world.interactions.filter(func(component): return component.global_position.is_equal_approx(anchor.global_position))
		check(matching_component.size() == 1, id + " interaction remains aligned to its visible station after room scaling")
		var route: PackedVector2Array = room.navigation.get_point_path(room.navigation_cell(world.to_global(room.spawn_position)), room.navigation_cell(anchor.global_position))
		check(not route.is_empty(), id + " has a connected floor route from spawn")
	for id in ["bed", "collection", "skill_tree_shrine", "sell_terminal"]:
		check(world.player.test_move(Transform2D(0, room.interaction_position(id)), Vector2(0, -350)), id + " has a solid large prop behind its interaction approach")
	for at in [Vector2(316, 220), Vector2(850, 180), Vector2(1460, 250), Vector2(1516, 920)]:
		check(blocked(room.to_global(at)), "upper portion of large furniture is solid at " + str(at))
	for at in [Vector2(750, 800), Vector2(900, 800), Vector2(1050, 800), Vector2(900, 1100), Vector2(900, 1350), Vector2(900, 1500)]:
		check(not blocked(room.to_global(at)), "central rug/path stays walkable at " + str(at))
	var texts: Array[String] = []
	var solid_count := 0
	for node in descendants(room):
		if node is Label: texts.append(node.text)
		if node is StaticBody2D: solid_count += 1
	check(solid_count >= 8 and solid_count <= 32, "large props and walls have a restrained number of solid bodies")
	for caption in ["Bed", "Rest & Save", "Collection", "View Your Slimes", "Skill Tree Shrine", "Upgrade Your Slime", "Sell Terminal", "Sell Items & Resources", "To Backyard"]:
		check(caption in texts, "world sign displays exact text: " + caption)
	var sign_rows := [
		["BedArea/BedSign", "BedArea/Visuals/BedAndNightstand"],
		["CollectionArea/CollectionSign", "CollectionArea/DeskVisuals/DeskBooksAndChair"],
		["SkillTreeShrine/SkillTreeSign", "SkillTreeShrine/Visuals/StoneShrineAndCrystals"],
		["SellTerminal/SellSign", "SellTerminal/Visuals/MerchantCounterAndCrates"],
	]
	for row in sign_rows:
		var sign_node := room.get_node(row[0]) as Node2D
		var prop := room.get_node(row[1]) as TextureRect
		var plaque_center: Vector2 = sign_node.get_parent().to_global(sign_node.get_base_position() + Vector2(sign_node.plaque_width * 0.5, 0))
		var prop_center: Vector2 = prop.get_global_transform() * (prop.size * 0.5)
		check(is_equal_approx(plaque_center.x, prop_center.x), sign_node.name + " is horizontally centered over its matching prop")
	var garden_sign := room.get_node("BackyardExit/ToBackyardSign") as Node2D
	var garden_center: Vector2 = garden_sign.get_parent().to_global(garden_sign.get_base_position() + Vector2(garden_sign.plaque_width * 0.5, 0))
	check(is_equal_approx(garden_center.x, room.to_global(Vector2(900, 0)).x), "To Backyard sign remains centered on the open path")
	for sign_node in [room.get_node("BedArea/BedSign"), room.get_node("CollectionArea/CollectionSign"), room.get_node("SkillTreeShrine/SkillTreeSign"), room.get_node("SellTerminal/SellSign"), garden_sign]:
		var base: Vector2 = sign_node.get_base_position()
		var lowest := 100.0
		var highest := -100.0
		var bounded := true
		var processing: bool = sign_node.is_processing()
		sign_node.set_process(false)
		# Sixteen simulated seconds cover several cycles and reveal accumulating
		# offsets without making the real gameplay integration test wait for them.
		for frame in 64:
			sign_node._process(0.25)
			var offset: Vector2 = sign_node.position - base
			lowest = minf(lowest, offset.y)
			highest = maxf(highest, offset.y)
			bounded = bounded and absf(offset.y) <= 3.01 and is_zero_approx(offset.x)
		sign_node.set_process(processing)
		check(bounded and highest - lowest > 4.0, sign_node.name + " gently bobs vertically without horizontal drift or accumulating displacement")
	check(world.interactions.size() == 5, "one shared interaction per station plus the ordinary exit")
	use_station("collection")
	check(world.hud.menu_title == "Collection" and is_instance_valid(world.hud.menu), "Collection desk opens the existing Collection tab")
	world.hud.close_menu()
	GameState.coins = 24
	use_station("skill_tree_shrine")
	check(not GameState.structure_unlocked_flags.get("skill_tree_shrine", false) and GameState.coins == 24, "Shrine rejects insufficient funds through WorldManager")
	GameState.coins = 100
	GameState.coins_earned = 100
	use_station("skill_tree_shrine")
	check(GameState.structure_unlocked_flags.get("skill_tree_shrine", false) and GameState.coins == 75, "Shrine preserves its 25 Coin repair")
	use_station("skill_tree_shrine")
	check(world.hud.menu_title == "Skills" and GameState.coins == 75, "repaired Shrine opens the existing Skill Tree without repurchasing")
	world.hud.close_menu()
	use_station("sell_terminal")
	check(GameState.structure_unlocked_flags.get("sell_terminal", false) and GameState.coins == 0, "Sell Terminal preserves its 75 Coin repair")
	use_station("sell_terminal")
	check(world.hud.menu_title == "Team", "Sell Terminal opens the existing Team inventory selling route")
	world.hud.close_menu()
	check(RollManager.request_roll(), "shared roll pipeline creates a valid first-save inventory")
	var copy: String = InventoryManager.equipped_copy_ids[0]
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	check(InventoryManager.sell_duplicates() > 0 and InventoryManager.equipped_copy_ids == [copy], "existing InventoryManager sells only the unprotected duplicate")
	var old_save_path := SaveManager.save_path
	SaveManager.save_path = "res://.godot/Slimerot-bedroom-%d.json" % OS.get_process_id()
	SaveManager.enabled = true
	var old_generation := SaveManager.generation
	var wallet := GameState.coins
	use_station("bed")
	check(SaveManager.generation > old_generation and FileAccess.file_exists(SaveManager.save_path), "Bed calls the shared atomic save writer")
	GameState.coins = wallet + 10
	check(SaveManager.load_game() and GameState.coins == wallet and GameState.current_zone == 0, "bedroom save restores currency and current zone")
	WorldManager.travel(0)
	await settled()
	check(GameState.structure_unlocked_flags.get("skill_tree_shrine", false) and GameState.structure_unlocked_flags.get("sell_terminal", false) and world.player.position == world.zone_root.spawn_position, "save return preserves repairs and uses safe room spawn")
	await suite.capture("Slimerot-bedroom-redesign-center")
	# Test world-space sign placement against the real portrait HUD at the exit.
	world.player.position = Vector2(backyard.x, backyard.y - 60)
	world.reset_camera()
	await settled()
	world.reset_camera()
	await settled()
	var camera: Camera2D = world.player.get_children().filter(func(node): return node is Camera2D)[0]
	var exit_sign: Node2D = world.zone_root.get_node("BackyardExit/ToBackyardSign")
	var sign_rect: Rect2 = exit_sign.get_global_transform_with_canvas() * exit_sign.visual_bounds()
	var player_screen: Vector2 = world.player.get_global_transform_with_canvas().origin
	var player_rect := Rect2(player_screen - Vector2(22, 22), Vector2(44, 44))
	check(get_viewport().get_visible_rect().encloses(sign_rect), "low Backyard sign stays fully visible when approaching the exit")
	var clear_of_controls := true
	for control in [world.hud.roll_button, world.hud.joystick, world.hud.interact_button]:
		if control.is_visible_in_tree():
			clear_of_controls = clear_of_controls and not sign_rect.intersects(control.get_global_rect()) and not player_rect.intersects(control.get_global_rect())
	check(clear_of_controls, "exit sign and walking player remain above the portrait touch controls")
	# Sweep the actual CharacterBody through the open path. No E or UI activation.
	world.player.position = Vector2(backyard.x, backyard.y - 200)
	world.reset_camera()
	Input.action_press("move_down")
	for frame in 150:
		await get_tree().physics_frame
		if GameState.current_zone == 1: break
	Input.action_release("move_down")
	check(GameState.current_zone == 1 and world.zone_root.name == "SlimerotBackyard", "walking straight down the open path enters Backyard automatically")
	for index in 8: world.request_interaction()
	check(GameState.current_zone == 1, "arrival guard prevents immediate repeated interactions bouncing home")
	check(SaveManager.load_game() and GameState.current_zone == 1, "walk transition persists through the existing zone save event")
	world.player.position = SlimerotCampaign.RETURN_GATE - Vector2(0, 230)
	world.update_context()
	world.player.position = SlimerotCampaign.RETURN_GATE
	world.request_interaction()
	await settled()
	check(GameState.current_zone == 0 and world.player.position == world.zone_root.spawn_position, "Backyard return gate rebuilds the same Bedroom at a safe spawn")
	for frame in 15: await get_tree().physics_frame
	check(GameState.current_zone == 0, "return spawn never retriggers the bottom exit")
	check(camera.zoom == Vector2.ONE and camera.limit_right == 1620 and camera.limit_bottom == 1962, "portrait camera follows at its existing zoom within room bounds")
	WorldManager.travel(1)
	check(camera.limit_left == -10000000 and camera.limit_right == 10000000, "room camera limits do not leak into other zones")
	SaveManager.enabled = false
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path + suffix)
	SaveManager.save_path = old_save_path
	WorldManager.travel(0)
