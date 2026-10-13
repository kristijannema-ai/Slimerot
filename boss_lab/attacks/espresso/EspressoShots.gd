extends BLAttack
## Alternating offset fans are locked before each volley, rather than homing.

func begin() -> void:
	attack_id = "espresso_shots"
	display_name = "Espresso Shots"
	var light := bool(params.get("light", false))
	var volleys := int(params.get("volleys", 2 if light else 3))
	var spacing := float(params.get("volley_spacing", 0.75))
	duration = (volleys - 1) * spacing + float(params.get("tell", 0.45)) + float(params.get("travel_allowance", 2.80))
	recovery = float(params.get("recovery", 0.25))
	for volley_index in range(volleys):
		var offset := float(params.get("aim_offset", 0.20)) * (-1.0 if volley_index % 2 == 0 else 1.0)
		at(volley_index * spacing, func(): volley(offset, light))

func volley(offset: float, light: bool) -> void:
	var origin := context.boss.global_position
	var aim := (context.predicted(float(params.get("lead", 1.10))) - origin).angle() + offset
	var direction := Vector2.from_angle(aim)
	var spread := float(params.get("spread", 1.00))
	var count := int(params.get("count", 3 if light else (7 if phase >= 3 else 5)))
	var tell := float(params.get("tell", 0.45))
	context.hazard({"kind":"sector", "origin":origin, "radius":430.0,
		"angle":aim, "arc":spread, "warning":tell, "active":0.04,
		"damage":0, "attack":display_name, "owner":attack_id,
		"color":Color("ff8a42"), "label":"COFFEE FAN"})
	at(elapsed + tell, func():
		context.fan(origin, direction, count, spread, float(params.get("speed", 250.0)), int(params.get("projectile_damage", 12)),
			display_name, attack_id, {"radius":float(params.get("projectile_radius", 8.0)), "puddle":phase >= 2,
				"puddle_radius":float(params.get("puddle_radius", 22.0)), "puddle_tell":float(params.get("puddle_tell", 0.45)),
				"puddle_active":float(params.get("puddle_active", 0.80)), "puddle_damage":int(params.get("puddle_damage", 10))}))
