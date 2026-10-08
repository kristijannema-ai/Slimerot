@tool
extends Node2D
## Carved wooden plaques with a little thickness and a quiet floating motion.
## The icon and both captions are laid out together, centered on the plaque.
@export var plaque_width := 280.0:
	set(value):
		plaque_width = value
		_refresh_visuals()
@export_enum("bed", "book", "shrine", "coins", "tree") var icon_kind := "book":
	set(value):
		icon_kind = value
		_refresh_visuals()
@export var single_line := false:
	set(value):
		single_line = value
		_refresh_visuals()

const BOB_HEIGHT := 3.0
const BOB_PERIOD := 3.5
const ICON_WIDTH := 40.0
const ICON_TEXT_GAP := 13.0

var _base_position := Vector2.ZERO
var _animation_time := 0.0
var _phase := 0.0
var _icon_center_x := 35.0
var _cast_shadow: Node2D
var _game_state: Node

func _ready() -> void:
	_base_position = position
	_phase = float(["bed", "book", "shrine", "coins", "tree"].find(icon_kind)) * 0.71
	_game_state = get_node_or_null("/root/GameState")
	_layout_labels()
	_build_shadow()
	set_process(not Engine.is_editor_hint())
	for label_name in ["Title", "Subtitle"]:
		var label := get_node_or_null(label_name) as Label
		if label != null and not label.theme_changed.is_connected(_refresh_visuals):
			label.theme_changed.connect(_refresh_visuals)

func get_base_position() -> Vector2:
	return _base_position if is_node_ready() else position

func visual_bounds() -> Rect2:
	# Includes the outer bevel and the widest shadow edge over a full bob cycle.
	var height := 60.0 if single_line else 78.0
	var right_padding := ceilf(7.0 + plaque_width * 0.017) + 2.0
	var bottom_padding := ceilf(14.0 + height * 0.017 + BOB_HEIGHT) + 2.0
	return Rect2(-2.0, -2.0, plaque_width + right_padding + 2.0, height + bottom_padding + 2.0)

func _process(delta: float) -> void:
	# Follow the game's own menu/pause state as well as normal scene-tree pause.
	if _game_state != null and _game_state.call("is_paused"):
		return
	_animation_time = fmod(_animation_time + delta, BOB_PERIOD)
	var bob := sin(_animation_time * TAU / BOB_PERIOD + _phase) * BOB_HEIGHT
	position = _base_position + Vector2(0.0, bob)
	if is_instance_valid(_cast_shadow):
		# Keep the cast shadow on the floor while the solid plaque moves above it.
		# Transform/modulate changes reuse cached draw commands; no per-frame redraw.
		_cast_shadow.position.y = -bob
		_cast_shadow.modulate.a = 0.93 + bob * 0.02

func _refresh_visuals() -> void:
	queue_redraw()
	if is_inside_tree():
		_layout_labels.call_deferred()
		_build_shadow.call_deferred()

