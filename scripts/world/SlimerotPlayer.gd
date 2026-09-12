class_name SlimerotPlayer
extends CharacterBody2D

var joystick: Control
var facing := Vector2.DOWN
var sprite: Texture2D
var animation_time := 0.0
var attack_remaining: Dictionary = {}
var cached_body_style: StyleBoxFlat

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
	var direction := Vector2.ZERO
	if not GameState.is_paused() and not GameState.player_dead:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if is_instance_valid(joystick) and joystick.direction.length() > 0.0:
			direction = joystick.direction
	if direction.length() > 0.05:
		facing = direction
	velocity = direction.limit_length() * SkillTreeManager.derived_stats().move_speed
	move_and_slide()
	if not GameState.is_paused():
		animation_time += delta
		for slot in attack_remaining.keys():
			attack_remaining[slot] = maxf(0.0, float(attack_remaining[slot]) - delta)
			if attack_remaining[slot] <= 0.0: attack_remaining.erase(slot)
		queue_redraw()
	for child in get_children():
		if child is Camera2D:
			var shaking: bool = not RollManager.active_reveal.is_empty() and RollManager.active_reveal.threshold >= 100000 and GameState.settings.screen_shake and not GameState.is_paused()
			child.offset = Vector2(sin(RollManager.reveal_remaining * 53), cos(RollManager.reveal_remaining * 47)) * 2 if shaking else Vector2.ZERO

func _slime_attacked(origin: Vector2, _destination: Vector2) -> void:
	for slot in InventoryManager.equipped_copy_ids.size():
		if CombatManager.slime_position(slot).distance_squared_to(origin) < 1.0:
			attack_remaining[slot] = SlimerotAssets.ATTACK_SQUASH_SECONDS
			queue_redraw()
			break

func _draw() -> void:
	draw_circle(Vector2(0, 17), 24, Color(0, 0, 0, 0.25))
	if sprite != null:
		var moving := velocity.length() > 1.0
		var bob := sin(animation_time * (10.0 if moving else 3.0)) * (2.5 if moving else 1.0)
		var rotation := 0.0
		if absf(facing.x) > absf(facing.y): rotation = -PI * 0.5 if facing.x > 0.0 else PI * 0.5
		elif facing.y < 0.0: rotation = PI
		if moving: rotation += sin(animation_time * 10.0) * 0.055
		draw_set_transform(Vector2(0, bob - 4), rotation)
		draw_texture_rect(sprite, Rect2(-33, -33, 66, 66), false)
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
