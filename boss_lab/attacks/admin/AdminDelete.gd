extends BLAttack

func begin() -> void:
	duration = 3.0
	recovery = 0.25
	var arena := context.arena
	var size := Vector2(arena.size.x * 0.38, arena.size.y * 0.29)
	var areas: Array[Rect2] = [Rect2(arena.position, size), Rect2(Vector2(arena.end.x - size.x, arena.end.y - size.y), size), Rect2(Vector2(arena.end.x - size.x, arena.position.y), size), Rect2(Vector2(arena.position.x, arena.end.y - size.y), size)]
	var count := mini(4, phase)
	for index in count:
		context.hazard({"kind": "rect", "rect": areas[index], "warning": float(params.get("tell", 1.05)), "active": float(params.get("active", 1.45)), "damage": int(params.get("damage", 28)), "attack": display_name, "owner": attack_id, "color": Color("ed607b"), "label": "DELETE"})
	at(1.05, func() -> void: context.shake(0.65))
