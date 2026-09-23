extends Node2D

var player: SlimerotPlayer
var hud: SlimerotHUD
var zone_root: Node2D
var interactions: Array[SlimerotInteraction] = []
var current_interaction: SlimerotInteraction
var interaction_in_flight := false
var transition_in_flight := false
var arrival_interaction: SlimerotInteraction
var arena: SlimerotBossArena
var rounded_styles: Dictionary = {}
var gate_state_label: Label
var pending_unlock := 0
var gate_animation_remaining := 0.0
var gate_animation_origin := Vector2.ZERO

func _ready() -> void:
	configure_input()
	GameState.changed.connect(queue_redraw)
	player = SlimerotPlayer.new()
	player.name = "SlimerotPlayer"
	add_child(player)
	CombatManager.player = player
	hud = SlimerotHUD.new()
	add_child(hud)
	player.joystick = hud.joystick
	hud.interact_requested.connect(request_interaction)
	WorldManager.zone_changed.connect(build_zone)
	WorldManager.zone_unlocked.connect(func(zone: int): pending_unlock = zone)
	WorldManager.respawn_requested.connect(respawn_player)
	WorldManager.boss_requested.connect(start_boss_arena)
	WorldManager.completion_reached.connect(func(): hud.open_menu("Completion"))
	build_zone(GameState.current_zone)
	# Slimerot diagnostics are optional observers, excluded from player exports.
	if OS.is_debug_build() and "--slimerot-playtest" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://dev/SlimerotPlaytestLogger.gd"):
		var logger: Node = load("res://dev/SlimerotPlaytestLogger.gd").new()
		logger.name = "SlimerotPlaytestLogger"
		add_child(logger)
		var output_directory := "user://Slimerot-playtests"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--slimerot-playtest-output="):
				output_directory = argument.trim_prefix("--slimerot-playtest-output=")
		if logger.start(output_directory) and ResourceLoader.exists("res://dev/SlimerotPlaytestOverlay.gd"):
			var overlay: Node = load("res://dev/SlimerotPlaytestOverlay.gd").new()
			overlay.logger = logger
			overlay.hud = hud
			add_child(overlay)
	if OS.is_debug_build() and "--slimerot-test" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tests/SlimerotTests.gd"):
		var test: Node = load("res://tests/SlimerotTests.gd").new()
		add_child(test)
		test.call_deferred("run", self)

func configure_input() -> void:
	var mapping := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "roll": [KEY_SPACE], "interact": [KEY_E]}
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in mapping[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func build_zone(zone_id: int) -> void:
	transition_in_flight = true
	arrival_interaction = null
	gate_state_label = null
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		arena = null
	if is_instance_valid(zone_root):
		remove_child(zone_root)
		zone_root.queue_free()
	interactions.clear()
	current_interaction = null
	CombatManager.reset_combat()
	var path := "res://scenes/zones/%s.tscn" % SlimerotCampaign.SCENES[zone_id]
	var packed: PackedScene = load(path)
	zone_root = packed.instantiate()
	add_child(zone_root)
	zone_root.z_index = -1
	if zone_id == 0:
		wall(Rect2(0,0,1000,32))
		wall(Rect2(0,0,32,1400))
		wall(Rect2(968,0,32,1400))
		wall(Rect2(0,1368,1000,32))
		wall(Rect2(110,650,175,250))
		wall(Rect2(720,680,175,100))
		wall(Rect2(110,360,280,100))
		add_interaction(Vector2(500,1190),"Enter Backyard",func(): WorldManager.use_exit())
	else:
		add_interaction(SlimerotCampaign.RETURN_GATE,"Return to " + SlimerotCampaign.zone(zone_id-1).name,func(): WorldManager.return_through_gate())
		add_interaction(SlimerotCampaign.EXIT_GATE,WorldManager.gate_prompt(zone_id),func():
			if not WorldManager.use_exit(): hud.show_notice(WorldManager.boss_encounter_prompt(zone_id) if WorldManager.progression_gate_role(zone_id) == "boss" else WorldManager.gate_blocker(zone_id)))
		interactions[-1].set_meta("gate",zone_id)
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] == zone_id:
			var id: String = row[0]
			add_interaction(row[4],("Variant Shrine" if id == "mutation_lab" else id.replace("_"," ").capitalize())+" · %s Coins" % SlimeDatabase.format_number(row[2]),func(): repair(id))
			interactions[-1].set_meta("structure",id)
	build_world_captions(zone_id)
	respawn_player()
	if WorldManager.arriving_from_next: player.position = SlimerotCampaign.RETURN_ARRIVAL
	reset_camera()
	transition_in_flight = false
	if pending_unlock == zone_id and zone_id > 0:
		pending_unlock = 0
		gate_animation_remaining = 1.2
		gate_animation_origin = SlimerotCampaign.RETURN_GATE
		CombatManager.feedback.zone_unlocked(player.global_position)
		hud.show_zone_unlock(zone_id)
	update_context()
	queue_redraw()

func reset_camera() -> void:
	for child in player.get_children():
		if child is Camera2D: child.reset_smoothing()

