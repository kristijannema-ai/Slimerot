extends Node

var world: Node
var suite: Node

func check(value: bool, label: String) -> void:
	suite.check(value, "Boss15 · " + label)

func fresh() -> void:
	SaveManager.enabled = false
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	world.hud.close_menu()
	RollManager.reset()
	InventoryManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	GameState.highest_zone_unlocked = 8
	WorldManager.travel(0)

func begin(zone: int) -> SlimerotBoss:
	fresh()
	assert(WorldManager.travel(zone))
	GameState.zone_kill_counts[str(zone)] = SlimerotCampaign.zone(zone).kill_requirement
	assert(WorldManager.start_boss(zone))
	world.arena.set_physics_process(false)
	world.arena.boss.set_physics_process(false)
	var boss: SlimerotBoss = world.arena.boss
	boss.contact_remaining = 1000.0
	GameState.player_hp = 1000.0
	return boss

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var processing := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing(), world.player.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	world.player.set_physics_process(false)
	await test_espresso()
	await test_router_beams()
	await test_janitor_teleport()
	await test_admin_phases()
	test_reset_and_rewards()
	fresh()
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	SaveManager.set_process(processing[2])
	CombatManager.set_physics_process(processing[3])
	world.player.set_physics_process(processing[4])
	await get_tree().process_frame

func test_espresso() -> void:
	var boss := begin(2)
	world.player.global_position = boss.global_position + Vector2(0, 100)
	boss.step(3.0)
	check(boss.phase == "slam_warning" and boss.critical_telegraph_active() and GameState.player_hp == 1000, "Espresso starts a visible slam warning without damage")
	boss.step(0.79)
	check(GameState.player_hp == 1000, "first slam remains harmless throughout its 0.8 second warning")
	boss.step(0.02)
	check(GameState.player_hp == 976 and boss.phase == "slam_release", "first impact deals exactly 24 damage once")
	boss.step(0.22)
	check(boss.phase == "combo_warning", "second slam has its own warning instead of an immediate combo hit")
	boss.step(0.64)
	check(GameState.player_hp == 976, "second slam grants its complete 0.65 second windup")
	boss.step(0.02)
	boss.step(0.22)
	check(GameState.player_hp == 952 and boss.phase == "charge_warning" and boss.charge_start.distance_to(boss.charge_end) <= SlimerotBoss.CHARGE_DISTANCE + 0.01, "two impacts lead into a bounded marked charge lane")
	boss.step(0.0)
	world.reset_camera()
	await suite.capture("Slimerot-p15-espresso-charge")
	var locked_end := boss.charge_end
	world.player.global_position = boss.global_position + Vector2(250, 0)
	boss.step(0.99)
	check(boss.charge_end == locked_end and boss.phase == "charge_warning" and GameState.player_hp == 952, "charge aim stays locked while the player sidesteps for one second")
	boss.step(0.02)
	boss.step(0.6)
	check(boss.phase == "recovery" and boss.velocity == Vector2.ZERO, "charge ends in a stationary punishable recovery")
	boss.step(1.24)
	check(boss.phase == "recovery", "Espresso preserves its 1.25 second recovery window")
	boss.step(0.02)
	check(boss.phase == "chase" and boss.pattern_cycle == 1, "Espresso completes its combo, charge and recovery cycle")

