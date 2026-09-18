extends Node

# Slimerot Prompt 11 uses real viewport pointer dispatch and an isolated test profile.
var suite: Node
var world: Node
var hud: SlimerotHUD
var transitions := 0
var requests := 0

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Stability input · " + description)

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func fresh() -> void:
	SaveManager.enabled = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	hud.joystick.reset()
	hud.refresh()
	transitions = 0
	requests = 0

func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event, true)

func emulated_mouse(at: Vector2, pressed: bool) -> void:
	mouse(at, pressed, InputEvent.DEVICE_ID_EMULATION)

func mouse(at: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event, true)

func close_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.text in ["Close", "Back"]: return child
		var nested := close_button(child)
		if nested != null: return nested
	return null

func on_transition(_zone: int) -> void:
	transitions += 1

func on_request() -> void:
	requests += 1

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	hud = world.hud
	WorldManager.zone_changed.connect(on_transition)
	hud.interact_requested.connect(on_request)
	await test_interactions()
	await test_close_stack()
	await test_offline_input_lock()
	test_upright_player()
	WorldManager.zone_changed.disconnect(on_transition)
	hud.interact_requested.disconnect(on_request)
	fresh()

func test_interactions() -> void:
	fresh()
	# No process/movement tick between positioning and requesting interaction.
	world.player.position = Vector2(500, 1190)
	world.current_interaction = null
	world.request_interaction()
	check(GameState.current_zone == 1 and transitions == 1, "stationary context request resolves immediately without a movement frame")
	for index in 20: world.request_interaction()
	check(GameState.current_zone == 1 and transitions == 1, "20 repeated requests cannot bounce through the arrival gate")
	world.player.position = Vector2(500, 1180)
	world.update_context()
	world.player.position = SlimerotCampaign.RETURN_GATE
	world.request_interaction()
	check(GameState.current_zone == 0 and transitions == 2, "return gate becomes available after walking away and back")
	fresh()
	await settled()
	var at := hud.interact_button.get_global_rect().get_center()
	touch(21, at, true)
	check(GameState.current_zone == 0 and requests == 0, "Interact press captures intent without activating gameplay")
	for frame in 8: await get_tree().process_frame
	check(GameState.current_zone == 0, "holding Interact does not repeat")
	touch(21, at, false)
	emulated_mouse(at, true)
	emulated_mouse(at, false)
	await settled()
	check(GameState.current_zone == 1 and transitions == 1 and requests == 1, "press-hold-release plus synthesized mouse events activates exactly once")
	for index in 20:
		touch(21, at, true)
		touch(21, at, false)
		await get_tree().process_frame
	check(GameState.current_zone == 1 and transitions == 1, "20 stationary spam taps never double-load or return to Hub")
	fresh()
	await settled()
	at = hud.interact_button.get_global_rect().get_center()
	touch(21, at, true)
	touch(21, at, false)
	check(GameState.current_zone == 1 and transitions == 1 and requests == 1, "single short stationary tap enters Backyard exactly once")
	fresh()
	await settled()
	at = hud.interact_button.get_global_rect().get_center()
	mouse(at, true)
	check(GameState.current_zone == 0, "desktop Interact waits for release")
	mouse(at, false)
	await settled()
	check(GameState.current_zone == 1 and transitions == 1 and requests == 1, "desktop native Button.pressed enters Backyard once")
	fresh()
	# A callback trying to activate again is also rejected synchronously.
	var component: SlimerotInteraction = world.current_interaction
	component.activated.connect(world.request_interaction)
	world.request_interaction()
	check(transitions == 1 and not world.interaction_in_flight and not world.transition_in_flight, "reentrant callbacks cannot start another interaction or transition")

func test_close_stack() -> void:
	fresh()
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	GameState.structure_unlocked_flags.sell_terminal = true
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	var screens := ["Inventory", "Team", "Collection", "Skills", "Roll Settings", "Stats", "Settings", "Potions", "Map", "Mutation", "Completion", "AFK Summary", "Sell Duplicates", "Copies:" + SlimerotBalance.FIRST_SLIME + ":normal"]
	for title in screens:
		var passed := true
		for iteration in 20:
			hud.close_menu()
			hud.open_menu(title)
			await settled()
			var control := close_button(hud.menu)
			if control == null:
				passed = false
				continue
			var at := control.get_global_rect().get_center()
			var before := hud.modal_stack.size()
			touch(22, at, true)
			GameState.changed.emit()
			hud._process(0.6)
			passed = passed and is_instance_valid(control) and hud.modal_stack.size() == before
			touch(22, at, false)
			emulated_mouse(at, true)
			emulated_mouse(at, false)
			await settled()
			passed = passed and hud.modal_stack.size() == before - 1
		check(passed, "%s opens/closes 20 times; state changes retain Close and one tap closes one layer" % title)
	hud.close_menu()

	hud.open_menu("Inventory")
	hud.open_modal("Settings")
	hud.open_modal("Stats")
	await settled()
	var at := close_button(hud.menu).get_global_rect().get_center()
	touch(22, at, true)
	touch(22, at, false)
	emulated_mouse(at, true)
	emulated_mouse(at, false)
	check(hud.modal_stack.size() == 2 and hud.menu_title == "Settings" and GameState.menu_paused, "Close pops only the top modal and preserves an underlying Pause")
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.menu_title == "Team" and not GameState.menu_paused, "Android Back closes Settings and restores its Team parent")
	hud.open_modal("Stats")
	hud.close_modal("Inventory")
	check(hud.menu_title == "Stats" and hud.modal_stack.size() == 1, "close_modal(id) removes only the requested layer")
	hud.close_top_modal()
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.menu_title == "Settings", "Android Back with no modal opens Pause")
	hud.close_menu()

func test_offline_input_lock() -> void:
	fresh()
	SaveManager.offline_processing = true
	hud.show_offline_summary({"pending": true, "seconds_away": 240})
	await settled()
	hud.handle_back()
	hud.open_menu("Inventory")
	hud.open_modal("Settings")
	var at := close_button(hud.menu).get_global_rect().get_center()
	touch(22, at, true)
	touch(22, at, false)
	mouse(at, true)
	mouse(at, false)
	check(hud.menu_title == "AFK Summary" and hud.modal_stack.size() == 1, "catch-up sampling blocks Close, Back and navigation")
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = true
	hud.handle_back()
	check(hud.menu_title == "AFK Summary", "failed durable catch-up commit keeps UI edits locked")
	SaveManager.offline_commit_pending = false
	hud.show_offline_summary({"pending": false, "seconds_away": 240, "rolls": 100, "rolls_earned": 100})
	await settled()
	at = close_button(hud.menu).get_global_rect().get_center()
	touch(22, at, true)
	touch(22, at, false)
	check(hud.modal_stack.is_empty(), "successful catch-up commit restores one-tap Close")
	hud.close_menu()

func test_upright_player() -> void:
	fresh()
	world.player.position = Vector2(500, 600)
	var upright := true
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		world.player.rotation = 0.73
		hud.joystick.direction = direction.normalized()
		world.player._physics_process(1.0 / 60.0)
		upright = upright and is_zero_approx(world.player.global_rotation) and world.player.facing.is_equal_approx(direction.normalized())
		for child in world.player.get_children():
			if child is Camera2D or child is CollisionShape2D: upright = upright and is_zero_approx(child.global_rotation)
		if not is_zero_approx(direction.x): upright = upright and world.player.facing_left == (direction.x < 0.0)
	check(upright, "all eight movement directions retain zero body/collider/camera rotation and change only sprite facing")
	hud.joystick.reset()