func start_boss_arena(zone_id: int) -> void:
	player.cancel_dash()
	hud.zone_banner.hide()
	hud.close_menu()
	arena = SlimerotBossArena.new()
	arena.zone_id = zone_id
	arena.z_index = -1
	add_child(arena)
	hud.notice.text = ""
	hud.notice_seconds = 0
	player.global_position = SlimerotEncounters.ARENA_ORIGIN + SlimerotEncounters.PLAYER_START
	reset_camera()
	arena.finished.connect(func(won: bool, died: bool):
		player.cancel_dash()
		var old := arena
		arena = null
		remove_child(old)
		old.queue_free()
		if not died:
			player.position = SlimerotCampaign.EXIT_GATE + Vector2(0, 140)
			if won:
				gate_animation_remaining = 1.2
				gate_animation_origin = SlimerotCampaign.EXIT_GATE
				CombatManager.feedback.burst(SlimerotCampaign.EXIT_GATE, Color("ffda87"), 14, 120, true)
			reset_camera()
			hud.show_notice("Boss defeated! First-kill rewards saved." if won else "Boss reset. Your progress is safe.")
	)

func repair(id: String) -> void:
	if GameState.structure_unlocked_flags.get(id, false):
		hud.open_menu({"skill_tree_shrine":"Skills","sell_terminal":"Team","potion_bench":"Potions","fast_travel_pillar":"Map","mutation_lab":"Variant Shrine"}[id])
	elif WorldManager.repair(id):
		hud.show_notice("Repaired! Available from the Slimerot HUD.")
	else:
		hud.show_notice("Earn more Coins by defeating Laglings.")
	queue_redraw()

func respawn_player() -> void:
	player.position = SlimerotBalance.ENTRANCES[GameState.current_zone]
	player.velocity = Vector2.ZERO
	for child in player.get_children():
		if child is Camera2D:
			child.reset_smoothing()

func wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	zone_root.add_child(body)

func add_interaction(at: Vector2, prompt: String, action: Callable) -> void:
	var component := SlimerotInteraction.new()
	component.position = at
	component.prompt = prompt
	component.activated.connect(action)
	zone_root.add_child(component)
	interactions.append(component)

func interact() -> void:
	request_interaction()

func request_interaction() -> void:
	if interaction_in_flight or transition_in_flight or GameState.player_dead or WorldManager.boss_active or GameState.is_paused(): return
	# Resolve proximity now: a stationary tap must never depend on a movement or
	# process frame updating an old context reference first.
	update_context()
	if not is_instance_valid(current_interaction): return
	interaction_in_flight = true
	var previous_zone := GameState.current_zone
	current_interaction.activate(player.global_position)
	if previous_zone != GameState.current_zone:
		# Arrivals are inside the return gate's range. Suppress that gate until the
		# player leaves it so repeated taps cannot bounce between two loaded zones.
		arrival_interaction = current_interaction
	interaction_in_flight = false
	update_context()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("roll") and not event.is_echo():
		RollManager.request_roll()
	if event.is_action_pressed("interact") and not event.is_echo():
		request_interaction()

func _process(delta: float) -> void:
	if gate_animation_remaining > 0:
		gate_animation_remaining = maxf(0, gate_animation_remaining - delta)
		queue_redraw()
	update_context()

func update_context() -> void:
	if is_instance_valid(gate_state_label):
		gate_state_label.text = "BOSS CHALLENGE" if WorldManager.progression_gate_role(GameState.current_zone) == "boss" else ("OPEN" if WorldManager.gate_open(GameState.current_zone) else "NEXT ZONE")
	if GameState.current_zone == 2 and not GameState.dash_unlocked and player.position.distance_to(SlimerotCampaign.EXIT_GATE) < 210:
		if GameState.unlock_dash(): hud.show_notice("DASH UNLOCKED - dodge through the slam! Aim with movement, then tap DASH.")
	var previous_interaction := current_interaction
	current_interaction = null
	if is_instance_valid(arrival_interaction) and not arrival_interaction.is_available(player.global_position):
		arrival_interaction = null
	var distance := SlimerotBalance.INTERACT_RANGE + 1.0
	for component in interactions:
		if not is_instance_valid(component) or component == arrival_interaction: continue
		if component.has_meta("gate"): component.prompt = "Enter Completion Portal" if GameState.current_zone == 8 and GameState.completion_portal_unlocked else WorldManager.gate_prompt(int(component.get_meta("gate")))
		if component.has_meta("structure") and GameState.structure_unlocked_flags.get(component.get_meta("structure"),false): component.prompt = "Open " + str(component.get_meta("structure")).replace("_"," ").capitalize()
		var candidate := component.global_position.distance_to(player.global_position)
		if component.is_available(player.global_position) and candidate < distance:
			distance = candidate
			current_interaction = component
	var prompt := current_interaction.prompt if current_interaction != null else ""
	hud.set_interaction(prompt)
	hud.interact_button.disabled = interaction_in_flight or transition_in_flight
	if previous_interaction != current_interaction: queue_redraw()

