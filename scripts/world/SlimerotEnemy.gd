class_name SlimerotEnemy
extends CharacterBody2D

var data: SlimerotData.EnemyData
var hp := 0.0
var dead := false
var attack_remaining := 0.0
var home := Vector2.ZERO
var respawn_remaining := 0.0

func _ready() -> void:
	data = SlimerotData.lagling()
	hp = data.max_hp
	home = position
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	shape.shape = circle
	add_child(shape)
	add_to_group("slimerot_enemies")

func _physics_process(delta: float) -> void:
	if GameState.is_paused():
		return
	if dead:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			dead = false
			hp = data.max_hp
			position = home
			show()
		return
	var player := CombatManager.player
	if not is_instance_valid(player):
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
	var distance := position.distance_to(player.position)
	velocity = position.direction_to(player.position) * data.move_speed if distance < 350 and distance > 38 else Vector2.ZERO
	move_and_slide()
	if distance < 45 and attack_remaining == 0.0:
		attack_remaining = data.attack_interval
		CombatManager.damage_player(data.attack_damage)
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		dead = true
		hide()
		respawn_remaining = SlimerotBalance.ENEMY_RESPAWN_SECONDS
		WorldManager.record_kill(data.zone, data.coin_reward)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 12), 26, Color(0, 0, 0, 0.2))
	draw_circle(Vector2.ZERO, 23, Color("d795a6"))
	draw_circle(Vector2(-8, -3), 4, Color("442e44"))
	draw_circle(Vector2(8, -3), 4, Color("442e44"))
	draw_line(Vector2(-9, 9), Vector2(9, 9), Color("442e44"), 3)
	draw_rect(Rect2(-26, -37, 52, 5), Color("273f39"))
	draw_rect(Rect2(-26, -37, 52 * hp / data.max_hp, 5), Color("e8abbd"))
	draw_string(ThemeDB.fallback_font, Vector2(-48, -47), "Lv. 1 Lagling", HORIZONTAL_ALIGNMENT_CENTER, 96, 15, Color("e7e9df"))
