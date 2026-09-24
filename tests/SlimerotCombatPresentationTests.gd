extends Node

var suite: Node
var world: Node

func check(value: bool, label: String) -> void:
	suite.check(value, "Combat15 · " + label)

func settle() -> void:
	for frame in 3: await get_tree().physics_frame

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	GameState.menu_paused = false
	GameState.suspended = false
	world.pending_unlock = 0
	WorldManager.travel(0)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var processing := [CombatManager.is_physics_processing(), RollManager.is_processing(), GameState.is_processing()]
	CombatManager.set_physics_process(false)
	RollManager.set_process(false)
	GameState.set_process(false)
	fresh()
	var feedback := CombatManager.feedback
	var hits := feedback.player_hit_events
	var shakes := feedback.camera_events
	CombatManager.damage_player(5)
	check(feedback.player_hit_events == hits + 1 and feedback.camera_events == shakes + 1, "one accepted player hit emits exactly one camera event")
	check(world.player.hit_flash_remaining > 0 and not GameState.is_paused(), "player flash adds no control lock")
	GameState.settings.screen_shake = false
	check(feedback.camera_offset() == Vector2.ZERO, "screen-shake preference applies to combat")
	GameState.settings.screen_shake = true
	var source := SlimerotEnemy.new()
	source.data = SlimerotCampaign.enemy(1, "shooter")
	source.position = Vector2(400, 1000)
	world.add_child(source)
	source.set_physics_process(false)
	var target := SlimerotEnemy.new()
	target.data = SlimerotCampaign.enemy(1, "tank")
	target.data.max_hp = 203
	target.position = Vector2(550, 1000)
	world.add_child(target)
	target.set_physics_process(false)
	world.player.position = Vector2(500, 1200)
	await settle()
	var particles := feedback.particle_events
	var shot: SlimerotProjectile = CombatManager.fire_enemy_projectile(source.global_position, Vector2.RIGHT, 999, 500, source, true, 1)
	shot.set_physics_process(false)
	shot._physics_process(0.4)
	check(target.hp == 162 and shot.spent, "Shooter swept ray hits another normal enemy for round(203 x .20) = 41")
	check(source.hp == source.data.max_hp, "Shooter excludes its own collider")
	check(feedback.particle_events > particles and target.hit_flash > 0, "enemy hit emits particles and flash/squash")
	var earned := GameState.coins
	for index in 5:
		shot = CombatManager.fire_enemy_projectile(source.global_position, Vector2.RIGHT, 999, 500, source, true, 1)
		shot.set_physics_process(false)
		shot._physics_process(0.4)
		target.take_damage(999)
	check(target.dead and GameState.coins == earned + target.data.coin_reward and GameState.zone_kill_counts.get("1", 0) == 1, "friendly-fire death rewards are committed once, including duplicate impact attempts")
	var boss := SlimerotBoss.new()
	boss.position = Vector2(600, 1000)
	world.add_child(boss)
	boss.set_physics_process(false)
	await settle()
	shot = CombatManager.fire_enemy_projectile(source.global_position, Vector2.RIGHT, 999, 500, source, true, 1)
	shot.set_physics_process(false)
	shot._physics_process(0.7)
	check(boss.hp == boss.data.hp and not shot.spent and not shot.can_hit_normal_enemy(boss), "boss layer is excluded and normal-enemy friendly fire cannot damage bosses")
	CombatManager.clear_projectiles()
	var node_count := CombatManager.get_child_count()
	var ids: Dictionary = {}
	for index in 1000:
		shot = CombatManager.fire_enemy_projectile(Vector2(-5000, -5000), Vector2.RIGHT, 1)
		ids[shot.get_instance_id()] = true
		shot.set_physics_process(false)
		shot._physics_process(6.1)
	check(CombatManager.get_child_count() == node_count and CombatManager.active_projectile_count() == 0 and ids.size() == 1, "1000 spawn/despawn lifetimes reuse a pool slot without any node growth")
	check(feedback.effects.size() == 48 and feedback.get_child_count() == 0, "impact/death effects use 48 fixed records and zero particle nodes")
	for index in CombatManager.PROJECTILE_CAPACITY:
		CombatManager.fire_enemy_projectile(Vector2(-5000, -5000), Vector2.RIGHT, 1)
	check(CombatManager.fire_enemy_projectile(Vector2.ZERO, Vector2.UP, 1) == null and CombatManager.active_projectile_count() == 128, "projectile capacity is bounded even under overload")
	CombatManager.clear_projectiles()
	for node in [source, target, boss]:
		world.remove_child(node)
		node.queue_free()
	fresh()
	GameState.highest_zone_unlocked = 2
	GameState.coins = 10000
	GameState.coins_earned = 10000
	GameState.zone_kill_counts["2"] = SlimerotCampaign.zone(2).kill_requirement
	WorldManager.travel(2)
	world.player.position = SlimerotCampaign.EXIT_GATE + Vector2(0, 80)
	world.update_context()
	check(GameState.dash_unlocked and not WorldManager.is_boss_zone_defeated(2), "approaching Z2 combined gate unlocks Dash before first boss")
	check(world.interactions.filter(func(item): return item.has_meta("gate")).size() == 1 and world.interactions.size() == 3, "boss zone has one progression gate, return gate and structure only")
	check(WorldManager.progression_gate_role(2) == "boss" and WorldManager.use_exit() and WorldManager.boss_active, "pre-clear progression gate starts the boss encounter")
	world.arena.boss.set_physics_process(false)
	world.arena.set_physics_process(false)
	GameState.purchased_skill_node_ids.assign(["R01", "R03"])
	GameState.lifetime_rolls = 100
	GameState.rolls_balance = 35
	GameState.roll_skill_spend = {"R01":25, "R03":40}
	GameState.settings.auto_roll_state = true
	RollManager.cooldown_remaining = 0
	var rolls := GameState.lifetime_rolls
	RollManager._process(0.1)
	check(GameState.lifetime_rolls == rolls + 1 and WorldManager.boss_active, "Auto Roll commits while the boss encounter remains active")
	RollManager.start_reveal({"slime_id":"brainrot_singularity", "variant":"normal", "first_roll":false, "first_discovery":true, "threshold":1000000000})
	world.hud.reveal.layout_card()
	await settle()
	check(world.hud.reveal.combat_compact and world.hud.reveal.card.size.y < 110 and not world.hud.reveal.portrait.visible, "jackpot becomes compact during combat, with no fullscreen dim or portrait")
	check(world.hud.reveal.card.position.y == 138 and world.hud.reveal.card.position.y + world.hud.reveal.card.size.y <= 200, "rare toast occupies the existing currency header, leaving boss title and all arena patterns visible")
	GameState.changed.emit()
	world.hud.refresh()
	check(world.hud.dash_button.visible and not world.hud.dash_button.get_global_rect().intersects(world.hud.roll_button.get_global_rect()) and not world.hud.dash_button.get_global_rect().intersects(world.hud.joystick.get_global_rect()), "dedicated mobile Dash does not overlap joystick or ROLL")
	var player_processing: bool = world.player.is_physics_processing()
	world.player.set_physics_process(false)
	world.player.cancel_dash(true)
	world.hud._process(0)
	var move_touch := InputEventScreenTouch.new()
	move_touch.index = 10
	move_touch.pressed = true
	move_touch.position = world.hud.joystick.global_position + world.hud.joystick.center + Vector2(65, 0)
	get_viewport().push_input(move_touch, true)
	var dash_touch := InputEventScreenTouch.new()
	dash_touch.index = 11
	dash_touch.pressed = true
	dash_touch.position = world.hud.dash_button.get_global_rect().get_center()
	get_viewport().push_input(dash_touch, true)
	dash_touch = dash_touch.duplicate()
	dash_touch.pressed = false
	get_viewport().push_input(dash_touch, true)
	check(world.player.is_dashing() and world.player.dash_direction.x > 0.9 and world.hud.joystick.touch_id == 10, "real second-finger Dash tap starts the aimed burst while movement touch stays held")
	move_touch = move_touch.duplicate()
	move_touch.pressed = false
	get_viewport().push_input(move_touch, true)
	world.player.cancel_dash(true)
	world.player.set_physics_process(player_processing)
	await suite.capture("Slimerot-p15-combat-reveal")
	RollManager.finish_reveal()
	world.arena.boss.take_damage(9999999)
	check(WorldManager.progression_gate_role(2) == "exit" and not WorldManager.boss_active, "boss clear transforms the same gate to onward travel")
	var reward_coins := GameState.coins
	check(not WorldManager.finish_boss_reward(2) and GameState.coins == reward_coins, "first-kill reward remains one-time")
	var snapshot := SaveManager.snapshot()
	check(SaveManager.validate(snapshot), "Dash and boss-gate state use a valid current save")
	SaveManager.enabled = true
	check(SaveManager.save_game(), "boss-gate state checkpoints to disk")
	GameState.boss_defeated_flags.clear()
	GameState.dash_unlocked = false
	check(SaveManager.load_game() and GameState.dash_unlocked and WorldManager.progression_gate_role(2) == "exit", "reload retains transformed gate and permanent Dash")
	SaveManager.enabled = false
	var events: Array[int] = []
	var listener := func(zone: int): events.append(zone)
	WorldManager.zone_unlocked.connect(listener)
	var luck_before := RollManager.get_effective_luck()
	check(WorldManager.use_exit() and GameState.current_zone == 3, "post-clear same gate purchases and enters next zone")
	check(events == [3] and world.hud.zone_banner.text.contains("Zone Luck x3") and is_equal_approx(RollManager.get_effective_luck() / luck_before, 1.5), "unlock beat reports x3 while central luck applies zone factor exactly once")
	var unlocks := feedback.unlock_events
	WorldManager.travel(2)
	WorldManager.use_exit()
	check(events == [3] and feedback.unlock_events == unlocks, "zone unlock event and visual do not replay on revisit")
	WorldManager.zone_unlocked.disconnect(listener)
	fresh()
	CombatManager.set_physics_process(processing[0])
	RollManager.set_process(processing[1])
	GameState.set_process(processing[2])