func rounded(rect: Rect2, color: Color, radius: int = 12) -> void:
	var key := str(color) + str(radius)
	if not rounded_styles.has(key):
		var appearance := StyleBoxFlat.new()
		appearance.bg_color = color
		appearance.set_corner_radius_all(radius)
		rounded_styles[key] = appearance
	draw_style_box(rounded_styles[key], rect)

func build_world_captions(zone_id: int) -> void:
	# Captions belong to landmark bounds in the world, not screen-pixel baselines.
	# Their anchored labels stay centered as the camera or phone aspect changes.
	var captions := Node2D.new()
	captions.name = "LandmarkCaptions"
	captions.z_index = 2
	zone_root.add_child(captions)
	if zone_id == 0:
		SlimerotUITheme.world_label(captions, Rect2(408, 1152, 184, 100), "BACKYARD\n↓", 20)
	else:
		var next := SlimerotCampaign.zone(zone_id + 1).name if zone_id < 8 else "FINAL BOSS"
		SlimerotUITheme.world_label(captions, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(230, 150), Vector2(460, 55)), next.to_upper(), 25)
		gate_state_label = SlimerotUITheme.landmark_label(captions, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(65, 72), Vector2(130, 130)), "", 20)
		SlimerotUITheme.world_label(captions, Rect2(SlimerotCampaign.RETURN_GATE - Vector2(100, 30), Vector2(200, 60)), "← RETURN", 22)
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] != zone_id: continue
		var id := str(row[0])
		var title := "VARIANT SHRINE" if id == "mutation_lab" else id.replace("_", " ").to_upper()
		var landmark := Rect2(Vector2(row[4]) - Vector2(64, 74), Vector2(128, 128))
		var caption := SlimerotUITheme.landmark_label(captions, landmark, title, 18)
		caption.set_meta("structure_id", id)

func _draw() -> void:
	if GameState.current_zone == 0:
		rounded(Rect2(0, 0, 1000, 1400), Color("413e49"), 0)
		for y in range(40, 1400, 64):
			draw_line(Vector2(32, y), Vector2(968, y), Color("4d4850"), 2)
		rounded(Rect2(345, 730, 310, 350), Color("656176"), 20)
		rounded(Rect2(365, 750, 270, 310), Color("777086"), 18)
		rounded(Rect2(110, 650, 175, 250), Color("303b4b"))
		rounded(Rect2(120, 662, 155, 226), Color("91b3b9"))
		rounded(Rect2(133, 672, 130, 60), Color("dfdfc8"))
		rounded(Rect2(120, 744, 155, 144), Color("658d95"))
		rounded(Rect2(720, 680, 175, 100), Color("9e7858"))
		rounded(Rect2(743, 659, 75, 45), Color("254048"))
		rounded(Rect2(753, 666, 55, 27), Color("a0d39d"))
		rounded(Rect2(110, 360, 280, 100), Color("9e7858"))
		rounded(Rect2(408, 1152, 184, 100), Color("b6ed78"), 15)
	else:
		var gate := SlimerotAssets.structure("boss_portal" if WorldManager.progression_gate_role(GameState.current_zone) == "boss" else ("gate_open" if WorldManager.gate_open(GameState.current_zone) or WorldManager.is_boss_zone_defeated(GameState.current_zone) else "gate_closed"))
		if gate != null: draw_texture_rect(gate, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(65, 72), Vector2(130, 130)), false)
		var return_gate := SlimerotAssets.structure("gate_open")
		if return_gate != null: draw_texture_rect(return_gate, Rect2(SlimerotCampaign.RETURN_GATE - Vector2(50, 65), Vector2(100, 100)), false)
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] != GameState.current_zone: continue
		var at: Vector2 = row[4]
		var sprite := SlimerotAssets.structure(row[0])
		if sprite != null:
			draw_texture_rect(sprite, Rect2(at - Vector2(64, 74), Vector2(128, 128)), false, Color.WHITE if GameState.structure_unlocked_flags.get(row[0], false) else Color(0.65, 0.65, 0.72))
		else:
			rounded(Rect2(at-Vector2(45,45),Vector2(90,80)),Color("727b89"))
			draw_circle(at-Vector2(0,18),23,Color("b6ed78") if GameState.structure_unlocked_flags.get(row[0],false) else Color("bdabc9"))
	if GameState.current_zone == 8 and GameState.completion_portal_unlocked:
		draw_arc(SlimerotCampaign.EXIT_GATE,70,0,TAU,48,Color("d3a6ff"),14)
		var portal := SlimerotAssets.structure("portal")
		if portal != null: draw_texture_rect(portal, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(75, 90), Vector2(150, 150)), false)
	if gate_animation_remaining > 0.0:
		var at := gate_animation_origin
		draw_arc(at, 60 + (1.2 - gate_animation_remaining) * 95, 0, TAU, 48, Color(1, 0.86, 0.5, gate_animation_remaining / 1.2), 7, true)
	if is_instance_valid(current_interaction):
		draw_arc(current_interaction.position, 70, 0, TAU, 40, Color(0.8, 0.95, 0.6, 0.65), 2, true)
