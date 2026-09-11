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
	if ending or GameState.is_paused(): return
	if GameState.player_dead: end_fight(false,true)
	elif not SlimerotEncounters.RESET_BOUNDARY.has_point(to_local(CombatManager.player.global_position)): end_fight(false,false)

func end_fight(won: bool, died: bool) -> void:
	if ending: return
	ending = true
	boss.dead = true
	WorldManager.boss_active = false
	CombatManager.clear_projectiles()
	CombatManager.attack_timers.clear()
	if won: WorldManager.finish_boss_reward(zone_id)
	finished.emit(won,died)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,SlimerotEncounters.ARENA_SIZE),Color("302c3e"))
	for y in range(80,1180,80): draw_line(Vector2(20,y),Vector2(880,y),Color("453e50"),2)
	draw_rect(Rect2(10,10,880,1180),Color("806e85"),false,20)
	draw_rect(SlimerotEncounters.RESET_BOUNDARY,Color("f1c297"),false,4)
	draw_string(ThemeDB.fallback_font,Vector2(120,1110),"Cross the gold boundary to retreat and reset",HORIZONTAL_ALIGNMENT_CENTER,660,22,Color("f1d1a5"))
