extends BLAttack

func begin() -> void:
	duration = 2.85
	recovery = 0.30
	var arena := context.arena
	var width := float(params.get("edge_width", 70.0 if phase < 4 else 82.0))
	var rectangles: Array[Rect2] = [Rect2(arena.position, Vector2(arena.size.x, width)), Rect2(Vector2(arena.position.x, arena.end.y - width), Vector2(arena.size.x, width)), Rect2(arena.position + Vector2(0, width), Vector2(width, arena.size.y - width * 2)), Rect2(Vector2(arena.end.x - width, arena.position.y + width), Vector2(width, arena.size.y - width * 2))]
	for rectangle in rectangles:
		context.hazard({"kind": "rect", "rect": rectangle, "warning": 1.05, "active": 1.45, "damage": int(params.get("damage", 26)), "attack": display_name, "owner": attack_id, "color": Color("f06980"), "label": "EDGE / REPULSION"})
	context.hazard({"kind": "field", "origin": arena.get_center(), "radius": 470.0, "warning": float(params.get("tell", 1.05)), "active": 0.55, "damage": 0, "push": float(params.get("push", 95.0)), "attack": display_name, "owner": attack_id, "color": Color("bd8cea"), "label": "REPULSION → EDGES"})
	at(1.05, func() -> void:
		context.fx(arena.get_center(), Color("b68cff"), 16)
		context.shake(0.8)
	)
