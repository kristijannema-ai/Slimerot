extends BLAttack

func begin() -> void:
	recovery = 0.25
	var count := 8 if phase >= 3 else 6
	var radius := float(params.get("radius", 96.0))
	var angular_speed := float(params.get("orbit_speed", 1.70))
	var speed := maxf(1.0, float(params.get("speed", 225.0)))
	var center := context.boss.global_position
	var target := context.predicted(0.30)
	for index in count:
		var angle := float(index) * TAU / float(count)
		var release_time := 1.15 + float(index) * float(params.get("stagger", 0.32))
		var release_origin := center + Vector2.from_angle(angle + angular_speed * release_time) * radius
		context.shot(center + Vector2.from_angle(angle) * radius, (target - release_origin).normalized(), speed, int(params.get("damage", 12)), display_name, attack_id, {"orbit_center": center, "orbit_radius": radius, "orbit_angle": angle, "orbit_speed": angular_speed, "orbit_time": release_time, "release_aim": target, "release_track": true, "radius": 8.0, "sequence": index})

	var last_release := 1.15 + float(count - 1) * float(params.get("stagger", 0.32))
	finish_when_clear_after = last_release + 0.05
	duration = last_release + flight_allowance(center, speed) + radius / speed
