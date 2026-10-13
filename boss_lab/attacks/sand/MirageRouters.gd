extends BLAttack
## The live copy always has a blue ground rune. Decoys never deal damage.

func begin() -> void:
	attack_id = "mirage_routers"
	display_name = "Mirage Routers"
	var first_fan := float(params.get("first_fan", 0.25))
	var fan_spacing := float(params.get("fan_spacing", 1.00))
	duration = first_fan + fan_spacing + float(params.get("fan_tell", 0.55)) + float(params.get("travel_allowance", 3.10))
	recovery = float(params.get("recovery", 0.30))
	var arena := context.arena
	var copies := clampi(int(params.get("copies", 3)), 2, 5)
	var live := context.rng.randi_range(0, copies - 1)
	var sources: Array[Vector2] = []
	for index in range(copies):
		var point := Vector2(arena.position.x + arena.size.x * (index + 1) / (copies + 1.0), arena.position.y + float(params.get("source_y", 130.0)))
		sources.append(point)
		context.hazard({"kind":"circle", "origin":point, "radius":float(params.get("copy_radius", 33.0)),
			"warning":0.25, "active":maxf(0.0, duration - 0.60), "damage":0,
			"attack":display_name, "owner":attack_id,
			"color":Color("62dbff") if index == live else Color("b989db"),
			"label":"LIVE · RUNE" if index == live else "DECOY"})
		if index == live:
			context.hazard({"kind":"ring", "origin":point, "radius":float(params.get("rune_radius", 39.0)), "width":9.0,
				"warning":0.25, "active":maxf(0.0, duration - 0.60), "damage":0, "attack":display_name,
				"owner":attack_id, "color":Color("72e6ff"), "label":"LIVE RUNE"})
	at(first_fan, func(): show_fans(sources, live))
	at(first_fan + fan_spacing, func(): show_fans(sources, live))

func show_fans(sources: Array[Vector2], live: int) -> void:
	var target := context.predicted(float(params.get("lead", 1.10)))
	var tell := float(params.get("fan_tell", 0.55))
	var spread := float(params.get("spread", 1.00))
	for index in range(sources.size()):
		var source := sources[index]
		var aim := (target - source).normalized()
		context.hazard({"kind":"sector", "origin":source, "radius":390.0,
			"angle":aim.angle(), "arc":spread, "warning":tell, "active":0.05,
			"damage":0, "attack":display_name, "owner":attack_id,
			"color":Color("ffb24e") if index == live else Color("af83d7"),
			"label":"LIVE FAN" if index == live else "DECOY FAN"})
		if index == live:
			at(elapsed + tell, func():
				context.fan(source, aim, int(params.get("count", 5)), spread, float(params.get("speed", 235.0)),
					int(params.get("projectile_damage", 12)), display_name, attack_id, {"radius":float(params.get("projectile_radius", 8.0))}))
