class_name SlimerotPortrait
extends Control

var slime_id := SlimerotBalance.FIRST_SLIME
var variant := "normal"
var silhouette := false
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(58, 58)

func _process(delta: float) -> void:
	if not GameState.is_paused(): clock += delta
	queue_redraw()

func _draw() -> void:
	paint(self, size * 0.5, minf(size.x, size.y) * 0.32, slime_id, variant, silhouette, clock)

static func paint(surface: CanvasItem, center: Vector2, radius: float, id: String, kind: String, hidden: bool, time: float) -> void:
	var tone := Color.from_hsv(float(absi(id.hash()) % 360) / 360.0, 0.34, 0.91)
	if kind == "golden": tone = Color("ffcf63")
	if hidden: tone = Color("42535b")
	var at := center + Vector2(0, sin(time * 3.0) * radius * 0.08)
	if kind == "glitched" and not hidden:
		at.x += sin(time * 28) * radius * 0.1
		surface.draw_circle(at + Vector2(4, 0), radius, Color(1, 0.2, 0.5, 0.4))
		surface.draw_circle(at - Vector2(4, 0), radius, Color(0.2, 1, 1, 0.4))
	if kind == "golden" and not hidden:
		surface.draw_circle(at, radius * 1.45, Color(1, 0.8, 0.2, 0.18))
	surface.draw_circle(at + Vector2(0, radius * 0.3), radius, tone.darkened(0.1))
	surface.draw_circle(at, radius, tone)
	if hidden:
		surface.draw_string(ThemeDB.fallback_font, at + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius), Color("859499"))
		return
	if kind == "shiny":
		surface.draw_arc(at, radius * 1.12, 0, TAU, 32, Color("f0ffff"), 2, true)
		for index in 4:
			var point := at + Vector2.from_angle(time + index * TAU / 4.0) * radius * 1.45
			surface.draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color.WHITE, 1.5)
			surface.draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color.WHITE, 1.5)
	surface.draw_circle(at + Vector2(-0.32, -0.05) * radius, radius * 0.13, Color("152c35"))
	surface.draw_circle(at + Vector2(0.32, -0.05) * radius, radius * 0.13, Color("152c35"))
	surface.draw_line(at + Vector2(-0.15, 0.35) * radius, at + Vector2(0.15, 0.35) * radius, Color("152c35"), 2)
	# Small deterministic markings distinguish Slimerot's original placeholder portraits.
	for index in 1 + absi(id.hash()) % 3:
		surface.draw_circle(at + Vector2(-0.4 + index * 0.35, -0.6) * radius, radius * 0.08, tone.lightened(0.4))
