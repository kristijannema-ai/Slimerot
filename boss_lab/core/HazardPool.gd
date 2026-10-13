class_name BLHazardPool
extends Node2D

const DANGER := Color("ff7e62")
const MOVING := Color("ffe37a")
const SPECIAL := Color("c89fff")
const SAFE := Color("73d8ff")
var context: BLContext
var slots: Array[Dictionary] = []
var peak := 0
var show_hitboxes := false
var show_telegraphs := true

func setup(ctx: BLContext, capacity: int) -> void:
	context = ctx
	for index in capacity: slots.append({})
	z_index = 1

func add(spec: Dictionary) -> int:
	if int(spec.get("damage", 0)) > 0 and float(spec.get("warning", 0.0)) < 0.25:
		push_error("Damage hazards require a readable warning: " + str(spec.get("attack", "")))
		return -1
	for index in slots.size():
		if slots[index].is_empty():
			var item := spec.duplicate(true)
			item.age = 0.0
			item.origin = item.get("origin", context.boss.global_position)
			item.initial_origin = item.origin
			item.warning = float(item.get("warning", 0.6))
			item.active = float(item.get("active", 0.5))
			item.damage = int(item.get("damage", 0))
			item.kind = item.get("kind", "circle")
			item.owner = item.get("owner", item.get("attack", ""))
			item.pushed = false
			slots[index] = item
			peak = maxi(peak, count_active())
			return index
	return -1

func update_slot(index: int, changes: Dictionary) -> void:
	if index >= 0 and index < slots.size() and not slots[index].is_empty():
		for key in changes: slots[index][key] = changes[key]

func clear(owner: String = "") -> void:
	for index in slots.size():
		if owner.is_empty() or slots[index].get("owner", "") == owner: slots[index] = {}
	queue_redraw()

func count_active() -> int:
	var count := 0
	for item in slots:
		if not item.is_empty(): count += 1
	return count

func active_time(item: Dictionary) -> float:
	return maxf(0.0, float(item.age) - float(item.warning))

func center(item: Dictionary) -> Vector2:
	var base: Vector2 = context.boss.global_position if item.get("follow_boss", false) else item.origin
	return base + Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item)

func radius(item: Dictionary) -> float:
	return maxf(0.0, float(item.get("radius", item.get("safe_radius", 100.0))) + float(item.get("growth", 0.0)) * active_time(item))

func wall_gaps(item: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for source in item.get("gaps", []):
		var gap: Vector2 = source
		var speed := float(item.get("gap_speed", 0.0))
		var bounds: Vector2 = item.get("gap_bounds", Vector2(context.arena.position.x + 24, context.arena.end.x - 24))
		var span := maxf(1.0, bounds.y - bounds.x - (gap.y - gap.x))
		var moving_left := bounds.x + pingpong(gap.x - bounds.x + speed * active_time(item), span) if speed != 0.0 else gap.x
		result.append(Vector2(moving_left, moving_left + gap.y - gap.x))
	return result

func contains(item: Dictionary, point: Vector2, body_radius: float = 0.0) -> bool:
	var origin := center(item)
	var distance := origin.distance_to(point)
	var width := float(item.get("width", 48.0))
	var kind: String = item.kind
	if kind == "circle" or kind == "field": return distance <= radius(item) + body_radius
	if kind == "rect":
		var area: Rect2 = item.get("rect", Rect2(origin - Vector2(50, 50), Vector2(100, 100)))
		area.position += Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item)
		var closest := point.clamp(area.position, area.end)
		return closest.distance_to(point) <= body_radius
	if kind == "lane":
		var end: Vector2 = item.get("end", origin + Vector2(0, 100))
		end += Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item)
		return Geometry2D.get_closest_point_to_segment(point, origin, end).distance_to(point) <= width * 0.5 + body_radius
	if kind == "wall":
		if absf(point.y - origin.y) > width * 0.5 + body_radius: return false
		for gap in wall_gaps(item):
			if point.x - body_radius >= gap.x and point.x + body_radius <= gap.y: return false
		return context.arena.grow(body_radius).has_point(point)
	if kind == "ring":
		if absf(distance - radius(item)) > width * 0.5 + body_radius: return false
		var gap := float(item.get("gap_width", 0.0))
		var angle := (point - origin).angle()
		var angular_margin := asin(minf(1.0, body_radius / maxf(distance, 1.0)))
		return absf(wrapf(angle - float(item.get("gap_angle", 0.0)), -PI, PI)) >= maxf(0.0, gap * 0.5 - angular_margin)
	if kind == "annulus":
		var safe := float(item.get("safe_radius", 160.0)) + float(item.get("growth", 0.0)) * active_time(item)
		return context.arena.has_point(point) and absf(distance - safe) > width * 0.5 - body_radius
	if kind == "sector":
		if distance > radius(item) + body_radius: return false
		# A player disk containing the wedge origin intersects every facing.
		if distance <= body_radius: return true
		var direction := float(item.get("angle", 0.0)) + float(item.get("angular_speed", 0.0)) * active_time(item)
		var angular_margin := asin(minf(1.0, body_radius / maxf(distance, 1.0)))
		return absf(wrapf((point - origin).angle() - direction, -PI, PI)) <= float(item.get("arc", PI)) * 0.5 + angular_margin
	return false