func _layout_labels() -> void:
	var title := get_node_or_null("Title") as Label
	var subtitle := get_node_or_null("Subtitle") as Label
	var text_width := 0.0
	for label in [title, subtitle]:
		if label == null or (single_line and label == subtitle):
			continue
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		text_width = maxf(text_width, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	text_width = ceilf(text_width) + 4.0
	var group_width := ICON_WIDTH + ICON_TEXT_GAP + text_width
	var group_left := (plaque_width - group_width) * 0.5
	_icon_center_x = group_left + ICON_WIDTH * 0.5
	for label in [title, subtitle]:
		if label == null:
			continue
		label.offset_left = group_left + ICON_WIDTH + ICON_TEXT_GAP
		label.offset_right = label.offset_left + text_width
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_redraw()

func _outline(inset: float = 0.0) -> PackedVector2Array:
	var height := 60.0 if single_line else 78.0
	return PackedVector2Array([
		Vector2(9 + inset, inset), Vector2(plaque_width - 9 - inset, inset),
		Vector2(plaque_width - inset, 9 + inset), Vector2(plaque_width - inset, height - 9 - inset),
		Vector2(plaque_width - 9 - inset, height - inset), Vector2(9 + inset, height - inset),
		Vector2(inset, height - 9 - inset), Vector2(inset, 9 + inset)])

func _build_shadow() -> void:
	if not is_instance_valid(_cast_shadow):
		_cast_shadow = Node2D.new()
		_cast_shadow.name = "GroundedCastShadow"
		_cast_shadow.show_behind_parent = true
		add_child(_cast_shadow, false, Node.INTERNAL_MODE_BACK)
	for child in _cast_shadow.get_children():
		child.free()
	var outline := _outline()
	var center := Vector2(plaque_width * 0.5, (60.0 if single_line else 78.0) * 0.5)
	for layer_index in 3:
		var soft_edge := Polygon2D.new()
		var shadow_points := PackedVector2Array()
		var spread := 1.0 + float(2 - layer_index) * 0.017
		for point in outline:
			shadow_points.append(center + (point - center) * spread + Vector2(7, 14))
		soft_edge.polygon = shadow_points
		soft_edge.color = Color(0.12, 0.065, 0.04, 0.045 + float(layer_index) * 0.035)
		_cast_shadow.add_child(soft_edge)

func _draw() -> void:
	var height := 60.0 if single_line else 78.0
	var outline := _outline()
	var extrusion := PackedVector2Array()
	for point in outline:
		extrusion.append(point + Vector2(4, 7))
	# The lower and right edge are real visible side faces, below the lit front.
	draw_colored_polygon(extrusion, Color("372016"))
	draw_colored_polygon(PackedVector2Array([outline[3], outline[4], outline[5], outline[6], extrusion[6], extrusion[5], extrusion[4], extrusion[3]]), Color("60351c"))
	draw_line(extrusion[5], extrusion[4], Color("8b5128"), 1.5, true)
	draw_colored_polygon(outline, Color("4b2816"))
	var inset := _outline(4.0)
	var grain_colors := PackedColorArray([
		Color("a36934"), Color("a36934"), Color("935829"), Color("683917"),
		Color("603417"), Color("603417"), Color("683917"), Color("935829")])
	draw_polygon(inset, grain_colors)
	var border := outline.duplicate()
	border.append(outline[0])
	draw_polyline(border, Color("dca452"), 2.3, true)
	# A warm upper bevel catches lamp light; lower bevel stays shaded.
	draw_polyline(PackedVector2Array([outline[7] + Vector2(2, 0), outline[0] + Vector2(0, 2), outline[1] + Vector2(0, 2), outline[2] + Vector2(-2, 0)]), Color("f7d590"), 2.1, true)
	draw_polyline(PackedVector2Array([inset[3], inset[4], inset[5], inset[6]]), Color("44220f"), 2.8, true)
	draw_line(Vector2(14, 7), Vector2(plaque_width - 15, 7), Color(1.0, 0.86, 0.55, 0.25), 1.2, true)
	for index in 4:
		var y := 17.0 + float(index) * 14.0
		var grain := PackedVector2Array([
			Vector2(18, y), Vector2(plaque_width * 0.26, y - 1.4),
			Vector2(plaque_width * 0.51, y + 0.9), Vector2(plaque_width - 19, y - 0.4)])
		draw_polyline(grain, Color(0.99, 0.78, 0.48, 0.065), 1.4, true)
	for x in [11.0, plaque_width - 11.0]:
		var pin := Vector2(x, height * 0.5)
		draw_circle(pin + Vector2(1, 2), 3.0, Color("3d2517"))
		draw_circle(pin, 2.8, Color("bd8542"))
		draw_arc(pin, 2.0, PI, TAU, 8, Color("f8dca0"), 1.2, true)
		draw_circle(pin + Vector2(-0.8, -0.8), 0.7, Color("fff0c0"))
	draw_set_transform(Vector2(_icon_center_x, height * 0.5))
	match icon_kind:
		"book": _book()
		"bed": _bed()
		"coins": _coins()
		"tree": _tree()
		"shrine": _shrine()
	draw_set_transform(Vector2.ZERO)

func _book() -> void:
	var cream := Color("fff1cf")
	# Separate fanned pages with a strong central spine and facing page folds.
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -13), Vector2(-5, -17), Vector2(0, -13), Vector2(5, -17), Vector2(19, -13), Vector2(19, 14), Vector2(5, 11), Vector2(0, 15), Vector2(-5, 11), Vector2(-19, 14)]), Color("c38f48"))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -15), Vector2(-5, -17), Vector2(-2, -13), Vector2(-2, 11), Vector2(-6, 8), Vector2(-16, 10)]), cream)
	draw_colored_polygon(PackedVector2Array([Vector2(16, -15), Vector2(5, -17), Vector2(2, -13), Vector2(2, 11), Vector2(6, 8), Vector2(16, 10)]), cream)
	draw_line(Vector2(0, -12), Vector2(0, 15), Color("fff6dd"), 2, true)
	for y in [-8.0, -3.0, 2.0]:
		draw_line(Vector2(-13, y), Vector2(-6, y - 1), Color("d3b88d"), 1)
		draw_line(Vector2(6, y - 1), Vector2(13, y), Color("d3b88d"), 1)

func _bed() -> void:
	var cream := Color("fff0cb")
	draw_rect(Rect2(-19, -3, 38, 14), cream, false, 2.5)
	draw_line(Vector2(-19, -16), Vector2(-19, 17), cream, 3)
	draw_line(Vector2(19, -9), Vector2(19, 17), cream, 3)
	draw_line(Vector2(-19, -13), Vector2(8, -13), cream, 2.5)
	draw_rect(Rect2(-15, -10, 10, 6), cream)
	draw_line(Vector2(-16, 3), Vector2(16, 3), Color("d4a452"), 2)

func _coins() -> void:
	for y in [10.0, 3.0, -4.0]:
		draw_style_box(_pill(Color("bc7c25"), Color("59351e")), Rect2(-15, y - 1, 30, 9))
		draw_style_box(_pill(Color("f6d775"), Color("ffebad")), Rect2(-15, y - 5, 30, 9))
		draw_line(Vector2(-8, y + 4), Vector2(8, y + 4), Color("e4ac43"), 2)
	draw_arc(Vector2(0, -4), 9, 0.0, PI, 12, Color("e4b546"), 1.3, true)

func _tree() -> void:
	draw_rect(Rect2(-3, 1, 6, 17), Color("e3b869"))
	draw_circle(Vector2(-10, -1), 9, Color("b6e8b0"))
	draw_circle(Vector2(10, -1), 9, Color("cbeec0"))
	draw_circle(Vector2(0, -11), 10, Color("d4f4c7"))
	draw_rect(Rect2(-10, -5, 20, 14), Color("bfe9b3"))
	draw_line(Vector2(0, 10), Vector2(6, 5), Color("e3b869"), 2)

func _shrine() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(13, -2), Vector2(0, 13), Vector2(-13, -2)]), Color("e7d7ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(13, -2), Vector2(0, 2)]), Color("fff2d0"))
	draw_line(Vector2(0, -16), Vector2(0, 11), Color("b796e0"), 1.5)
	draw_rect(Rect2(-17, 15, 34, 5), Color("f5dfae"))
	for p in [Vector2(-18, -13), Vector2(19, 6)]:
		draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color("ffecb5"), 1.8)
		draw_line(p - Vector2(0, 3), p + Vector2(0, 3), Color("ffecb5"), 1.8)

func _pill(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	return style
