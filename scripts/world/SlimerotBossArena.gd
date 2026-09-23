class_name SlimerotBossArena
extends Node2D

signal finished(won: bool, died: bool)
var zone_id := 2
var boss: SlimerotBoss
var ending := false

func _ready() -> void:
	position = SlimerotEncounters.ARENA_ORIGIN
	for rect in [Rect2(0,0,900,20),Rect2(0,0,20,1200),Rect2(880,0,20,1200),Rect2(0,1180,900,20)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)
	boss = SlimerotBoss.new()
	boss.zone_id = zone_id
	boss.position = SlimerotEncounters.BOSS_START
	add_child(boss)
	boss.defeated.connect(func(): end_fight(true,false))

func _physics_process(_delta: float) -> void:
	if ending or GameState.is_paused() or not is_instance_valid(CombatManager.player): return
	if GameState.player_dead: end_fight(false,true)
	elif not SlimerotEncounters.RESET_BOUNDARY.has_point(to_local(CombatManager.player.global_position)): end_fight(false,false)

func end_fight(won: bool, died: bool) -> void:
	if ending: return
	ending = true
	boss.dead = true
	boss.velocity = Vector2.ZERO
	boss.warnings.clear()
	boss.beam_segments.clear()
	WorldManager.boss_active = false
	CombatManager.clear_projectiles()
	CombatManager.attack_timers.clear()
	if won: WorldManager.finish_boss_reward(zone_id)
	finished.emit(won,died)

func _draw() -> void:
	var accent := Color("d6aa79") if zone_id == 2 else Color("efc676") if zone_id == 4 else Color("c0c97c") if zone_id == 6 else Color("c78dfa")
	var floor_color := Color("352d36") if zone_id == 2 else Color("403642") if zone_id == 4 else Color("333a35") if zone_id == 6 else Color("30253f")
	draw_rect(Rect2(Vector2.ZERO, SlimerotEncounters.ARENA_SIZE), Color("1b1727"))
	draw_rect(Rect2(24, 24, 852, 1152), floor_color)
	for y in range(110, 1160, 100):
		for x in range(90, 840, 100):
			var tile := PackedVector2Array([Vector2(x - 42, y - 34), Vector2(x + 34, y - 34), Vector2(x + 42, y - 26), Vector2(x + 42, y + 34), Vector2(x - 34, y + 34), Vector2(x - 42, y + 26)])
			draw_colored_polygon(tile, floor_color.lightened(0.035))
			var edge := tile.duplicate()
			edge.append(tile[0])
			draw_polyline(edge, floor_color.darkened(0.12), 2)
	# Decorative machinery stays outside the open combat floor. No invisible
	# centre obstacles steal space needed for the 240px Dash and crossing lanes.
	for corner in [Vector2(40, 40), Vector2(860, 40), Vector2(40, 1160), Vector2(860, 1160)]:
		var footing := PackedVector2Array([corner + Vector2(-24, -18), corner + Vector2(18, -18), corner + Vector2(26, -8), corner + Vector2(22, 22), corner + Vector2(-24, 22)])
		draw_colored_polygon(footing, accent.darkened(0.55))
		draw_circle(corner, 17, Color("1d192b"))
		draw_circle(corner - Vector2(0, 3), 10, accent)
		draw_line(corner + Vector2(-9, 17), corner + Vector2(9, 17), accent.lightened(0.2), 4)
	draw_rect(Rect2(10, 10, 880, 1180), accent.darkened(0.35), false, 16)
	draw_rect(SlimerotEncounters.RESET_BOUNDARY, Color("f1c297"), false, 4)
	draw_string(ThemeDB.fallback_font, Vector2(110, 1110), "Gold boundary = retreat  ·  Dash across marked lanes", HORIZONTAL_ALIGNMENT_CENTER, 680, 21, Color("f1d1a5"))
