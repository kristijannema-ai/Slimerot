@tool
extends Node2D
## Small diegetic wooden plaques. The book is deliberately an open volume.
@export var plaque_width := 280.0:
	set(value):
		plaque_width = value
		queue_redraw()
@export_enum("bed", "book", "shrine", "coins", "tree") var icon_kind := "book":
	set(value):
		icon_kind = value
		queue_redraw()
@export var single_line := false:
	set(value):
		single_line = value
		queue_redraw()

func _draw() -> void:
	var height := 60.0 if single_line else 78.0
	var outline := PackedVector2Array([Vector2(9, 0), Vector2(plaque_width - 9, 0), Vector2(plaque_width, 9), Vector2(plaque_width, height - 9), Vector2(plaque_width - 9, height), Vector2(9, height), Vector2(0, height - 9), Vector2(0, 9)])
	var shadow := PackedVector2Array()
	for point in outline: shadow.append(point + Vector2(0, 5))
	draw_colored_polygon(shadow, Color(0.22, 0.12, 0.12, 0.40))
	draw_colored_polygon(outline, Color("533018"))
	var inset := PackedVector2Array([Vector2(11, 4), Vector2(plaque_width - 11, 4), Vector2(plaque_width - 4, 11), Vector2(plaque_width - 4, height - 11), Vector2(plaque_width - 11, height - 4), Vector2(11, height - 4), Vector2(4, height - 11), Vector2(4, 11)])
	draw_colored_polygon(inset, Color("79451f"))
	var border := outline.duplicate()
	border.append(outline[0])
	draw_polyline(border, Color("e3b660"), 2.5, true)
	draw_line(Vector2(12, 5), Vector2(plaque_width - 12, 5), Color("f4d886"), 1.5, true)
	for index in 4:
		draw_line(Vector2(14, 16 + index * 15), Vector2(plaque_width - 14, 16 + index * 15), Color(0.94, 0.69, 0.34, 0.06), 2)
	draw_circle(Vector2(9, height * 0.5), 2, Color("edc873"))
	draw_circle(Vector2(plaque_width - 9, height * 0.5), 2, Color("edc873"))
	draw_set_transform(Vector2(35, height * 0.5))
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
