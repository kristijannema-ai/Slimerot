extends BLAttack
## Offset second fan threads between the first fan's angular spokes.

func begin() -> void:
	attack_id = "sand_fan"
	display_name = "Sand Fan"
	var light := bool(params.get("light", false))
	var volleys := int(params.get("volleys", 1 if light else 2))
	var spacing := float(params.get("volley_spacing", 0.90))
	duration = (volleys - 1) * spacing + float(params.get("tell", 0.50)) + float(params.get("travel_allowance", 3.05))
	recovery = float(params.get("recovery", 0.25))
	for volley in range(volleys):
		var offset := float(params.get("second_offset", 0.125)) if volley % 2 == 1 else 0.0
		at(volley * spacing, func(): launch(offset, light))

func launch(offset: float, light: bool) -> void:
	var origin := context.boss.global_position
	var angle := (context.predicted(float(params.get("lead", 1.15))) - origin).angle() + offset
	var direction := Vector2.from_angle(angle)
	var spread := float(params.get("spread", 1.00))
	var tell := float(params.get("tell", 0.50))
	context.hazard({"kind":"sector", "origin":origin, "radius":450.0,
		"angle":angle, "arc":spread, "warning":tell, "active":0.04,
		"damage":0, "attack":display_name, "owner":attack_id,
		"color":Color("ffb84b"), "label":"SAND FAN"})
	at(elapsed + tell, func():
		context.fan(origin, direction, int(params.get("count", 3 if light else 5)), spread,
			float(params.get("speed", 210.0 if light else 230.0)), int(params.get("projectile_damage", 12)), display_name, attack_id,
			{"radius":float(params.get("projectile_radius", 8.0))}))
