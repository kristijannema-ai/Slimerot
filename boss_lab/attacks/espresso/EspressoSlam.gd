extends BLAttack
## Rhythmic close-range impact followed by a readable radial route.

func begin() -> void:
	attack_id = "espresso_slam"
	display_name = "Espresso Slam"
	var tell := float(params.get("tell", 0.65))
	var waves := clampi(int(params.get("ring_count", 2 if phase >= 3 else 1)), 1, 3)
	var impact_radius := float(params.get("impact_radius", 115.0))
	var ring_delay := float(params.get("ring_delay", 0.02))
	var ring_interval := float(params.get("ring_interval", 0.55))
	var ring_tell := float(params.get("ring_tell", 0.30))
	var ring_active := float(params.get("ring_active", 1.95))
	var center := context.boss.global_position
	var gap := context.free_angle()
	duration = tell + ring_delay + ring_tell + ring_active + ring_interval * (waves - 1) + 0.03
	recovery = float(params.get("recovery", 0.35 if phase == 1 else 0.22))
	context.hazard({"kind":"circle", "origin":center, "radius":impact_radius,
		"warning":tell, "active":float(params.get("impact_active", 0.16)), "damage":int(params.get("impact_damage", 24)), "attack":display_name,
		"owner":attack_id, "color":Color("ff7044"), "label":"SLAM"})
	at(tell, func():
		context.fx(center, Color("ff9a43"), 18)
		context.shake(0.65))
	for wave in range(waves):
		var start := tell + ring_delay + ring_interval * wave
		var safe_gap := gap + float(params.get("gap_turn", 0.30)) * wave
		at(start, func():
			context.hazard({"kind":"ring", "origin":center, "radius":impact_radius,
				"width":float(params.get("ring_width", 26.0)), "growth":float(params.get("ring_speed", 210.0)), "gap_angle":safe_gap,
				"gap_width":float(params.get("gap_width", 0.76)), "warning":ring_tell, "active":ring_active,
				"damage":int(params.get("ring_damage", 18)), "attack":display_name, "owner":attack_id,
				"color":Color("ff9147"), "label":"GAP / DASH"}))
