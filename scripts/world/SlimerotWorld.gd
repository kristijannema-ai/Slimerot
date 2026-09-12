extends Node2D

var player: SlimerotPlayer
var hud: SlimerotHUD
var zone_root: Node2D
var interactions: Array[SlimerotInteraction] = []
var current_interaction: SlimerotInteraction
var arena: SlimerotBossArena
var rounded_styles: Dictionary = {}

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
	hud.interact_requested.connect(interact)
	WorldManager.zone_changed.connect(build_zone)
	WorldManager.respawn_requested.connect(respawn_player)
	WorldManager.boss_requested.connect(start_boss_arena)
	WorldManager.completion_reached.connect(func(): hud.open_menu("Completion"))
	build_zone(GameState.current_zone)
	if "--slimerot-test" in OS.get_cmdline_user_args():
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
			if not WorldManager.use_exit(): hud.show_notice(WorldManager.gate_blocker(zone_id)))
		interactions[-1].set_meta("gate",zone_id)
		if not SlimerotCampaign.zone(zone_id).boss_id_or_null.is_empty():
			add_interaction(Vector2(770,230),"Boss entrance",func():
				if not WorldManager.start_boss(zone_id): hud.show_notice(WorldManager.boss_encounter_prompt(zone_id)))
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] == zone_id:
			var id: String = row[0]
			add_interaction(row[4],id.replace("_"," ").capitalize()+" · %s Coins" % SlimeDatabase.format_number(row[2]),func(): repair(id))
			interactions[-1].set_meta("structure",id)
	respawn_player()
	if WorldManager.arriving_from_next: player.position = SlimerotCampaign.RETURN_ARRIVAL
	reset_camera()
	queue_redraw()

func reset_camera() -> void:
	for child in player.get_children():
		if child is Camera2D: child.reset_smoothing()

func start_boss_arena(zone_id: int) -> void:
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
		var old := arena
		arena = null
		remove_child(old)
		old.queue_free()
		if not died:
			player.position = Vector2(770,330)
			reset_camera()
			hud.show_notice("Boss defeated! First-kill rewards saved." if won else "Boss reset. Your progress is safe.")
	)

func repair(id: String) -> void:
	if GameState.structure_unlocked_flags.get(id, false):
		hud.open_menu({"skill_tree_shrine":"Skills","sell_terminal":"Inventory","potion_bench":"Potions","fast_travel_pillar":"Map","mutation_lab":"Mutation"}[id])
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
	if GameState.player_dead or WorldManager.boss_active: return
	if not GameState.is_paused() and is_instance_valid(current_interaction):
		current_interaction.activate(player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("roll") and not event.is_echo():
		RollManager.request_roll()
	if event.is_action_pressed("interact") and not event.is_echo():
		interact()

func _process(delta: float) -> void:
	var previous_interaction := current_interaction
	current_interaction = null
	var distance := SlimerotBalance.INTERACT_RANGE + 1.0
	for component in interactions:
		if component.has_meta("gate"): component.prompt = "Enter Completion Portal" if GameState.current_zone == 8 and GameState.completion_portal_unlocked else WorldManager.gate_prompt(int(component.get_meta("gate")))
		if component.has_meta("structure") and GameState.structure_unlocked_flags.get(component.get_meta("structure"),false): component.prompt = "Open " + str(component.get_meta("structure")).replace("_"," ").capitalize()
		var candidate := component.global_position.distance_to(player.global_position)
		if component.is_available(player.global_position) and candidate < distance:
			distance = candidate
			current_interaction = component
	var prompt := current_interaction.prompt if current_interaction != null else ""
	hud.set_interaction(prompt)
	if previous_interaction != current_interaction: queue_redraw()

func rounded(rect: Rect2, color: Color, radius: int = 12) -> void:
	var key := str(color) + str(radius)
	if not rounded_styles.has(key):
		var appearance := StyleBoxFlat.new()
		appearance.bg_color = color
		appearance.set_corner_radius_all(radius)
		rounded_styles[key] = appearance
	draw_style_box(rounded_styles[key], rect)

func label_at(at: Vector2, text: String, size: int = 22, color: Color = Color("e7e9df")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

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
		label_at(Vector2(438, 1194), "BACKYARD", 20, Color("273f39"))
		label_at(Vector2(480, 1230), "↓", 32, Color("273f39"))
	else:
		var gate := SlimerotAssets.structure("gate_open" if WorldManager.gate_open(GameState.current_zone) else "gate_closed")
		if gate != null: draw_texture_rect(gate, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(65, 72), Vector2(130, 130)), false)
		var return_gate := SlimerotAssets.structure("gate_open")
		if return_gate != null: draw_texture_rect(return_gate, Rect2(SlimerotCampaign.RETURN_GATE - Vector2(50, 65), Vector2(100, 100)), false)
		var next := SlimerotCampaign.zone(GameState.current_zone+1).name if GameState.current_zone < 8 else "FINAL BOSS"
		label_at(Vector2(320,100),next.to_upper(),25)
		label_at(Vector2(360,270),"OPEN" if WorldManager.gate_open(GameState.current_zone) else "GATE REQUIREMENTS",20)
		label_at(Vector2(385,1430),"← RETURN",22,Color("273f39"))
		if not SlimerotCampaign.zone(GameState.current_zone).boss_id_or_null.is_empty():
			draw_arc(Vector2(770,230),55,0,TAU,32,Color("c580aa"),12)
			var portal := SlimerotAssets.structure("boss_portal")
			if portal != null: draw_texture_rect(portal, Rect2(710, 160, 120, 120), false)
			label_at(Vector2(700,310),"BOSS ENTRANCE",16)
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] != GameState.current_zone: continue
		var at: Vector2 = row[4]
		var sprite := SlimerotAssets.structure(row[0])
		if sprite != null:
			draw_texture_rect(sprite, Rect2(at - Vector2(64, 74), Vector2(128, 128)), false, Color.WHITE if GameState.structure_unlocked_flags.get(row[0], false) else Color(0.65, 0.65, 0.72))
		else:
			rounded(Rect2(at-Vector2(45,45),Vector2(90,80)),Color("727b89"))
			draw_circle(at-Vector2(0,18),23,Color("b6ed78") if GameState.structure_unlocked_flags.get(row[0],false) else Color("bdabc9"))
		label_at(at+Vector2(-90,65),str(row[0]).replace("_"," ").to_upper(),17)
	if GameState.current_zone == 8 and GameState.completion_portal_unlocked:
		draw_arc(SlimerotCampaign.EXIT_GATE,70,0,TAU,48,Color("d3a6ff"),14)
		var portal := SlimerotAssets.structure("portal")
		if portal != null: draw_texture_rect(portal, Rect2(SlimerotCampaign.EXIT_GATE - Vector2(75, 90), Vector2(150, 150)), false)
	if is_instance_valid(current_interaction):
		draw_arc(current_interaction.position, 70, 0, TAU, 40, Color(0.8, 0.95, 0.6, 0.65), 2, true)
