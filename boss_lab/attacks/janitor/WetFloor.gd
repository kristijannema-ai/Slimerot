extends BLAttack

func begin() -> void:
	duration = 3.15
	recovery = 0.25
	var rows := [context.arena.position.y + context.arena.size.y * 0.35, context.arena.position.y + context.arena.size.y * 0.68]
	for row in rows:
		context.hazard({"kind": "lane", "origin": Vector2(context.arena.position.x + 48.0, row), "end": Vector2(context.arena.end.x - 48.0, row), "width": float(params.get("width", 48.0)), "warning": float(params.get("tell", 0.65)), "active": 2.30, "damage": 0, "slow": float(params.get("slow", 0.86)), "slide": true, "attack": display_name, "owner": attack_id, "color": Color("62bad0"), "label": "WET FLOOR"})
