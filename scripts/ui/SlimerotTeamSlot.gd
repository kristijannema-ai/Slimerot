class_name SlimerotTeamSlot
extends SlimerotPortrait

var locked := false
var empty_slot := true

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(64, 86)

func _draw() -> void:
	if not empty_slot or locked:
		super._draw()
	else:
		var center := size * 0.5
		draw_circle(center, minf(size.x, size.y) * 0.31, Color("d5eade"))
		draw_line(center - Vector2(8, 0), center + Vector2(8, 0), Color("587c76"), 3, true)
		draw_line(center - Vector2(0, 8), center + Vector2(0, 8), Color("587c76"), 3, true)
	if not locked:
		return
	# Draw real interlocking links so locked slots do not depend on an emoji font.
	for direction in [-1.0, 1.0]:
		for index in 7:
			var at := size * 0.5 + Vector2(index - 3, (index - 3) * direction) * 8.0
			draw_arc(at, 6.0, 0, TAU, 12, Color("244d59"), 5.0, true)
			draw_arc(at, 6.0, 0, TAU, 12, Color("adc6cb"), 2.2, true)
	var lock_center := size * 0.5
	draw_arc(lock_center - Vector2(0, 5), 8, PI, TAU, 12, Color("244d59"), 4, true)
	draw_style_box(_lock_style(), Rect2(lock_center - Vector2(12, 4), Vector2(24, 21)))
	draw_circle(lock_center + Vector2(0, 4), 2.5, Color("244d59"))
	draw_line(lock_center + Vector2(0, 4), lock_center + Vector2(0, 10), Color("244d59"), 3, true)

func _lock_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ffdf88")
	box.border_color = Color("244d59")
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	return box
