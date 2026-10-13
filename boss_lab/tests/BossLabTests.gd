extends Node

var checks := 0
var failures := 0
var benchmarks: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("BOSS LAB PASS: " + label)
	else:
		failures += 1
		push_error("BOSS LAB FAIL: " + label)

func run(session: BLSession) -> void:
	check(not session.running and session.profiles.size() == 4, "Independent launch presents all four profiles")
	check(not session.stats.persistence_enabled, "Test flag protects local player statistics")
	check(session.balance.player_hp == 100 and session.balance.move_speed == 180, "Requested HP and movement baseline")
	check(session.balance.dash_duration == 0.16 and session.balance.dash_cooldown == 1.0 and session.balance.dash_distance == 240, "Central Dash duration, cooldown and distance")
	await get_tree().physics_frame
	await test_player(session)
	test_geometry(session)
	test_session(session)
	var patterns := preload("res://tests/BossLabPatternTests.gd").new()
	patterns.run(session, self)
	var metrics := preload("res://tests/BossLabMetricsTests.gd").new()
	metrics.run(session, self)
	var ui := preload("res://tests/BossLabUITests.gd").new()
	await ui.run(session, self)
	await test_duration_and_stress(session)
	session.return_to_menu()
	session.hit_sound.stop()
	session.clear_sound.stop()
	for frame in 12: await get_tree().process_frame
	print("BOSS LAB BENCHMARK " + JSON.stringify(benchmarks))
	print("BOSS LAB RESULT: %d checks; %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func test_player(session: BLSession) -> void:
	var player := session.player
	player.reset()
	player.global_position = Vector2(150, 720)
	player.touch_direction = Vector2.RIGHT
	var start := player.global_position
	check(player.request_dash(), "Dedicated Dash starts immediately")
	check(not player.take_hit(30, "Dash test"), "Active Dash grants brief invulnerability")
	for index in 10: player.step(0.016)
	check(absf(player.global_position.distance_to(start) - 240.0) < 1.0, "Unobstructed Dash actually travels 240px")
	check(not player.request_dash(), "Dash spam is blocked by cooldown")
	player.reset()
	player.global_position = Vector2(630, 720)
	player.touch_direction = Vector2.RIGHT
	player.request_dash()
	for index in 10: player.step(0.016)
	check(player.global_position.x <= 668.1, "Dash cannot pass the arena collision wall")
	player.reset()
	player.global_position = Vector2(360, 850)
	player.touch_direction = Vector2.RIGHT
	start = player.global_position
	for index in 30: player.step(1.0 / 60.0)
	check(absf(player.global_position.distance_to(start) - 90.0) < 0.6, "Ordinary movement retains 180px/sec")
	player.touch_direction = Vector2.ZERO
	player.hit_remaining = 0
	player.hp = 100
	check(player.take_hit(20, "Coffee") and player.hp == 80, "Damage applies once with exact source")
	check(not player.take_hit(20, "Coffee") and player.hp == 80, "Short hit grace prevents overlapping instant burst damage")
	player.reset()
	await get_tree().physics_frame

func test_geometry(session: BLSession) -> void:
	var pool := session.context.hazards
	var circle := {"kind":"circle", "origin":Vector2(300, 500), "radius":80, "age":0, "warning":0.7, "active":1}
	check(pool.contains(circle, Vector2(379, 500)) and not pool.contains(circle, Vector2(381, 500)), "Circle geometry matches its visible radius")
	var lane := {"kind":"lane", "origin":Vector2(100, 400), "end":Vector2(600, 400), "width":80, "age":0, "warning":0.6, "active":1}
	check(pool.contains(lane, Vector2(350, 439)) and not pool.contains(lane, Vector2(350, 441)), "Lane edges match visible 80px width")
	var rect := {"kind":"rect", "origin":Vector2.ZERO, "rect":Rect2(180, 300, 64, 116), "velocity":Vector2(100, 0), "age":1.5, "warning":0.5, "active":2}
	check(pool.contains(rect, Vector2(281, 310)) and not pool.contains(rect, Vector2(181, 310)), "Moving rectangular cart translates its exact hitbox")
	var ring := {"kind":"ring", "origin":Vector2(360, 600), "radius":100, "width":20, "gap_angle":0.0, "gap_width":0.7, "age":0, "warning":0.6, "active":2}
	check(not pool.contains(ring, Vector2(460, 600)) and pool.contains(ring, Vector2(260, 600)), "Ring safe gap is genuinely non-damaging")
	var wall := {"kind":"wall", "origin":Vector2(360, 500), "width":32, "gaps":[Vector2(250, 390)], "gap_speed":45.0, "gap_bounds":Vector2(46, 674), "age":2.0, "warning":0.5, "active":4}
	var gap: Vector2 = pool.wall_gaps(wall)[0]
	check(not pool.contains(wall, Vector2((gap.x + gap.y) / 2, 500), 12) and pool.contains(wall, Vector2(gap.x - 30, 500)), "Moving Sand Wall visual gap and collision share the same formula")
	var annulus := {"kind":"annulus", "origin":Vector2(360, 600), "safe_radius":200, "width":160, "growth":22, "age":1.85, "warning":1.35, "active":4}
	check(not pool.contains(annulus, Vector2(571, 600), 12) and pool.contains(annulus, Vector2(360, 600), 12), "Event Horizon broad blue band stays safe as it moves")
	var sector := {"kind":"sector", "origin":Vector2(360, 600), "radius":180, "angle":0, "arc":PI / 2, "age":0, "warning":0.7, "active":1}
	check(pool.contains(sector, Vector2(500, 600)) and not pool.contains(sector, Vector2(220, 600)), "Mop sector damage follows its visible directional wedge")
	sector.angle = PI
	check(pool.contains(sector, Vector2(360, 600), 12) and pool.contains(sector, Vector2(371, 600), 12), "Player body intersecting Mop origin cannot hide behind an opposite-facing wedge")
	check(not pool.contains(sector, Vector2(390, 600), 12), "Opposite-facing Mop still leaves a real safe area beyond the body-origin overlap")
	session.context.clear()
	session.player.reset()
	session.player.global_position = Vector2(360, 700)
	session.context.hazard({"kind":"circle", "origin":Vector2(360, 700), "radius":100, "warning":0.65, "active":0.2, "damage":24, "attack":"Telegraph test", "owner":"test"})
	session.running = false
	session.context.step(0.64)
	check(session.player.hp == 100, "Telegraph cannot deal damage before its full warning")
	session.context.step(0.02)
	check(session.player.hp == 76, "Damage begins only when the warning becomes active")
	session.context.clear()
	session.player.reset()
	session.context.hazard({"kind":"field", "origin":session.player.global_position, "radius":100, "warning":0.3, "active":2, "damage":0, "slow":0.01, "pull":9999, "attack":"Control test", "owner":"test"})
	session.context.step(0.31)
	check(session.player.speed_modifier >= 0.38 and session.player.external_force.length() <= 100.1, "Slow/gravity mechanics retain control with bounded influence")
	session.context.clear()

func test_session(session: BLSession) -> void:
	session.set_practice(false)
	session.select_boss("sand")
	session.start_attempt()
	var number := session.attempt
	var began := Time.get_ticks_usec()
	session.retry()
	check(Time.get_ticks_usec() - began < 1000000 and session.running, "Retry completes in under one second without a scene reload")
	check(session.attempt == number + 1, "Instant restart counts the interrupted attempt")
	session.god_mode = true
	session.speed_scale = 0.5
	session.step(0.1)
	check(not session.player.god_mode and absf(session.elapsed - 0.1) < 0.001, "Normal mode ignores God Mode and slow-motion flags")
	var phase := session.controller.phase
	session.set_phase(3)
	check(session.controller.phase == phase, "Normal phase forcing is denied")
	session.player.hp = 10
	session.player.hit_remaining = 0
	session.player.take_hit(15, "Sand Wall Collapse")
	check(not session.running and session.last_record.death_attack == "Sand Wall Collapse" and session.last_record.hits >= 1, "Death records the exact killing attack and hit count")
	session.return_to_menu()
	session.set_practice(false)

func test_duration_and_stress(session: BLSession) -> void:
	var frame_count := 0
	for profile in session.profiles:
		session.select_boss(profile.id)
		session.set_practice(true)
		session.god_mode = true
		session.configured_phase = 1
		session.set_dps("EXPECTED")
		session.start_attempt()
		var nodes := get_tree().get_node_count()
		var start := Time.get_ticks_usec()
		var memory := OS.get_static_memory_usage()
		while session.running and session.elapsed < 200.0:
			session.step(1.0 / 60.0)
			frame_count += 1
		check(not session.running and session.last_record.get("victory", false), profile.id + " automatic representative three-slime team clears in God practice")
		check(session.elapsed >= 90.0 and session.elapsed <= 180.0, profile.id + " Expected DPS duration stays in 90-180s without giant HP")
		check(session.controller.highest_phase == profile.phase_thresholds.size() + 1, profile.id + " reaches every real HP-driven phase")
		check(get_tree().get_node_count() == nodes, profile.id + " full encounter creates no scene nodes per attack/projectile")
		check(session.context.hazards.count_active() == 0 and session.context.projectiles.count_active() == 0, profile.id + " victory clears every transient hazard and shot")
		benchmarks.append({"boss":profile.id, "fight_seconds":session.elapsed, "wall_ms":float(Time.get_ticks_usec() - start) / 1000.0,
			"nodes":nodes, "memory_before":memory, "memory_after":OS.get_static_memory_usage(), "hazard_peak":session.context.hazards.peak,
			"projectile_peak":session.context.projectiles.peak, "fx_peak":session.context.effects.peak})
		await get_tree().process_frame
	# Repeated restarts must keep the same scene/pool population even in Admin phase 4.
	session.select_boss("admin")
	session.set_practice(true)
	session.configured_phase = 4
	var nodes := get_tree().get_node_count()
	var before := OS.get_static_memory_usage()
	for iteration in 100:
		session.retry()
		session.force_attack("orbital_projectiles")
		for frame in 180: session.step(1.0 / 60.0)
	check(get_tree().get_node_count() == nodes, "100 Admin orbital restarts preserve the exact node count")
	check(OS.get_static_memory_usage() - before < 3 * 1024 * 1024, "Repeated transient allocations stay bounded after 100 restarts")
	check(session.context.projectiles.peak <= session.balance.projectile_capacity and session.context.effects.peak <= session.balance.fx_capacity, "Projectile/FX stress respects fixed capacity")
	print("BOSS LAB REAL TICKS: " + str(frame_count + 18000))
