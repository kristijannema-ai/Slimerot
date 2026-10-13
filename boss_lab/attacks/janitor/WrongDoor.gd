extends BLAttack

func begin() -> void:
	duration = 3.70
	recovery = 0.25
	var arena := context.arena
	var doors: Array[Vector2] = [Vector2(arena.position.x + 34, arena.get_center().y), Vector2(arena.end.x - 34, arena.get_center().y), Vector2(arena.get_center().x, arena.position.y + 34), Vector2(arena.get_center().x, arena.end.y - 34)]
	var first := context.rng.randi_range(0, 3)
	var order: Array[int] = [first, (first + 2) % 4, (first + 1) % 4, (first + 3) % 4]
	context.boss.modulate.a = 0.22
	for step in 4:
		var point: Vector2 = doors[order[step]]
		at(float(step) * 0.36, func() -> void:
			context.hazard({"kind": "circle", "origin": point, "radius": 34.0, "warning": 0.26, "active": 0.06, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("c7a4ff"), "label": "DOOR"})
		)
	var exit: Vector2 = doors[order[3]]
	at(1.50, func() -> void: context.move_boss_to(exit, 0.10, attack_id))
	at(1.60, func() -> void:
		context.boss.modulate.a = 1.0
		var angle := (arena.get_center() - exit).angle()
		context.hazard({"kind": "sector", "origin": exit, "radius": float(params.get("radius", 420.0)), "angle": angle - 1.6, "arc": 1.40, "angular_speed": 2.8, "warning": float(params.get("sweep_tell", 0.60)), "active": 1.00, "damage": int(params.get("damage", 30)), "attack": display_name, "owner": attack_id, "color": Color("edab52"), "label": "DOOR / MOP ↻"})
	)

func cleanup() -> void:
	context.boss.modulate.a = 1.0
	super.cleanup()
