@tool
extends Node2D
## Static, cached environment drawing. Props stay separate in the .tscn.
## No lights, particles, per-frame redraws, or background image are required.
@export_enum("Floor", "Walls", "Path", "Greenery", "Lighting") var layer := "Floor":
	set(value):
		layer = value
		queue_redraw()

func _draw() -> void:
	match layer:
		"Floor": _floor()
		"Walls": _walls()
		"Path": _path()
		"Greenery": _greenery()
		"Lighting": _lighting()

func _floor() -> void:
	draw_rect(Rect2(0, 0, 1800, 2180), Color("263c36"))
	draw_rect(Rect2(34, 124, 1732, 1210), Color("a87242"))
	# Staggered individual planks keep the scale consistent while exploring.
	for row in 24:
		var y := 128.0 + row * 50.0
		for column in 9:
			var start := 42.0 + column * 230.0 - (115.0 if row % 2 else 0.0)
			var x := maxf(42.0, start)
			var right := minf(1758.0, start + 228.0)
			if right <= x: continue
			var shade := float((row * 7 + column * 11) % 9) / 8.0
			var color := Color("d29253").lerp(Color("efb775"), shade * 0.50)
			var rect := Rect2(x, y, right - x, 48)
			draw_rect(rect, color)
			draw_line(Vector2(x + 1, y + 2), Vector2(right - 1, y + 2), Color(1.0, 0.83, 0.52, 0.28), 2)
			draw_line(Vector2(x + 1, y + 47), Vector2(right - 1, y + 47), Color(0.34, 0.16, 0.08, 0.20), 2)
			for grain in 3:
				var gy := y + 10 + grain * 12
				var gx := x + 9 + ((row * 23 + column * 37 + grain * 19) % 51)
				if gx + 12 < right:
					draw_line(Vector2(gx, gy), Vector2(minf(right - 8, gx + 45 + grain * 15), gy + 1), Color(0.51, 0.27, 0.13, 0.13), 1)
			if right - x > 100:
				draw_circle(Vector2(x + 7, y + 7), 1.4, Color(0.32, 0.19, 0.12, 0.30))
	# Dark room edge and warm perimeter trim provide depth without screen FX.
	for inset in 6:
		draw_rect(Rect2(44 + inset * 5, 164 + inset * 5, 1712 - inset * 10, 1154 - inset * 10), Color(0.25, 0.12, 0.06, 0.025), false, 6)

func _walls() -> void:
	# Warm plaster above a timber dado; the furniture hides the lower seam.
	draw_rect(Rect2(24, 22, 1752, 193), Color("53342d"))
	draw_rect(Rect2(47, 48, 1706, 139), Color("d7ad7b"))
	for panel in 11:
		var x := 53 + panel * 155
		draw_rect(Rect2(x, 55, 147, 125), Color("e3bc89"))
		draw_line(Vector2(x + 6, 62), Vector2(x + 137, 62), Color("efcea1"), 3)
	_beam(Rect2(30, 18, 1740, 33))
	_beam(Rect2(30, 182, 1740, 32))
	_beam(Rect2(24, 28, 35, 1300))
	_beam(Rect2(1741, 28, 35, 1300))
	for x in [58.0, 560.0, 1150.0, 1710.0]:
		_beam(Rect2(x, 28, 30, 179))
	# Fabric banners and small gallery pieces echo the purple/slime theme.
	_banner(Vector2(1182, 73))
	_frame(Vector2(1582, 89), Color("b4d983"))
	# Low stone/wood boundary splits around a broad, physical open path.
	for side in [Rect2(35, 1304, 710, 50), Rect2(1055, 1304, 710, 50)]:
		for stone in int(side.size.x / 72.0) + 1:
			var sx: float = side.position.x + stone * 72
			if sx + 68 <= side.end.x:
				_stone(Rect2(sx, 1336, 68, 56), stone)
		_beam(Rect2(side.position.x, 1304, side.size.x, 29))
		for post in [side.position.x + 14, side.end.x - 41]:
			_beam(Rect2(post, 1281, 33, 83))
	# Lamp pedestals frame the opening but do not occupy the walking corridor.
	for x in [704.0, 1066.0]:
		_stone(Rect2(x, 1300, 48, 86), 2)
		_lantern(Vector2(x + 24, 1282), 1.0)

func _path() -> void:
	# The room floor becomes a garden path; there is no doorway or portal.
	draw_rect(Rect2(748, 1300, 304, 880), Color("987b53"))
	for row in 19:
		var y := 1296.0 + row * 49.0
		for column in 3:
			var x := 753.0 + column * 99.0
			var rect := Rect2(x + (3 if row % 2 == 0 else 0), y + 2, 94, 44)
			var color := Color("d5b987").lerp(Color("ecd2a0"), float((row + column * 2) % 3) / 3)
			draw_style_box(_rounded(color, Color("ab8d61"), 6, 2), rect)
			draw_line(rect.position + Vector2(8, 3), rect.position + Vector2(rect.size.x - 8, 3), Color(1, 0.91, 0.72, 0.55), 2)
	# A few moss-filled seams at the sides signal the outdoor threshold.
	for index in 36:
		var side := 751.0 if index % 2 else 1044.0
		var y := 1340.0 + index * 23.0
		draw_circle(Vector2(side, y), 5, Color("70884a"))
		draw_circle(Vector2(side + (-4 if index % 2 else 4), y + 5), 4, Color("95ae5b"))