func step(delta: float) -> void:
	for index in slots.size():
		var item := slots[index]
		if item.is_empty(): continue
		item.age += delta
		if item.age >= item.warning and item.age <= item.warning + item.active:
			if contains(item, context.player.global_position, context.balanced.player_radius):
				if int(item.damage) > 0: context.player.take_hit(item.damage, str(item.get("attack", "Hazard")))
				if not context.player.is_dashing():
					context.player.speed_modifier = minf(context.player.speed_modifier, maxf(0.38, float(item.get("slow", 1.0))))
					context.player.sliding = context.player.sliding or item.get("slide", false)
					var direction := (center(item) - context.player.global_position).normalized()
					context.player.external_force += direction * clampf(float(item.get("pull", 0.0)), -100.0, 100.0)
					if float(item.get("push", 0.0)) != 0.0:
						item.pushed = true
						context.player.external_force -= direction * minf(100.0, float(item.push))
		if item.age > item.warning + item.active: slots[index] = {}
	queue_redraw()

func _draw() -> void:
	if context == null: return
	for item in slots:
		if item.is_empty(): continue
		var warning: bool = item.age < item.warning
		if warning and not show_telegraphs: continue
		var color: Color = item.get("color", DANGER if int(item.damage) > 0 else SPECIAL)
		var pulse := 0.20 + 0.13 * (sin(float(item.age) * 12.0) * 0.5 + 0.5)
		var fill := Color(color, pulse if warning else 0.40)
		var origin := center(item)
		var size := radius(item)
		var width := float(item.get("width", 48.0))
		var outline := Color.WHITE if show_hitboxes else color
		var kind: String = item.kind
		if kind == "circle" or kind == "field":
			draw_circle(origin, size, fill)
			draw_arc(origin, size, 0, TAU, 64, outline, 2.0, true)
		elif kind == "rect":
			var area: Rect2 = item.get("rect", Rect2(origin - Vector2(50, 50), Vector2(100, 100)))
			area.position += Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item)
			draw_rect(area, fill)
			draw_rect(area, outline, false, 2)
		elif kind == "lane":
			var end: Vector2 = item.get("end", origin + Vector2(0, 100))
			end += Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item)
			draw_line(origin, end, fill, width, true)
			draw_circle(origin, width * 0.5, fill)
			draw_circle(end, width * 0.5, fill)
			var normal := (end - origin).normalized().orthogonal() * width * 0.5
			draw_line(origin + normal, end + normal, outline, 2.0, true)
			draw_line(origin - normal, end - normal, outline, 2.0, true)
		elif kind == "wall":
			var gaps := wall_gaps(item)
			gaps.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
			var from := context.arena.position.x
			for gap in gaps:
				wall_segment(Rect2(from, origin.y - width * 0.5, maxf(0, gap.x - from), width), fill, outline)
				draw_line(Vector2(gap.x, origin.y), Vector2(gap.y, origin.y), SAFE, 4, true)
				from = gap.y
			wall_segment(Rect2(from, origin.y - width * 0.5, maxf(0, context.arena.end.x - from), width), fill, outline)
		elif kind == "ring":
			var gap := float(item.get("gap_width", 0.0))
			var angle := float(item.get("gap_angle", 0.0))
			draw_arc(origin, size, angle + gap * 0.5, angle + TAU - gap * 0.5, 96, fill, width, true)
			draw_arc(origin, maxf(1, size - width * 0.5), angle + gap * 0.5, angle + TAU - gap * 0.5, 96, outline, 1, true)
			draw_arc(origin, size + width * 0.5, angle + gap * 0.5, angle + TAU - gap * 0.5, 96, outline, 1, true)
		elif kind == "annulus":
			var safe := float(item.get("safe_radius", 160.0)) + float(item.get("growth", 0.0)) * active_time(item)
			draw_rect(context.arena, Color(color, 0.11 if warning else 0.2))
			draw_arc(origin, safe, 0, TAU, 128, Color(SAFE, 0.32), width, true)
			draw_circle(origin, maxf(1, safe - width * 0.5), fill)
			draw_arc(origin, maxf(1, safe - width * 0.5), 0, TAU, 96, SAFE, 3, true)
			draw_arc(origin, safe + width * 0.5, 0, TAU, 96, SAFE, 3, true)
		elif kind == "sector":
			var angle := float(item.get("angle", 0.0)) + float(item.get("angular_speed", 0.0)) * active_time(item)
			var arc := float(item.get("arc", PI))
			if warning and float(item.get("angular_speed", 0.0)) != 0.0:
				var sweep := float(item.get("angular_speed", 0.0)) * float(item.active)
				var begin := angle - arc * 0.5 + minf(0.0, sweep)
				var end := angle + arc * 0.5 + maxf(0.0, sweep)
				draw_arc(origin, size, begin, minf(begin + TAU, end), 96, Color(outline, 0.4), 4, true)
				draw_line(origin, origin + Vector2.from_angle(angle) * size, outline, 2, true)
			var points := PackedVector2Array([origin])
			for index in 33: points.append(origin + Vector2.from_angle(angle - arc * 0.5 + arc * index / 32.0) * size)
			draw_colored_polygon(points, fill)
			draw_polyline(points, outline, 2, true)
		var label: String = item.get("label", "")
		if not label.is_empty():
			var label_origin: Vector2 = item.rect.get_center() + Vector2(item.get("velocity", Vector2.ZERO)) * active_time(item) if kind == "rect" and item.has("rect") else origin
			draw_string(ThemeDB.fallback_font, label_origin + Vector2(-56, -8), label, HORIZONTAL_ALIGNMENT_CENTER, 112, 17, color)

func wall_segment(area: Rect2, fill: Color, outline: Color) -> void:
	if area.size.x <= 0.0: return
	draw_rect(area, fill)
	draw_rect(area, outline, false, 1.5)
