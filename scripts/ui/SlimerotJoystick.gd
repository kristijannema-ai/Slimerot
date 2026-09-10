class_name SlimerotJoystick
extends Control

var direction := Vector2.ZERO
var touch_id := -1
var radius := 88.0
var center := Vector2(112, 112)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local: Vector2 = event.position - global_position
		if event.pressed and touch_id == -1 and local.distance_to(center) < radius * 1.25:
			touch_id = event.index
			update_direction(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_id:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		update_direction(event.position - global_position)
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
	draw_circle(center, radius, Color(0.05, 0.12, 0.16, 0.82))
	draw_arc(center, radius, 0, TAU, 64, Color("658d95"), 2.0, true)
	draw_circle(center + direction * radius * 0.65, 34, Color("bed2c9"))
	draw_circle(center + direction * radius * 0.65, 23, Color("dce9d6"))
