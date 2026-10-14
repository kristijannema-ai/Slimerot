class_name BLEffects
extends Node2D

var slots: Array[Dictionary] = []
var peak := 0

func setup(capacity: int) -> void:
	for index in capacity: slots.append({})
	z_index = 8

func burst(point: Vector2, color: Color, count: int = 12) -> void:
	var added := 0
	for index in slots.size():
		if slots[index].is_empty():
			var direction := Vector2.from_angle(float(added) * TAU / maxf(count, 1.0) + 0.3)
			slots[index] = {"point":point, "velocity":direction * (55.0 + added % 3 * 30.0), "color":color, "life":0.38, "age":0.0}
			added += 1
			if added >= count: break
	peak = maxi(peak, count_active())

func count_active() -> int:
	var count := 0
	for item in slots:
		if not item.is_empty(): count += 1
	return count

func clear() -> void:
	for index in slots.size(): slots[index] = {}

func step(delta: float) -> void:
	for index in slots.size():
		if slots[index].is_empty(): continue
		slots[index].age += delta
		slots[index].point += Vector2(slots[index].velocity) * delta
		if slots[index].age >= slots[index].life: slots[index] = {}
	queue_redraw()

func _draw() -> void:
	for item in slots:
		if item.is_empty(): continue
		var alpha := 1.0 - float(item.age) / float(item.life)
		draw_circle(item.point, 2.0 + alpha * 2.0, Color(item.color, alpha))

