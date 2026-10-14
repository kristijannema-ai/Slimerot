class_name BLArena
extends Node2D

var context: BLContext
var profile: BLProfile
var clock := 0.0
var pillars: Array[Rect2] = []
var floor_style := StyleBoxFlat.new()

func setup(ctx: BLContext) -> void:
	context = ctx
	floor_style.set_corner_radius_all(18)
	z_index = -2
	# Permanent border collision; the final Admin inset is an additional visible bound.
	for rect in [Rect2(24, 204, 672, 16), Rect2(24, 980, 672, 16), Rect2(24, 220, 16, 760), Rect2(680, 220, 16, 760)]:
		add_wall(rect)

func add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func step(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if context == null: return
	var bounds := context.arena
	var color := profile.arena_color if profile else Color("20283c")
	var accent := profile.accent if profile else Color("80b3dd")
	floor_style.bg_color = color
	draw_style_box(floor_style, bounds)
	for x in range(40, 681, 64): draw_line(Vector2(x, 220), Vector2(x, 980), Color(accent, 0.075), 1)
	for y in range(220, 981, 64): draw_line(Vector2(40, y), Vector2(680, y), Color(accent, 0.075), 1)
	if profile != null and profile.id == "espresso":
		for at in [Vector2(78, 260), Vector2(642, 260), Vector2(78, 940), Vector2(642, 940)]:
			draw_circle(at, 19, Color("bb7a54"))
			draw_arc(at, 12, 0, TAU, 24, Color("ffd887"), 2)
	elif profile != null and profile.id == "sand":
		for y in range(240, 881, 44):
			draw_arc(Vector2(350 + sin(y) * 80, y), 90, 0.05, 2.7, 24, Color(Color("dcb472"), 0.11), 1, true)
	elif profile != null and profile.id == "janitor":
		for x in [44, 648]:
			for y in [286, 525, 784]:
				draw_rect(Rect2(x, y, 27, 68), Color("493b28"))
				draw_rect(Rect2(x + 5, y + 6, 17, 54), Color("958356"), false, 2)
	else:
		for index in 25:
			var point := Vector2(65 + (index * 89) % 590, 235 + (index * 157) % 710)
			draw_circle(point, 1.5 + sin(clock + index) * 0.5, Color(accent, 0.5))
	draw_rect(bounds, accent, false, 3)

