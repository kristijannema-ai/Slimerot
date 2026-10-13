extends BLAttack
## Progressive edge bands retain a broad center; its fans are intentionally light.

func begin() -> void:
	attack_id = "sand_collapse"
	display_name = "Sand Collapse"
	duration = float(params.get("duration", 6.35))
	recovery = float(params.get("recovery", 0.35))
	var widths: Array = params.get("edge_widths", [100.0, 180.0, 250.0])
	var delays: Array = params.get("edge_delays", [0.0, 1.25, 2.70])
	var tells: Array = params.get("edge_tells", [1.10, 0.80, 0.80])
	var lifetimes: Array = params.get("edge_lifetimes", [4.85, 3.90, 2.40])
	for index in mini(mini(widths.size(), delays.size()), mini(tells.size(), lifetimes.size())):
		var width := float(widths[index])
		var tell := float(tells[index])
		var active := float(lifetimes[index])
		var delay := float(delays[index])
		duration = maxf(duration, delay + tell + active + 0.15)
		if is_zero_approx(delay):
			add_edges(width, tell, active)
		else:
			at(delay, func(): add_edges(width, tell, active))
	for time in params.get("fan_times", [1.50, 3.40]):
		at(float(time), func(): small_fan())
	at(3.50, func(): context.shake(0.55))

func add_edges(width: float, tell: float, active: float) -> void:
	var arena := context.arena
	var lines := [
		[Vector2(arena.position.x, arena.position.y), Vector2(arena.position.x, arena.end.y)],
		[Vector2(arena.end.x, arena.position.y), Vector2(arena.end.x, arena.end.y)],
		[Vector2(arena.position.x, arena.position.y), Vector2(arena.end.x, arena.position.y)],
		[Vector2(arena.position.x, arena.end.y), Vector2(arena.end.x, arena.end.y)]]
	for line in lines:
		context.hazard({"kind":"lane", "origin":line[0], "end":line[1],
			"width":width, "warning":tell, "active":active, "damage":int(params.get("edge_damage", 30)),
			"attack":display_name, "owner":attack_id,
			"color":Color("ff8651"), "label":"SAND COLLAPSE"})

func small_fan() -> void:
	var origin := context.boss.global_position
	var lead := float(params.get("lead", 0.0))
	var target := context.player.global_position if is_zero_approx(lead) else context.predicted(lead)
	var aim := (target - origin).normalized()
	var spread := float(params.get("spread", 1.10))
	var tell := float(params.get("fan_tell", 0.55))
	context.hazard({"kind":"sector", "origin":origin, "radius":450.0,
		"angle":aim.angle(), "arc":spread, "warning":tell, "active":0.04,
		"damage":0, "attack":display_name, "owner":attack_id,
		"color":Color("ffbf52"), "label":"LIGHT FAN"})
	at(elapsed + tell, func():
		context.fan(origin, aim, int(params.get("count", 3)), spread, float(params.get("speed", 210.0)),
			int(params.get("projectile_damage", 12)), display_name, attack_id, {"radius":float(params.get("projectile_radius", 8.0))}))
