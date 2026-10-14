extends BLAttack

func begin() -> void:
	duration = 2.70
	recovery = 0.25
	var origin := context.boss.global_position
	var direction := (context.predicted(0.25) - origin).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.DOWN
	var destination := context.clamp_point(origin + direction * 800.0, 34.0)
	var tell := float(params.get("tell", 0.78 if phase < 4 else 0.66))
	context.hazard({"kind": "lane", "origin": origin, "end": destination, "width": float(params.get("width", 70.0)), "warning": tell, "active": 0.24, "damage": int(params.get("damage", 30)), "attack": display_name, "owner": attack_id, "color": Color("eec156"), "label": "SINGULARITY DASH →"})
	at(tell, func() -> void:
		context.move_boss_to(destination, 0.20, attack_id)
		context.fx(origin, Color("b08ae9"), 12)
		context.shake(0.70)
	)
	at(tell + 0.30, func() -> void:
		context.hazard({"kind": "field", "origin": (origin + destination) * 0.5, "radius": float(params.get("wake_radius", 180.0)), "warning": 0.30, "active": 0.85, "damage": 0, "pull": float(params.get("wake_pull", 42.0)), "attack": display_name, "owner": attack_id, "color": Color("b08ae9"), "label": "GRAVITY WAKE"})
	)
