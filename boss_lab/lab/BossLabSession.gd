class_name BLSession
extends Node2D

signal updated
signal attempt_ended(record: Dictionary)
signal selection_changed
var balance: BLBalance = preload("res://data/Balance.tres").duplicate()
var profiles: Array[BLProfile] = []
var selected: BLProfile
var mode := "normal"
var player: BLPlayer
var controller: BLBossController
var context: BLContext
var arena: BLArena
var hud: BLHUD
var stats: BLMetrics
var elapsed := 0.0
var attempt := 0
var hits := 0
var damage_taken := 0.0
var dash_count := 0
var running := false
var god_mode := false
var speed_scale := 1.0
var show_hitboxes := false
var show_telegraphs := true
var ui_paused := false
var dps_preset := "EXPECTED"
var seed := 31017
var damage_by_attack: Dictionary = {}
var last_record: Dictionary = {}
var frame_tick := 0.0
var attack_clock := 0.0
var shot_index := 0
var team_beams: Array[Dictionary] = []
var visual_clock := 0.0
var shake_remaining := 0.0
var shake_amount := 0.0
var dark_overlay: Node2D
var saved_player_processing := false
var configured_phase := 1
var camera: Camera2D
var hit_sound: AudioStreamPlayer
var clear_sound: AudioStreamPlayer

func _ready() -> void:
	get_tree().quit_on_go_back = false
	for pair in [["lab_left", KEY_A, KEY_LEFT], ["lab_right", KEY_D, KEY_RIGHT], ["lab_up", KEY_W, KEY_UP], ["lab_down", KEY_S, KEY_DOWN]]:
		if not InputMap.has_action(pair[0]): InputMap.add_action(pair[0])
		for code in [pair[1], pair[2]]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(pair[0], key)
	for data in [preload("res://data/Espresso.tres"), preload("res://data/Sand.tres"), preload("res://data/Janitor.tres"), preload("res://data/Admin.tres")]: profiles.append(data.duplicate(true))
	selected = profiles[0]
	camera = Camera2D.new()
	camera.position = Vector2(360, 640)
	add_child(camera)
	hit_sound = AudioStreamPlayer.new()
	hit_sound.stream = preload("res://assets/hit.wav")
	hit_sound.volume_db = -13.0
	add_child(hit_sound)
	clear_sound = AudioStreamPlayer.new()
	clear_sound.stream = preload("res://assets/clear.wav")
	clear_sound.volume_db = -9.0
	add_child(clear_sound)
	stats = BLMetrics.new()
	stats.load_local()
	player = BLPlayer.new()
	add_child(player)
	player.setup(balance)
	player.hit.connect(_on_hit)
	player.dashed.connect(func(): dash_count += 1)
	controller = BLBossController.new()
	add_child(controller)
	context = BLContext.new()
	add_child(context)
	context.setup(balance, player, controller)
	context.shook.connect(func(amount): shake_amount = amount; shake_remaining = 0.16)
	controller.defeated.connect(func(): finish_attempt(true, ""))
	arena = BLArena.new()
	add_child(arena)
	arena.setup(context)
	arena.profile = selected
	controller.setup(context, selected)
	controller.active = false
	player.global_position = Vector2(360, 850)
	hud = BLHUD.new()
	add_child(hud)
	hud.setup(self)
	updated.emit()
	if "--boss-lab-test" in OS.get_cmdline_user_args():
		set_physics_process(false)
		var test_runner: Node = load("res://tests/BossLabTests.gd").new()
		add_child(test_runner)
		test_runner.run.call_deferred(self)
	elif "--boss-lab-capture" in OS.get_cmdline_user_args():
		var capture: Node = load("res://tests/BossLabCapture.gd").new()
		add_child(capture)
		capture.run.call_deferred(self)

func select_boss(id: String) -> void:
	if running: finish_attempt(false, "Changed encounter")
	for profile in profiles:
		if profile.id == id: selected = profile; break
	arena.profile = selected
	controller.setup(context, selected)
	controller.active = false
	selection_changed.emit()
	updated.emit()

