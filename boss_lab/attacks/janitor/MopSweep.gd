extends BLAttack

func begin() -> void:
	recovery = 0.30
	duration = 4.00 if phase >= 3 else 2.30
	_sweep(1.0, 0.65)
	if phase >= 3:
		at(2.05, func() -> void: _sweep(-1.0, 0.55))

func _sweep(direction: float, tell: float) -> void:
	var aim_angle := context.aim().angle()
	context.hazard({"kind": "sector", "origin": context.boss.global_position, "radius": float(params.get("radius", 175.0)), "angle": aim_angle - direction * 2.3, "arc": float(params.get("arc", 1.22)), "angular_speed": direction * float(params.get("sweep_speed", 4.2)), "warning": tell, "active": 1.10, "damage": int(params.get("damage", 27)), "attack": display_name, "owner": attack_id, "color": Color("f0b454"), "label": "MOP ↻" if direction > 0 else "MOP ↺"})
