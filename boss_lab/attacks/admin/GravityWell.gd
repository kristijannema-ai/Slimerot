extends BLAttack

var projectile_speed := 190.0

func begin() -> void:
	duration = 5.25
	finish_when_clear_after = 2.55
	recovery = 0.25
	projectile_speed = maxf(1.0, float(params.get("speed", 190.0)))
	var center := context.clamp_point(context.arena.get_center() + Vector2.from_angle(context.free_angle()) * 90.0, 130.0)
	context.hazard({"kind": "field", "origin": center, "radius": float(params.get("radius", 220.0)), "warning": float(params.get("tell", 0.85)), "active": 4.10, "damage": 0, "pull": float(params.get("pull", 48.0)), "attack": display_name, "owner": attack_id, "color": Color("b98af2"), "label": "GRAVITY WELL"})
	var volleys := [0.25, 1.10, 1.95]
	for index in volleys.size():
		at(volleys[index], _warn_fan.bind(index))

func _warn_fan(sequence: int) -> void:
	var origin := context.boss.global_position
	var direction := context.aim()
	duration = maxf(duration, elapsed + 0.55 + flight_allowance(origin, projectile_speed))
	context.hazard({"kind": "sector", "origin": origin, "radius": 560.0, "angle": direction.angle(), "arc": 0.93, "warning": 0.55, "active": 0.10, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("eb9f69"), "label": "GRAVITY / FAN"})
	at(elapsed + 0.55, func() -> void: context.fan(origin, direction, 3, 0.85, projectile_speed, int(params.get("projectile_damage", 10)), display_name, attack_id, {"sequence": sequence}))
