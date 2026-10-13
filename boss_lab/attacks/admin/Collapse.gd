extends BLAttack

var projectile_speed := 170.0

func begin() -> void:
	duration = 5.15
	finish_when_clear_after = 2.15
	recovery = 0.30
	projectile_speed = maxf(1.0, float(params.get("speed", 170.0)))
	var arena := context.arena
	var corridor := float(params.get("corridor", 96.0))
	var size := (arena.size - Vector2.ONE * corridor) * 0.5
	var areas: Array[Rect2] = [Rect2(arena.position, size), Rect2(Vector2(arena.end.x - size.x, arena.position.y), size), Rect2(arena.end - size, size), Rect2(Vector2(arena.position.x, arena.end.y - size.y), size)]
	var first := context.rng.randi_range(0, 3)
	var count := 2 if phase >= 4 else 1
	for index in count:
		context.hazard({"kind": "rect", "rect": areas[(first + index) % 4], "warning": float(params.get("tell", 1.25)), "active": float(params.get("active", 3.45)), "damage": int(params.get("damage", 32)), "attack": display_name, "owner": attack_id, "color": Color("ec6c86"), "label": "COLLAPSE"})
	var volleys := [0.55, 1.45]
	for index in volleys.size():
		var sequence: int = index
		at(volleys[index], func() -> void:
			var origin := context.boss.global_position
			var direction := context.aim()
			duration = maxf(duration, elapsed + 0.65 + flight_allowance(origin, projectile_speed))
			context.hazard({"kind": "sector", "origin": origin, "radius": 560.0, "angle": direction.angle(), "arc": 0.98, "warning": 0.65, "active": 0.1, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("e9af70")})
			at(elapsed + 0.65, func() -> void: context.fan(origin, direction, 3, 0.9, projectile_speed, int(params.get("projectile_damage", 10)), display_name, attack_id, {"sequence": sequence}))
		)
