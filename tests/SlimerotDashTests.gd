extends Node

var suite: Node
var world: Node
var player: SlimerotPlayer
const STEP := 1.0 / 60.0

func check(value: bool, label: String) -> void:
	suite.check(value, "Dash15 · " + label)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.menu_paused = false
	GameState.suspended = false
	WorldManager.travel(0)
	world.hud.joystick.reset()
	player.cancel_dash(true)
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]: Input.action_release(action)

func frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
		player._physics_process(STEP)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	player = world.player
	var process_states := [player.is_physics_processing(), CombatManager.is_physics_processing(), RollManager.is_processing(), GameState.is_processing()]
	player.set_physics_process(false)
	CombatManager.set_physics_process(false)
	RollManager.set_process(false)
	GameState.set_process(false)
	fresh()
	check(not player.request_dash() and not player.is_dashing(), "fresh saves cannot Dash before the tutorial unlock")
	var checkpoint_events: Array[String] = []
	var on_critical := func(reason: String): checkpoint_events.append(reason)
	GameState.critical_change.connect(on_critical)
	check(GameState.unlock_dash() and not GameState.unlock_dash() and checkpoint_events == ["dash_unlocked"], "free permanent unlock commits once without charging any currency")
	GameState.critical_change.disconnect(on_critical)
	var baseline := SaveManager.snapshot()
	check(SaveManager.validate(baseline) and baseline.dash_unlocked, "Dash unlock is a validated additive save field")
	GameState.dash_unlocked = false
	SaveManager.apply_snapshot(baseline)
	check(GameState.dash_unlocked, "restore preserves the unlocked Dash independently of the current zone")
	var legacy := baseline.duplicate(true)
	legacy.erase("dash_unlocked")
	check(not SaveManager.migrate(legacy).dash_unlocked and not legacy.has("dash_unlocked"), "pre-Z2 legacy save remains locked and migration leaves source data untouched")
	legacy.highest_zone_unlocked = 2
	check(SaveManager.validate(SaveManager.migrate(legacy)) and SaveManager.migrate(legacy).dash_unlocked, "old save at Z2 receives Dash before any first-boss defeat")
	legacy.highest_zone_unlocked = 8
	check(SaveManager.migrate(legacy).dash_unlocked, "late legacy saves retain access to the new free ability")
	var malformed := baseline.duplicate(true)
	malformed.dash_unlocked = "true"
	check(not SaveManager.validate(malformed), "non-boolean Dash flags cannot silently grant the ability")
	fresh()
	GameState.unlock_dash()
	player.position = Vector2(400, 1000)
	player.facing = Vector2.RIGHT
	player.force_update_transform()
	await get_tree().physics_frame
	check(player.request_dash() and player.is_dashing() and is_equal_approx(player.dash_remaining, 0.16), "Dash starts immediately for 0.16 seconds in the last faced direction")
	var hp_before: float = GameState.player_hp
	CombatManager.damage_player(10)
	check(GameState.player_hp == hp_before, "active Dash is invulnerable through the shared combat damage hook")
	check(not player.request_dash(), "Dash cannot restart while the current burst is active")
	await frames(10)
	check(not player.is_dashing() and is_equal_approx(player.position.x, 640.0) and is_zero_approx(player.global_rotation), "unobstructed velocity burst travels 240 pixels without rotating the player")
	CombatManager.damage_player(10)
	check(GameState.player_hp == hp_before - 10 and player.dash_cooldown_remaining > 0.0, "Dash i-frames end with movement rather than lasting through cooldown")
	check(not player.request_dash(), "cooldown blocks repeated Dash after movement has finished")
	await frames(49)
	check(not player.request_dash(), "Dash remains unavailable before the full one-second cooldown")
	await frames(2)
	check(player.request_dash(), "Dash becomes available again after one second")
	player.cancel_dash(true)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(580, 1000)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 180)
	collider.shape = rectangle
	wall.add_child(collider)
	world.add_child(wall)
	player.position = Vector2(500, 1000)
	player.force_update_transform()
	await get_tree().physics_frame
	player.request_dash()
	await frames(10)
	check(player.position.x > 510.0 and player.position.x <= 551.1 and not player.is_dashing(), "swept body movement stops against a wall without teleporting through it")
	world.remove_child(wall)
	wall.queue_free()
	var children_before := player.get_child_count()
	for index in 1000: player.add_afterimage()
	check(player.afterimages.size() == player.MAX_AFTERIMAGES and player.get_child_count() == children_before, "afterimages use an eight-entry draw buffer with no spawned nodes")
	await frames(12)
	check(player.afterimages.is_empty(), "afterimages fully expire after the burst")
	player.cancel_dash(true)
	GameState.menu_paused = true
	check(not player.request_dash() and not player.is_dashing(), "paused menus cannot trigger Dash")
	GameState.menu_paused = false
	GameState.player_dead = true
	check(not player.request_dash(), "a dead player cannot Dash")
	GameState.player_dead = false
	check(InputMap.has_action("dash") and not InputMap.action_get_events("dash").is_empty(), "desktop Dash has an explicit Q input action")
	fresh()
	player.set_physics_process(process_states[0])
	CombatManager.set_physics_process(process_states[1])
	RollManager.set_process(process_states[2])
	GameState.set_process(process_states[3])