func set_practice(enabled: bool) -> void:
	if running: finish_attempt(false, "Changed mode")
	mode = "practice" if enabled else "normal"
	if not enabled:
		god_mode = false
		speed_scale = 1.0
		show_hitboxes = false
		show_telegraphs = true
		configured_phase = 1
	updated.emit()

func set_dps(preset: String) -> void:
	if running and mode == "normal": return
	dps_preset = preset.to_upper()
	if dps_preset not in ["LOW", "EXPECTED", "HIGH"]: dps_preset = "EXPECTED"
	updated.emit()

func current_dps() -> float:
	if dps_preset == "LOW": return balance.low_dps
	if dps_preset == "HIGH": return balance.high_dps
	return balance.team_dps

func start_attempt() -> void:
	if running: finish_attempt(false, "Restarted")
	shake_remaining = 0.0
	shake_amount = 0.0
	camera.offset = Vector2.ZERO
	hit_sound.stop()
	clear_sound.stop()
	context.clear()
	context.hazards.peak = 0
	context.projectiles.peak = 0
	context.effects.peak = 0
	ui_paused = false
	elapsed = 0.0
	hits = 0
	damage_taken = 0.0
	dash_count = 0
	damage_by_attack.clear()
	last_record.clear()
	team_beams.clear()
	attack_clock = 0.0
	shot_index = 0
	attempt = stats.next_attempt_number(selected.id, mode)
	# The seed is repeatable across retries: learning is not hidden RNG difficulty.
	context.rng.seed = seed
	player.reset()
	player.god_mode = mode == "practice" and god_mode
	controller.setup(context, selected)
	if mode == "practice" and configured_phase > 1: controller.force_phase(configured_phase)
	player.global_position = Vector2(360, 850)
	context.hazards.show_hitboxes = mode == "practice" and show_hitboxes
	context.projectiles.show_hitboxes = mode == "practice" and show_hitboxes
	context.hazards.show_telegraphs = true if mode == "normal" else show_telegraphs
	running = true
	if hud != null: hud.attempt_started()
	updated.emit()

func retry() -> void:
	start_attempt()

func return_to_menu() -> void:
	if running: finish_attempt(false, "Returned to menu")
	context.clear()
	controller.active = false
	ui_paused = false
	player.touch_direction = Vector2.ZERO
	last_record.clear()
	if hud != null: hud.show_menu()
	updated.emit()
	selection_changed.emit()

func set_phase(value: int) -> void:
	if mode != "practice": return
	configured_phase = clampi(value, 1, selected.phase_thresholds.size() + 1)
	if running: controller.force_phase(configured_phase)
	updated.emit()

func force_attack(id: String = "") -> void:
	if mode != "practice" or not running: return
	if not id.is_empty() and selected.attacks.has(id):
		var required: int = selected.attacks[id].min_phase
		if controller.phase < required: set_phase(required)
	controller.force_attack(id)
	updated.emit()

func _on_hit(amount: float, attack: String) -> void:
	if not running: return
	hits += 1
	damage_taken += amount
	damage_by_attack[attack] = float(damage_by_attack.get(attack, 0.0)) + amount
	context.fx(player.global_position, Color("ff8a70"), 10)
	context.shake(0.25)
	if not DisplayServer.get_name() == "headless": hit_sound.play()
	if player.hp <= 0.0: finish_attempt(false, attack)

func finish_attempt(victory: bool, killer: String) -> void:
	if not running: return
	running = false
	var record := {"boss_id":selected.id, "boss_name":selected.display_name, "mode":mode,
		"attempt":attempt, "duration":elapsed, "phase":controller.highest_phase,
		"boss_hp_remaining":100.0 * controller.hp / selected.max_hp, "hits":hits,
		"dash_count":dash_count, "damage_taken":damage_taken, "damage_by_attack":damage_by_attack.duplicate(),
		"death_attack":killer, "victory":victory, "seed":seed, "dps_preset":dps_preset, "dps":current_dps(),
		"timestamp":Time.get_datetime_string_from_system(true)}
	last_record = record
	stats.record_attempt(record)
	controller.active = false
	if not victory:
		controller.cleanup()
		context.fx(player.global_position, Color("ff8a70"), 18)
	elif not DisplayServer.get_name() == "headless": clear_sound.play()
	player.touch_direction = Vector2.ZERO
	ui_paused = false
	attempt_ended.emit(record)
	updated.emit()

