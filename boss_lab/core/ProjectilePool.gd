class_name BLProjectilePool
extends Node2D

var context: BLContext
var slots: Array[Dictionary] = []
var peak := 0
var show_hitboxes := false

func setup(ctx: BLContext, capacity: int) -> void:
	context = ctx
	z_index = 5
	for index in capacity: slots.append({})

func add(origin: Vector2, direction: Vector2, speed: float, damage: int, attack: String, owner: String, params: Dictionary) -> int:
	for index in slots.size():
		if slots[index].is_empty():
			slots[index] = {"position": origin, "previous": origin, "direction": direction.normalized(),
				"speed": speed, "damage": damage, "attack": attack, "owner": owner, "age": 0.0, "params": params.duplicate(true)}
			peak = maxi(peak, count_active())
			return index
	return -1

func count_active() -> int:
	var count := 0
	for item in slots:
		if not item.is_empty(): count += 1
	return count

func clear(owner: String = "") -> void:
	for index in slots.size():
		if owner.is_empty() or slots[index].get("owner", "") == owner: slots[index] = {}
	queue_redraw()

func step(delta: float) -> void:
	for index in slots.size():
		var item := slots[index]
		if item.is_empty(): continue
		var params: Dictionary = item.params
		var prior_age := float(item.age)
		item.age += delta
		var orbit_time := float(params.get("orbit_time", 0.0))
		if prior_age < orbit_time:
			var anchor: Vector2 = params.get("orbit_center", context.boss.global_position)
			var angle := float(params.get("orbit_angle", 0.0)) + float(params.get("orbit_speed", 1.7)) * minf(item.age, orbit_time)
			item.position = anchor + Vector2.from_angle(angle) * float(params.get("orbit_radius", 96.0))
			item.previous = item.position
			if params.get("release_track", false) and not params.get("locked", false) and item.age >= orbit_time - 0.45:
				params.locked = true
				params.release_aim = context.player.global_position
				var release_position := anchor + Vector2.from_angle(float(params.get("orbit_angle", 0.0)) + float(params.get("orbit_speed", 1.7)) * orbit_time) * float(params.get("orbit_radius", 96.0))
				context.hazard({"kind":"lane", "origin":release_position, "end":params.release_aim,
					"width":16.0, "warning":0.45, "active":0.10, "damage":0, "attack":item.attack, "owner":item.owner,
					"color":Color("ffca75"), "label":"ORBIT / LOCK"})
			if item.age < orbit_time: continue
			var target: Vector2 = params.get("release_aim", context.player.global_position)
			item.direction = (target - Vector2(item.position)).normalized()
		item.previous = item.position
		item.position += Vector2(item.direction) * float(item.speed) * delta
		var closest := Geometry2D.get_closest_point_to_segment(context.player.global_position, item.previous, item.position)
		var radius := float(params.get("radius", 8.0))
		if closest.distance_to(context.player.global_position) <= radius + context.balanced.player_radius:
			context.player.take_hit(int(item.damage), str(item.attack))
			expire(index, true)
		elif not context.arena.grow(30.0).has_point(item.position) or float(item.age) > 7.0 + orbit_time:
			expire(index, false)
	queue_redraw()

func expire(index: int, impact: bool) -> void:
	var item := slots[index]
	if item.is_empty(): return
	if impact: context.fx(item.position, Color("ffca75"), 6)
	if item.params.get("puddle", false):
		context.hazard({"kind":"circle", "origin":context.clamp_point(item.position), "radius":float(item.params.get("puddle_radius",22.0)),
			"warning":float(item.params.get("puddle_tell",0.45)), "active":float(item.params.get("puddle_active",0.8)), "damage":int(item.params.get("puddle_damage",10)), "attack":item.attack + " puddle", "owner":item.owner})
	slots[index] = {}

func _draw() -> void:
	for item in slots:
		if item.is_empty(): continue
		var params: Dictionary = item.params
		var orbit := float(item.age) < float(params.get("orbit_time", 0.0))
		var color: Color = params.get("color", Color("ffca75"))
		if orbit: color = Color("cbb2ff")
		var radius := float(params.get("radius", 8.0))
		draw_line(item.position, Vector2(item.position) - Vector2(item.direction) * 20.0, Color(color, 0.35), radius, true)
		draw_circle(item.position, radius + 3.0, Color(color, 0.2))
		draw_circle(item.position, radius, color)
		draw_circle(item.position, radius * 0.40, Color("fff6d9"))
		if show_hitboxes: draw_arc(item.position, radius, 0, TAU, 20, Color.WHITE, 1.0, true)