func test_router_beams() -> void:
	var boss := begin(4)
	boss.step(3.2)
	var locked_aim := boss.aim
	world.player.global_position += Vector2(100, 0)
	boss.step(0.79)
	check(boss.phase == "fan_warning" and boss.aim == locked_aim and CombatManager.active_projectile_count() == 0, "Router fan shows locked rays for its full warning")
	boss.step(0.02)
	var valid_fan := CombatManager.active_projectile_count() == 5
	for shot in CombatManager.active_projectiles():
		valid_fan = valid_fan and shot.damage == 50 and shot.source == boss and not shot.allow_friendly_fire and shot.style_zone == 4
	check(valid_fan, "five themed Router shots retain damage and disable boss friendly fire")
	CombatManager.clear_projectiles()
	boss.step(0.3)
	check(boss.phase == "beam_warning" and boss.beam_segments.size() == 1 and boss.critical_telegraph_active(), "fan leads to a visible beam warning")
	boss.step(0.0)
	world.reset_camera()
	await suite.capture("Slimerot-p15-router-beam")
	var beam: Dictionary = boss.beam_segments[0].duplicate()
	var centre: Vector2 = (beam.a + beam.b) * 0.5
	var direction: Vector2 = (beam.b - beam.a).normalized()
	var side := direction.orthogonal()
	var radius := float(beam.width) * 0.5
	check(boss.beam_contains(centre + side * radius) and not boss.beam_contains(centre + side * (radius + 0.01)) and not boss.beam_contains(beam.a - direction * 0.01) and not boss.beam_contains(beam.b + direction * 0.01), "beam damage uses exact rendered rectangle edges and finite endpoints")
	world.player.global_position = centre + side * 120
	boss.step(1.04)
	check(boss.beam_segments[0] == beam and boss.phase == "beam_warning" and GameState.player_hp == 1000, "beam geometry remains fixed as the player moves during its 1.05 second warning")
	boss.step(0.02)
	check(boss.phase == "beam_active" and GameState.player_hp == 1000, "warning-to-active transition never skips straight into damage")
	world.player.global_position = centre + side * (radius + 0.01)
	boss.step(0.01)
	check(GameState.player_hp == 1000, "a player just outside the visible active beam takes no damage")
	world.player.global_position = centre
	boss.step(0.01)
	check(GameState.player_hp == 950, "entering the visible beam deals exactly one 50 damage hit")
	boss.step(0.01)
	check(GameState.player_hp == 950, "sustained beam does not repeat damage each frame")
	boss.step(0.4)
	var sweep: Dictionary = boss.beam_segments[0]
	var sweep_direction: Vector2 = (sweep.b - sweep.a).normalized()
	check(boss.phase == "sweep_warning" and is_zero_approx(direction.dot(sweep_direction)), "perpendicular sweep receives a new explicit warning")
	boss.step(0.9)
	boss.step(0.4)
	check(boss.phase == "recovery" and boss.beam_segments.is_empty(), "Router clears beam geometry before recovery")
	# A slow frame may advance one phase, but cannot omit a warning entirely.
	boss.enter_phase("chase")
	boss.step(30.0)
	check(boss.phase == "fan_warning" and CombatManager.active_projectile_count() == 0, "a long frame cannot skip the fan warning")

func test_janitor_teleport() -> void:
	var boss := begin(6)
	var start := boss.position
	boss.step(2.2)
	check(boss.phase == "teleport_fadeout" and boss.position == start and boss.critical_telegraph_active(), "Janitor begins distortion/fadeout before moving")
	boss.step(SlimerotBoss.FADE_OUT_SECONDS * 0.5)
	check(is_equal_approx(boss.teleport_opacity(), 0.5) and boss.position == start, "fadeout visibly interpolates while the old position remains fixed")
	boss.step(SlimerotBoss.FADE_OUT_SECONDS * 0.5)
	var destination := boss.teleport_destination
	check(boss.phase == "teleport_marker" and boss.teleport_opacity() == 0 and boss.get_parent().to_global(destination).distance_to(world.player.global_position) >= 210, "destination marker identifies a safe-distance arrival while the boss is hidden")
	world.player.global_position = boss.get_parent().to_global(destination)
	boss.step(0.64)
	check(boss.position == start and GameState.player_hp == 1000 and CombatManager.active_projectile_count() == 0, "arrival marker grants its full 0.65 second warning without damage")
	boss.step(0.02)
	check(boss.phase == "teleport_fadein" and boss.position == destination and boss.teleport_index == 1 and GameState.player_hp == 1000, "marked arrival starts fadein without an unannounced contact hit")
	boss.step(SlimerotBoss.FADE_IN_SECONDS * 0.5)
	check(is_equal_approx(boss.teleport_opacity(), 0.5), "fadein visibly interpolates instead of instantly appearing")
	world.player.global_position += Vector2(0, 250)
	boss.step(SlimerotBoss.FADE_IN_SECONDS * 0.5)
	boss.step(0.0)
	world.reset_camera()
	await suite.capture("Slimerot-p15-janitor-arrival")
	var locked_aim := boss.aim
	world.player.global_position += Vector2(150, 0)
	boss.step(0.64)
	check(boss.phase == "burst_warning" and boss.aim == locked_aim and CombatManager.active_projectile_count() == 0, "after arrival, aimed burst gets a separate locked 0.65 second windup")
	boss.step(0.02)
	check(CombatManager.active_projectile_count() == 3 and boss.bursts_fired == 1, "first warned burst emits exactly three shots")
	boss.step(0.2)
	check(boss.phase == "burst_warning" and CombatManager.active_projectile_count() == 3, "second aimed burst gets its own windup")
	boss.step(SlimerotBoss.BURST_WARNING_SECONDS)
	boss.step(0.2)
	check(boss.phase == "beam_warning" and CombatManager.active_projectile_count() == 6 and boss.beam_segments.size() == 2, "two bursts lead to the warned moving safe-zone pattern")
	CombatManager.clear_projectiles()
	var first_gap: Vector2 = boss.get_parent().to_global(Vector2(330, 550))
	var second_gap: Vector2 = boss.get_parent().to_global(Vector2(570, 550))
	check(not boss.beam_contains(first_gap) and boss.beam_contains(second_gap), "first safe column is clearly separated from damaging floor")
	boss.step(SlimerotBoss.BEAM_WARNING_SECONDS)
	world.player.global_position = first_gap
	boss.step(0.01)
	check(GameState.player_hp == 1000, "the marked safe column remains safe during active beams")
	boss.step(SlimerotBoss.BEAM_ACTIVE_SECONDS)
	check(boss.phase == "sweep_warning" and boss.beam_contains(first_gap) and not boss.beam_contains(second_gap), "safe column shifts only behind a fresh visible warning")

