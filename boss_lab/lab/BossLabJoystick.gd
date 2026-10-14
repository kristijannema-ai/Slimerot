class_name BLJoystick
extends Control

signal direction_changed(direction: Vector2)

const RADIUS := 87.0
const THUMB_RADIUS := 34.0
var _finger := -1
var _mouse_down := false
var _direction := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_visibility_reset)
	queue_redraw()

func reset() -> void:
	_finger = -1
	_mouse_down = false
	_direction = Vector2.ZERO
	direction_changed.emit(_direction)
	queue_redraw()

func _visibility_reset() -> void:
	if not is_visible_in_tree():
		reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and _finger == -1:
		_finger = event.index
		_update_thumb(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _finger == -1:
			_mouse_down = true
			_update_thumb(event.position)
		elif not event.pressed and _mouse_down:
			reset()
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenDrag and event.index == _finger:
		_update_thumb(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == _finger and not event.pressed:
		reset()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_down:
		_update_thumb(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _mouse_down:
		reset()
		get_viewport().set_input_as_handled()

func _update_thumb(point: Vector2) -> void:
	_direction = ((point - size * 0.5) / RADIUS).limit_length(1.0)
	if _direction.length() < 0.12:
		_direction = Vector2.ZERO
	direction_changed.emit(_direction)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS, Color("142631"))
	draw_arc(center, RADIUS, 0.0, TAU, 64, Color("7ca2b2"), 3.0, true)
	draw_arc(center, RADIUS * 0.54, 0.0, TAU, 48, Color("25424f"), 2.0, true)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + axis * 64.0, center + axis * 74.0, Color("7ca2b2"), 3.0, true)
	var thumb := center + _direction * (RADIUS - 12.0)
	draw_circle(thumb + Vector2(0, 4), THUMB_RADIUS, Color("08141e"))
	draw_circle(thumb, THUMB_RADIUS, Color("a3f7c0") if _direction != Vector2.ZERO else Color("70bac2"))
	draw_arc(thumb, THUMB_RADIUS, 0.0, TAU, 40, Color("e3ffee"), 2.0, true)
