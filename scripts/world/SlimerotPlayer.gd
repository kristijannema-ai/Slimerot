class_name SlimerotPlayer
extends CharacterBody2D

var joystick: Control
var facing := Vector2.DOWN

func _ready() -> void:
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

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if not GameState.is_paused():
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if is_instance_valid(joystick) and joystick.direction.length() > 0.0:
			direction = joystick.direction
	if direction.length() > 0.05:
		facing = direction
	velocity = direction.limit_length() * SkillTreeManager.derived_stats().move_speed
	move_and_slide()
	queue_redraw()
	for child in get_children():
		if child is Camera2D:
			var shaking: bool = not RollManager.active_reveal.is_empty() and RollManager.active_reveal.threshold >= 100000 and GameState.settings.screen_shake and not GameState.is_paused()
			child.offset = Vector2(sin(RollManager.reveal_remaining * 53), cos(RollManager.reveal_remaining * 47)) * 2 if shaking else Vector2.ZERO

func _draw() -> void:
	draw_circle(Vector2(0, 17), 24, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, 22, Color("e8d1a7"))
	draw_style_box(body_style(), Rect2(-18, -6, 36, 32))
	draw_circle(Vector2(-7, -8) + facing * 2.0, 3, Color("172d39"))
	draw_circle(Vector2(7, -8) + facing * 2.0, 3, Color("172d39"))
	for index in InventoryManager.equipped_copy_ids.size():
		var angle := float(index) / maxf(1.0, InventoryManager.equipped_copy_ids.size()) * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 52.0
		draw_circle(offset + Vector2(0, 8), 17, Color(0, 0, 0, 0.2))
		var pair := InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[index])
		SlimerotPortrait.paint(self, offset, 17, pair.slime_id, pair.variant, false, GameState.active_play_seconds)

func body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7fb5ce")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style
