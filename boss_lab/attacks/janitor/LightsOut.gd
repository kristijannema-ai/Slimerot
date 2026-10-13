extends BLAttack

func begin() -> void:
	duration = 3.10
	recovery = 0.30
	context.darkness = float(params.get("darkness", 0.54))
	var center := context.predicted(0.30)
	for index in 3:
		var offset := Vector2.from_angle(float(index) * TAU / 3.0 + 0.5) * 108.0
		var point := context.clamp_point(center + offset, 70.0)
		at(0.35 + float(index) * 0.48, func() -> void:
			context.hazard({"kind": "circle", "origin": point, "radius": float(params.get("radius", 76.0)), "warning": float(params.get("tell", 1.05)), "active": 0.30, "damage": int(params.get("damage", 22)), "attack": display_name, "owner": attack_id, "color": Color("ffc564"), "label": "WARNING LIGHT"})
		)
	at(2.85, func() -> void: context.darkness = 0.0)

func cleanup() -> void:
	context.darkness = 0.0
	super.cleanup()