func snapshot() -> Dictionary:
	return {"boss_hp":controller.hp, "boss_max_hp":selected.max_hp, "player_hp":player.hp,
		"player_max_hp":balance.player_hp, "phase":controller.phase, "attack":controller.current_attack,
		"dash_cooldown":player.dash_cooldown, "elapsed":elapsed, "attempt":attempt,
		"damage_taken":damage_taken, "dps":current_dps(), "hits":hits, "dash_count":dash_count,
		"seed":seed, "running":running, "mode":mode, "boss_id":selected.id,
		"projectiles":context.projectiles.count_active(), "hazards":context.hazards.count_active()}

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	visual_clock += delta
	arena.step(delta)
	if running and not ui_paused:
		var scaled := delta * (speed_scale if mode == "practice" else 1.0)
		elapsed += scaled
		player.god_mode = mode == "practice" and god_mode
		context.hazards.show_hitboxes = mode == "practice" and show_hitboxes
		context.projectiles.show_hitboxes = mode == "practice" and show_hitboxes
		context.hazards.show_telegraphs = true if mode == "normal" else show_telegraphs
		controller.step(scaled)
		context.step(scaled)
		if running: player.step(scaled)
		if running and controller.transition_remaining <= 0.0:
			attack_clock += scaled
			while attack_clock >= 1.0 / 3.0:
				attack_clock -= 1.0 / 3.0
				team_beams.append({"from":slime_position(shot_index % 3), "life":0.08})
				shot_index += 1
				controller.take_damage(current_dps() / 3.0)
	else:
		context.effects.step(delta)
		if controller.hp <= 0.0: controller.step(delta)
	for index in range(team_beams.size() - 1, -1, -1):
		team_beams[index].life -= delta
		if team_beams[index].life <= 0.0: team_beams.remove_at(index)
	shake_remaining = maxf(0.0, shake_remaining - delta)
	# Camera movement affects rendering only. CanvasLayer controls stay stable.
	camera.offset = Vector2(sin(visual_clock * 93.0), cos(visual_clock * 77.0)) * shake_amount * 2.0 * minf(1.0, shake_remaining / 0.1)
	frame_tick += delta
	if frame_tick >= 0.1:
		frame_tick = 0.0
		updated.emit()
	queue_redraw()

func slime_position(index: int) -> Vector2:
	return player.global_position + Vector2.from_angle(visual_clock * 0.55 + float(index) * TAU / 3.0) * 36.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			hud.toggle_debug()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			retry()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			if not hud.close_top_modal(): return_to_menu()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_Q, KEY_SPACE] and running and not ui_paused:
			player.request_dash()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	if player == null: return
	for index in 3:
		var point := slime_position(index)
		draw_circle(point, 10, Color("c1ef71"))
		draw_circle(point + Vector2(-3, -2), 1.8, Color("242a42"))
		draw_circle(point + Vector2(3, -2), 1.8, Color("242a42"))
	for beam in team_beams: draw_line(beam.from, controller.global_position, Color("dcffc7"), 2, true)
	if context.darkness > 0.0:
		# Darkening never hides danger colors; hazard/projectile canvas has higher z.
		draw_rect(context.arena, Color(0.015, 0.015, 0.03, minf(context.darkness, 0.40)))

func _exit_tree() -> void:
	if is_instance_valid(hit_sound):
		hit_sound.stop()
		hit_sound.stream = null
	if is_instance_valid(clear_sound):
		clear_sound.stop()
		clear_sound.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):
		if not hud.close_top_modal(): return_to_menu()
