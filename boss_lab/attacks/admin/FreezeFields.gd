extends BLAttack

var projectile_speed := 180.0

func begin() -> void:
	duration = 4.85
	finish_when_clear_after = 1.90
	recovery = 0.25
	projectile_speed = maxf(1.0, float(params.get("speed", 180.0)))
	var arena := context.arena
	for x_fraction in [0.24, 0.76]:
		for y_fraction in [0.28, 0.72]:
			var point := arena.position + arena.size * Vector2(x_fraction, y_fraction)
			context.hazard({"kind": "field", "origin": point, "radius": float(params.get("radius", 78.0)), "warning": float(params.get("tell", 0.85)), "active": 3.55, "damage": 0, "slow": float(params.get("slow", 0.45)), "attack": display_name, "owner": attack_id, "color": Color("ab88e5"), "label": "FREEZE FIELD"})
	var volleys := [0.20, 1.25]
	for index in volleys.size():
		var sequence: int = index
		at(volleys[index], func() -> void:
			var origin := context.boss.global_position
			var direction := context.aim()
			duration = maxf(duration, elapsed + 0.6 + flight_allowance(origin, projectile_speed))
			context.hazard({"kind": "sector", "origin": origin, "radius": 560.0, "angle": direction.angle(), "arc": 0.88, "warning": 0.6, "active": 0.1, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("ecae6c")})
			at(elapsed + 0.6, func() -> void: context.fan(origin, direction, 3, 0.80, projectile_speed, int(params.get("projectile_damage", 10)), display_name, attack_id, {"sequence": sequence}))
		)
