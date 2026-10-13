extends BLAttack
## Moderate, finite slowing fields; never disables movement or Dash.

func begin() -> void:
	attack_id = "quicksand_nodes"
	display_name = "Quicksand Nodes"
	var tell := float(params.get("tell", 0.65))
	var active := float(params.get("active", 3.85))
	var fan_delay := float(params.get("fan_delay", 1.0))
	duration = maxf(tell + active, fan_delay + float(params.get("fan_tell", 0.50)) + float(params.get("travel_allowance", 3.30)))
	recovery = float(params.get("recovery", 0.25))
	var count := clampi(int(params.get("node_count", 3 if phase == 1 else 4)), 1, 6)
	var center := context.arena.get_center()
	var jitter := float(params.get("angle_jitter", 0.25))
	var phase_offset := context.rng.randf_range(-jitter, jitter)
	for index in range(count):
		var angle := TAU * float(index) / count + phase_offset
		var point := center + Vector2(cos(angle) * float(params.get("spread_x", 180.0)), sin(angle) * float(params.get("spread_y", 230.0)))
		if index == 0:
			point = context.predicted(float(params.get("lead", 0.65)))
		var radius := float(params.get("radius", 62.0))
		point = context.clamp_point(point, radius + 6.0)
		context.hazard({"kind":"field", "origin":point, "radius":radius,
			"warning":tell, "active":active, "damage":0, "slow":float(params.get("slow", 0.65)),
			"attack":display_name, "owner":attack_id,
			"color":Color("c38cf1"), "label":"QUICKSAND · %d%%" % roundi(float(params.get("slow", 0.65)) * 100.0)})

	at(fan_delay, func(): light_fan())

func light_fan() -> void:
	var origin := context.boss.global_position
	var aim := (context.predicted(float(params.get("fan_lead", 0.90))) - origin).normalized()
	var tell := float(params.get("fan_tell", 0.50))
	var spread := float(params.get("fan_spread", 1.00))
	context.hazard({"kind":"sector", "origin":origin, "radius":450.0,
		"angle":aim.angle(), "arc":spread, "warning":tell, "active":0.04,
		"damage":0, "attack":display_name, "owner":attack_id,
		"color":Color("ffb84b"), "label":"QUICKSAND FAN"})
	at(elapsed + tell, func():
		context.fan(origin, aim, int(params.get("fan_count", 3)), spread, float(params.get("fan_speed", 210.0)),
			int(params.get("projectile_damage", 12)), display_name, attack_id, {"radius":float(params.get("projectile_radius", 8.0))}))