func test_admin_phases() -> void:
	var boss := begin(8)
	boss.take_damage(float(boss.data.hp) * 0.6)
	check(boss.enraged and boss.hp == 800000, "Admin enters final phase at exactly 40 percent HP")
	boss.step(1.8)
	check(boss.phase == "fan_warning" and boss.fan_count == 7 and CombatManager.active_projectile_count() == 0, "final phase accelerates cadence with seven telegraphed fan lanes")
	boss.step(0.0)
	world.reset_camera()
	await suite.capture("Slimerot-p15-admin-final")
	boss.aoe_clock = 10.0
	boss.step(0.8)
	check(boss.warnings.is_empty() and CombatManager.active_projectile_count() == 7, "final circles never start on top of an active fan release")
	CombatManager.clear_projectiles()
	boss.enter_phase("recovery")
	check(boss.warnings.size() == 1 and GameState.player_hp == 1000, "final circle starts only in a recovery window with no instant hit")
	var warning_point: Vector2 = boss.warnings[0].at
	world.player.global_position += Vector2(180, 0)
	boss.step(1.19)
	check(boss.warnings.size() == 1 and boss.warnings[0].at == warning_point and GameState.player_hp == 1000, "final circle target is locked through its 1.2 second warning")
	world.player.global_position = warning_point
	boss.step(0.02)
	check(boss.warnings.is_empty() and GameState.player_hp == 830, "final circle resolves once for the preserved 170 damage")

func test_reset_and_rewards() -> void:
	for zone in [2, 4, 6, 8]:
		var boss := begin(zone)
		var arena: SlimerotBossArena = world.arena
		boss.take_damage(100)
		boss.warnings.append({"at": world.player.global_position, "remaining": 1.0})
		boss._add_beam(Vector2(100, 100), Vector2(100, 900), 74)
		CombatManager.fire_enemy_projectile(boss.global_position, Vector2.DOWN, 10, 250, boss)
		var wallet := GameState.coins
		GameState.dash_unlocked = true
		world.player.cancel_dash(true)
		world.player.request_dash()
		arena.end_fight(false, false)
		check(boss.dead and boss.warnings.is_empty() and boss.beam_segments.is_empty() and CombatManager.active_projectile_count() == 0 and GameState.coins == wallet and not WorldManager.is_boss_zone_defeated(zone), "Z%d retreat clears bullets and all warning geometry without awarding a kill" % zone)
		check(not world.player.is_dashing() and world.player.dash_remaining == 0, "retreat cancels active Dash before the world gate arrival")
		assert(WorldManager.start_boss(zone))
		world.arena.set_physics_process(false)
		world.arena.boss.set_physics_process(false)
		boss = world.arena.boss
		arena = world.arena
		check(boss.hp == boss.data.hp and boss.warnings.is_empty() and boss.beam_segments.is_empty(), "Z%d restart restores a clean full-health encounter" % zone)
		boss.take_damage(boss.hp)
		var earned := GameState.coins
		boss.take_damage(9999999)
		arena.end_fight(true, false)
		check(earned == wallet + int(boss.data.coins) and GameState.coins == earned and WorldManager.is_boss_zone_defeated(zone) and not WorldManager.finish_boss_reward(zone), "Z%d death, duplicate hits and repeated finish grant the canonical reward once" % zone)