func _greenery() -> void:
	# Subtle grass under the separate flower/leaf sprites, continuing off-screen.
	for side in [Rect2(0, 1334, 742, 846), Rect2(1058, 1334, 742, 846)]:
		draw_rect(side, Color("4e773f"))
		for index in 450:
			var x: float = side.position.x + float((index * 137 + 31) % 735)
			var y: float = side.position.y + float((index * 67 + 11) % 846)
			var shade := Color("80a650", 0.4) if index % 3 else Color("365f35", 0.35)
			var p := Vector2(x, y)
			draw_line(p, p + Vector2(-2, -5), shade, 1.5, true)
			draw_line(p + Vector2(2, 1), p + Vector2(4, -6), shade, 1.5, true)
	# Green tufts hug the paving edges without adding a single collider.
	for index in 29:
		var p := Vector2(746 if index % 2 else 1054, 1330 + index * 28)
		for leaf in 5:
			var angle := float(leaf) * TAU / 5
			_leaf(p, Vector2(cos(angle), sin(angle)) * 15, Color("80a953") if leaf % 2 else Color("4c8545"))
		if index % 3 == 0: _flower(p + Vector2(-10 if index % 2 else 10, -10), Color("f4e3ae"))

func _lighting() -> void:
	# Drawn pools are static and inexpensive on the compatibility renderer.
	for position in [Vector2(167, 384), Vector2(647, 362), Vector2(1454, 1032), Vector2(728, 1304), Vector2(1090, 1304)]:
		for radius in range(4, 0, -1):
			draw_circle(position, radius * 29, Color(1.0, 0.68, 0.26, 0.018))
	for radius in range(4, 0, -1):
		draw_circle(Vector2(1470, 492), radius * 42, Color(0.46, 0.31, 1.0, 0.020))

func _beam(rect: Rect2) -> void:
	draw_style_box(_rounded(Color("8e542d"), Color("4e3024"), 5, 3), rect)
	if rect.size.x > rect.size.y:
		draw_line(rect.position + Vector2(6, 5), Vector2(rect.end.x - 6, rect.position.y + 5), Color("c58a4a"), 4)
		draw_line(rect.position + Vector2(10, 17), Vector2(rect.end.x - 10, rect.position.y + 17), Color("a86934"), 2)
	else:
		draw_line(rect.position + Vector2(6, 7), Vector2(rect.position.x + 6, rect.end.y - 6), Color("c58a4a"), 4)

func _banner(at: Vector2) -> void:
	_beam(Rect2(at.x - 4, at.y - 8, 76, 13))
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(66, 0), at + Vector2(66, 105), at + Vector2(33, 123), at + Vector2(0, 105)]), Color("6b4c9f"))
	draw_line(at + Vector2(4, 3), at + Vector2(4, 101), Color("d5ab59"), 3)
	draw_line(at + Vector2(62, 3), at + Vector2(62, 101), Color("d5ab59"), 3)
	draw_circle(at + Vector2(33, 61), 21, Color("b396d3"))
	draw_circle(at + Vector2(26, 58), 3, Color("6c509c"))
	draw_circle(at + Vector2(40, 58), 3, Color("6c509c"))

func _frame(at: Vector2, art: Color) -> void:
	_beam(Rect2(at, Vector2(98, 90)))
	draw_rect(Rect2(at + Vector2(10, 10), Vector2(78, 67)), Color("e5c794"))
	draw_circle(at + Vector2(49, 45), 22, art)
	draw_circle(at + Vector2(42, 43), 3, Color("566c4d"))
	draw_circle(at + Vector2(56, 43), 3, Color("566c4d"))

func _stone(rect: Rect2, variation: int) -> void:
	var color := Color("7b8198").lerp(Color("a3a7b3"), float(variation % 3) / 3)
	draw_style_box(_rounded(color, Color("54596f"), 8, 3), rect)
	draw_line(rect.position + Vector2(8, 5), Vector2(rect.end.x - 8, rect.position.y + 5), Color("b8b9c2"), 3)

func _lantern(at: Vector2, scale_factor: float) -> void:
	draw_circle(at + Vector2(0, 5), 32 * scale_factor, Color(1, 0.74, 0.20, 0.10))
	draw_style_box(_rounded(Color("f7be4c"), Color("704726"), 6, 4), Rect2(at + Vector2(-15, -27) * scale_factor, Vector2(30, 43) * scale_factor))
	draw_style_box(_rounded(Color("fff0ac"), Color("efb742"), 4, 2), Rect2(at + Vector2(-8, -19) * scale_factor, Vector2(16, 26) * scale_factor))
	draw_rect(Rect2(at + Vector2(-19, -31) * scale_factor, Vector2(38, 8) * scale_factor), Color("6a4932"))
	draw_circle(at + Vector2(0, -36) * scale_factor, 5 * scale_factor, Color("5c432e"))
	draw_rect(Rect2(at + Vector2(-18, 14) * scale_factor, Vector2(36, 7) * scale_factor), Color("ad7334"))

func _leaf(at: Vector2, direction: Vector2, color: Color) -> void:
	var side := direction.orthogonal().normalized() * 10
	draw_colored_polygon(PackedVector2Array([at, at + direction * 0.5 + side, at + direction, at + direction * 0.5 - side]), color)
	draw_line(at, at + direction * 0.82, Color("a0ba64"), 1.5, true)

func _flower(at: Vector2, color: Color) -> void:
	for petal in 5:
		var angle := float(petal) * TAU / 5
		draw_circle(at + Vector2(cos(angle), sin(angle)) * 4, 3.3, color)
	draw_circle(at, 2.7, Color("e8bd50"))

func _rounded(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
