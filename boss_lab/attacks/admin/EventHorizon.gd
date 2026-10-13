extends BLAttack

var projectile_speed := 160.0

func begin() -> void:
	duration = 6.10
	finish_when_clear_after = 3.80
	recovery = 0.40
	projectile_speed = maxf(1.0, float(params.get("speed", 160.0)))
	var center := context.arena.get_center()
	context.move_boss_to(center, 0.45, attack_id)
	context.hazard({"kind": "annulus", "origin": center, "safe_radius": float(params.get("safe_radius", 170.0)), "width": float(params.get("safe_width", 160.0)), "growth": float(params.get("growth", 40.0)), "warning": float(params.get("tell", 1.45)), "active": 4.40, "damage": int(params.get("damage", 32)), "attack": display_name, "owner": attack_id, "color": Color("bf89ec"), "label": "EVENT HORIZON / BLUE BAND SAFE"})
	var volleys := [1.60, 2.35, 3.10]
	for index in volleys.size():
		var sequence: int = index
		at(volleys[index], func() -> void:
			var direction := context.aim()
			duration = maxf(duration, elapsed + 0.65 + flight_allowance(center, projectile_speed))
			context.hazard({"kind": "lane", "origin": center, "end": context.clamp_point(center + direction * 560.0), "width": 18.0, "warning": 0.65, "active": 0.1, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("eda66e")})
			at(elapsed + 0.65, func() -> void: context.shot(center, direction, projectile_speed, int(params.get("projectile_damage", 10)), display_name, attack_id, {"sequence": sequence}))
		)
