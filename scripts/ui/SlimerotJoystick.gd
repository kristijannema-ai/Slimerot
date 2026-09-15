class_name SlimerotJoystick
extends Control

var direction := Vector2.ZERO
var touch_id := -1
var radius := SlimerotPresentation.JOYSTICK_RADIUS
var center := Vector2(112, 112)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if GameState.is_paused() or GameState.player_dead:
		reset()
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and touch_id == -1 and local.distance_to(center) <= radius:
			touch_id = event.index
			update_direction(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_id:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		update_direction(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func update_direction(local: Vector2) -> void:
	direction = ((local - center) / radius).limit_length()
	if direction.length() < 0.12:
		direction = Vector2.ZERO
	queue_redraw()

func reset() -> void:
	touch_id = -1
	direction = Vector2.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()

func _draw() -> void:
	var engaged := touch_id >= 0
	var accent := Color("c8fa7c") if engaged else Color("8297aa")
	draw_circle(center + Vector2(0, 6), radius + 2, Color(0.02, 0.04, 0.08, 0.25))
	draw_circle(center, radius, Color(0.06, 0.11, 0.18, 0.9))
	draw_arc(center, radius, 0, TAU, 64, Color("344b61"), 2.0, true)
	draw_circle(center, radius - 13, Color(0.09, 0.15, 0.22, 0.85))
	draw_arc(center, radius - 13, 0, TAU, 64, Color("22354b"), 1.0, true)
	for index in 4:
		var axis := Vector2.from_angle(index * PI * 0.5)
		draw_line(center + axis * (radius - 22), center + axis * (radius - 15), accent, 2.0, true)
	if direction != Vector2.ZERO:
		var angle := direction.angle()
		draw_arc(center, radius, angle - 0.34, angle + 0.34, 16, accent, 3.0, true)
	var thumb := center + direction * radius * 0.65
	draw_circle(thumb + Vector2(0, 5), 35, Color(0.01, 0.03, 0.06, 0.45))
	draw_circle(thumb, 34, Color("a7cf70") if engaged else Color("587185"))
	draw_circle(thumb + Vector2(0, -2), 32, Color("c8fa7c") if engaged else Color("a8bdc8"))
	draw_arc(thumb + Vector2(0, -2), 29, PI * 1.15, PI * 1.85, 24, Color(0.94, 0.96, 0.93, 0.55), 2.0, true)
	for offset in [-7, 0, 7]:
		draw_circle(thumb + Vector2(offset, 0), 1.5, Color("526343") if engaged else Color("5a7488"))
