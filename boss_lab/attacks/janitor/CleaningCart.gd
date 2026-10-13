extends BLAttack

func begin() -> void:
	duration = 4.65
	recovery = 0.30
	var y := clampf(context.predicted(0.35).y, context.arena.position.y + 130.0, context.arena.end.y - 130.0)
	var start := Vector2(context.arena.position.x + 35.0, y)
	var destination := Vector2(context.arena.end.x - 35.0, y)
	var tell := float(params.get("tell", 0.80))
	var bottle_speed := maxf(1.0, float(params.get("bottle_speed", 230.0)))
	var travel := 2.30 if phase < 3 else 2.00
	finish_when_clear_after = tell + travel + 0.45
	duration = maxf(duration, tell + travel + 0.40 + flight_allowance(destination, bottle_speed))
	context.hazard({"kind": "lane", "origin": start, "end": destination, "width": 112.0, "warning": tell, "active": travel, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("ecc554"), "label": "CART →"})
	context.hazard({"kind": "rect", "rect": Rect2(start - Vector2(32, 58), Vector2(64, 116)), "velocity": Vector2((destination.x - start.x) / travel, 0), "warning": tell, "active": travel, "damage": int(params.get("cart_damage", 24)), "attack": display_name, "owner": attack_id, "color": Color("f2a344"), "label": "CART"})
	at(tell + travel, func() -> void:
		for direction in [Vector2.UP, Vector2.DOWN]:
			context.hazard({"kind": "sector", "origin": destination, "radius": 360.0, "angle": direction.angle(), "arc": 0.68, "warning": 0.40, "active": 0.12, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("f2a344"), "label": "BOTTLES"})
		at(elapsed + 0.40, func() -> void:
			context.fan(destination, Vector2.UP, 3, 0.6, bottle_speed, int(params.get("bottle_damage", 12)), display_name, attack_id, {"sequence": 0})
			context.fan(destination, Vector2.DOWN, 3, 0.6, bottle_speed, int(params.get("bottle_damage", 12)), display_name, attack_id, {"sequence": 0})
		)
	)
