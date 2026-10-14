extends BLAttack
## Three clear vertical routes, with exactly one blue lane remaining safe.

func begin() -> void:
	attack_id = "route_recalculation"
	display_name = "Route Recalculation"
	var tell := float(params.get("tell", 0.95))
	var active := float(params.get("active", 1.65))
	duration = tell + active + 0.35
	recovery = float(params.get("recovery", 0.25))
	var arena := context.arena
	var route_count := clampi(int(params.get("route_count", 3)), 2, 5)
	var route_width := arena.size.x / route_count
	var current := clampi(int((context.player.global_position.x - arena.position.x) / route_width), 0, route_count - 1)
	# Only the current route or a neighboring route is selected: no full-width scramble.
	var choices: Array[int] = [current]
	if current > 0:
		choices.append(current - 1)
	if current < route_count - 1:
		choices.append(current + 1)
	var safe_route := choices[context.rng.randi_range(0, choices.size() - 1)]
	for route in range(route_count):
		var x := arena.position.x + route_width * (route + 0.5)
		var safe := route == safe_route
		context.hazard({"kind":"lane", "origin":Vector2(x, arena.position.y),
			"end":Vector2(x, arena.end.y), "width":route_width - float(params.get("route_padding", 10.0)),
			"warning":tell, "active":active, "damage":0 if safe else int(params.get("damage", 20)),
			"attack":display_name, "owner":attack_id,
			"color":Color("68d9ff") if safe else Color("ff9352"),
			"label":"SAFE ROUTE" if safe else "REROUTING"})
