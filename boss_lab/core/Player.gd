class_name BLPlayer
extends CharacterBody2D

signal hit(amount: float, attack: String)
signal dashed
var balance: BLBalance
var hp := 100.0
var touch_direction := Vector2.ZERO
var last_direction := Vector2.UP
var external_force := Vector2.ZERO
var speed_modifier := 1.0
var sliding := false
var dash_remaining := 0.0
var dash_cooldown := 0.0
var hit_remaining := 0.0
var god_mode := false
var bounds := Rect2(40, 220, 640, 760)
var flash := 0.0
var ghosts: Array[Dictionary] = []
var texture: Texture2D = preload("res://assets/player.svg")

func setup(data: BLBalance) -> void:
	balance = data
	var shape := CircleShape2D.new()
	shape.radius = balance.player_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	collision_layer = 2
	collision_mask = 1
	z_index = 7
	set_physics_process(false)
	reset()

func reset() -> void:
	hp = balance.player_hp
	velocity = Vector2.ZERO
	touch_direction = Vector2.ZERO
	dash_remaining = 0.0
	dash_cooldown = 0.0
	hit_remaining = 0.0
	last_direction = Vector2.UP
	ghosts.clear()
	flash = 0.0

func is_dashing() -> bool:
	return dash_remaining > 0.0

func request_dash() -> bool:
	if hp <= 0.0 or dash_cooldown > 0.0 or balance == null: return false
	var direction := movement_input()
	if direction.length() > 0.1: last_direction = direction.normalized()
	dash_remaining = balance.dash_duration
	dash_cooldown = balance.dash_cooldown
	dashed.emit()
	return true

func movement_input() -> Vector2:
	var keyboard := Input.get_vector("lab_left", "lab_right", "lab_up", "lab_down")
	return touch_direction if touch_direction.length() > 0.1 else keyboard

func step(delta: float) -> void:
	flash = maxf(0, flash - delta)
	hit_remaining = maxf(0, hit_remaining - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	var direction := movement_input().limit_length()
	if direction.length() > 0.1 and not is_dashing(): last_direction = direction.normalized()
	if is_dashing():
		var active_delta := minf(delta, dash_remaining)
		velocity = last_direction * balance.dash_distance / balance.dash_duration * (active_delta / maxf(delta, 0.0001))
		if ghosts.size() >= 8: ghosts.pop_front()
		ghosts.append({"at":global_position, "life":0.16})
		dash_remaining = maxf(0.0, dash_remaining - delta)
	else:
		var desired := direction * balance.move_speed * speed_modifier + external_force.limit_length(100.0)
		velocity = velocity.move_toward(desired, 680.0 * delta) if sliding else desired
	move_and_collide(velocity * delta)
	global_position = global_position.clamp(bounds.position + Vector2.ONE * balance.player_radius, bounds.end - Vector2.ONE * balance.player_radius)
	for index in range(ghosts.size() - 1, -1, -1):
		ghosts[index].life -= delta
		if ghosts[index].life <= 0: ghosts.remove_at(index)
	rotation = 0.0
	queue_redraw()

func take_hit(amount: float, attack: String) -> bool:
	if hp <= 0.0 or amount <= 0.0 or god_mode or is_dashing() or hit_remaining > 0.0: return false
	var applied := minf(hp, amount)
	hp -= applied
	hit_remaining = balance.hit_grace
	flash = 0.14
	hit.emit(applied, attack)
	queue_redraw()
	return true

func _draw() -> void:
	for ghost in ghosts: draw_circle(Vector2(ghost.at) - global_position, 12, Color(0.55, 0.9, 1.0, float(ghost.life) * 2.5))
	draw_circle(Vector2.ZERO, 18, Color("181c35"))
	draw_texture_rect(texture, Rect2(-25, -25, 50, 50), false, Color.WHITE if flash <= 0 else Color("ff9783"))
	# The bright ring is the exact 12px damage radius; sprite protrusions are cosmetic.
	draw_arc(Vector2.ZERO, balance.player_radius if balance else 12.0, 0, TAU, 32, Color("92eaff"), 2, true)
	if god_mode: draw_arc(Vector2.ZERO, 21, 0, TAU, 32, Color("c9a8ff"), 2, true)

