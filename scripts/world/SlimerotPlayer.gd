class_name SlimerotPlayer
extends CharacterBody2D

var joystick: Control
var facing := Vector2.DOWN
var facing_left := false
var sprite: Texture2D
var animation_time := 0.0
var attack_remaining: Dictionary = {}
var cached_body_style: StyleBoxFlat
const DASH_DURATION := 0.16
const DASH_SPEED := 1500.0
const DASH_COOLDOWN := 1.0
const MAX_AFTERIMAGES := 8
const AFTERIMAGE_LIFETIME := 0.18
var dash_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_direction := Vector2.DOWN
var afterimages: Array[Dictionary] = []
var afterimage_remaining := 0.0
var hit_flash_remaining := 0.0

func _ready() -> void:
	sprite = SlimerotAssets.texture("player", "player")
	cached_body_style = body_style()
	CombatManager.slime_attacked.connect(_slime_attacked)
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 19.0
	shape.shape = circle
	add_child(shape)
	var camera := Camera2D.new()
	camera.position = Vector2(0, -70)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)

func _physics_process(delta: float) -> void:
	# Slimerot's body, collider and following camera remain upright in every direction.
	global_rotation = 0.0
	var paused := GameState.is_paused()
	if GameState.player_dead: cancel_dash()
	var direction := movement_direction() if not paused and not GameState.player_dead else Vector2.ZERO
	if direction.length() > 0.05:
		facing = direction
		if not is_zero_approx(direction.x): facing_left = direction.x < 0.0
	if not paused:
		dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
		if Input.is_action_just_pressed("dash"): request_dash()
	var active_dash_seconds := minf(delta, dash_remaining) if is_dashing() else 0.0
	if active_dash_seconds > 0.0:
		# move_and_slide sweeps the existing body against layer-1 walls. Scale the
		# final physics tick so the unobstructed burst remains exactly 240 pixels.
		velocity = dash_direction * DASH_SPEED * active_dash_seconds / maxf(delta, 0.000001)
		afterimage_remaining -= delta
		if afterimage_remaining <= 0.0:
			add_afterimage()
			afterimage_remaining = 0.025
	else:
		velocity = direction.limit_length() * SkillTreeManager.derived_stats().move_speed
	move_and_slide()
	if active_dash_seconds > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		if dash_remaining == 0.0:
			dash_feedback("dash_finished")
	assert(is_zero_approx(global_rotation), "Slimerot player world rotation must stay zero")
	if not paused:
		animation_time += delta
		hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
		for index in range(afterimages.size() - 1, -1, -1):
			afterimages[index].remaining -= delta
			if afterimages[index].remaining <= 0.0: afterimages.remove_at(index)
		for slot in attack_remaining.keys():
			attack_remaining[slot] = maxf(0.0, float(attack_remaining[slot]) - delta)
			if attack_remaining[slot] <= 0.0: attack_remaining.erase(slot)
		queue_redraw()
	for child in get_children():
		if child is Camera2D:
			var shaking: bool = not WorldManager.boss_active and not RollManager.active_reveal.is_empty() and RollManager.active_reveal.threshold >= 100000 and GameState.settings.screen_shake and not GameState.is_paused()
			var reveal_offset := Vector2(sin(RollManager.reveal_remaining * 53), cos(RollManager.reveal_remaining * 47)) * 2 if shaking else Vector2.ZERO
			var feedback: Node = CombatManager.get("feedback")
			var combat_offset: Vector2 = feedback.camera_offset() if is_instance_valid(feedback) and feedback.has_method("camera_offset") else Vector2.ZERO
			child.offset = (reveal_offset + combat_offset).limit_length(12.0)

func movement_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_instance_valid(joystick) and joystick.direction.length() > 0.0: direction = joystick.direction
	return direction.limit_length()

func request_dash() -> bool:
	if not GameState.dash_unlocked or dash_remaining > 0.0 or dash_cooldown_remaining > 0.0 or GameState.is_paused() or GameState.player_dead: return false
	var direction := movement_direction()
	dash_direction = direction.normalized() if direction.length() > 0.05 else facing.normalized()
	if dash_direction.is_zero_approx(): dash_direction = Vector2.DOWN
	dash_remaining = DASH_DURATION
	dash_cooldown_remaining = DASH_COOLDOWN
	afterimage_remaining = 0.025
	add_afterimage()
	dash_feedback("dash_started")
	queue_redraw()
	return true

func is_dashing() -> bool:
	return dash_remaining > 0.0 and not GameState.is_paused() and not GameState.player_dead

func cancel_dash(reset_cooldown: bool = false) -> void:
	var was_dashing := dash_remaining > 0.0
	dash_remaining = 0.0
	if reset_cooldown: dash_cooldown_remaining = 0.0
	velocity = Vector2.ZERO
	afterimages.clear()
	if was_dashing: dash_feedback("dash_finished")
	queue_redraw()

func dash_feedback(method: String) -> void:
	var feedback: Node = CombatManager.get("feedback")
	if is_instance_valid(feedback) and feedback.has_method(method): feedback.call(method, global_position)

func add_afterimage() -> void:
	if afterimages.size() >= MAX_AFTERIMAGES: afterimages.pop_front()
	afterimages.append({"at": global_position, "remaining": AFTERIMAGE_LIFETIME, "left": facing_left})

func combat_hit_flash() -> void:
	hit_flash_remaining = 0.12
	queue_redraw()

func _slime_attacked(origin: Vector2, _destination: Vector2) -> void:
	for slot in InventoryManager.equipped_copy_ids.size():
		if CombatManager.slime_position(slot).distance_squared_to(origin) < 1.0:
			attack_remaining[slot] = SlimerotAssets.ATTACK_SQUASH_SECONDS
			queue_redraw()
			break

func _draw() -> void:
	if sprite != null:
		for ghost in afterimages:
			var opacity: float = float(ghost.remaining) / AFTERIMAGE_LIFETIME * 0.42
			draw_set_transform(to_local(ghost.at) + Vector2(0, -4), 0.0, Vector2(-1.1 if ghost.left else 1.1, 0.9))
			draw_texture_rect(sprite, Rect2(-33, -33, 66, 66), false, Color(0.54, 1.0, 0.69, opacity))
			draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, 17), 24, Color(0, 0, 0, 0.25))
	if sprite != null:
		var moving := velocity.length() > 1.0
		var bob := sin(animation_time * (10.0 if moving else 3.0)) * (2.5 if moving else 1.0)
		# Flip only the drawing, never the physics body or camera. Vertical travel
		# retains an upright portrait while the facing state still records direction.
		var stretch := Vector2(1.22, 0.82) if is_dashing() else Vector2.ONE
		if is_dashing() and absf(dash_direction.y) > absf(dash_direction.x): stretch = Vector2(0.9, 1.15)
		stretch.x *= -1.0 if facing_left else 1.0
		draw_set_transform(Vector2(0, bob - 4), 0.0, stretch)
		draw_texture_rect(sprite, Rect2(-33, -33, 66, 66), false, Color(1.6, 1.6, 1.6) if hit_flash_remaining > 0.0 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(Vector2.ZERO, 22, Color("e8d1a7"))
		draw_style_box(cached_body_style, Rect2(-18, -6, 36, 32))
		draw_circle(Vector2(-7, -8) + facing * 2.0, 3, Color("172d39"))
		draw_circle(Vector2(7, -8) + facing * 2.0, 3, Color("172d39"))
	for index in InventoryManager.equipped_copy_ids.size():
		var offset := to_local(CombatManager.slime_position(index))
		draw_circle(offset + Vector2(0, 8), 17, Color(0, 0, 0, 0.2))
		var pair := InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[index])
		var progress := float(attack_remaining.get(index, 0.0)) / SlimerotAssets.ATTACK_SQUASH_SECONDS
		SlimerotPortrait.paint(self, offset, 17, pair.slime_id, pair.variant, false, animation_time + index * 0.7, sin(progress * PI))

func body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7fb5ce")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style
