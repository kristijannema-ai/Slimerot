extends BLAttack
## Crossing wall with a nearby guaranteed route; later the route glides sideways.

func begin() -> void:
	attack_id = "sand_wall"
	display_name = "Sand Wall"
	var tell := float(params.get("tell", 0.90))
	var active := float(params.get("active", 5.65))
	duration = tell + active + 0.10
	recovery = float(params.get("recovery", 0.30))
	var arena := context.arena
	var from_top := context.rng.randf() < 0.5
	var start_y := arena.position.y + 12.0 if from_top else arena.end.y - 12.0
	var direction := 1.0 if from_top else -1.0
	var gap_width := float(params.get("gap_width", 156.0 if phase >= 2 else 132.0))
	var center_margin := maxf(88.0, gap_width * 0.5 + 6.0)
	var gap_center := clampf(context.predicted(float(params.get("lead", 0.50))).x,
		arena.position.x + center_margin, arena.end.x - center_margin)
	var gaps: Array[Vector2] = [Vector2(gap_center - gap_width * 0.5, gap_center + gap_width * 0.5)]
	if phase == 1:
		var second_center := arena.position.x + maxf(105.0, center_margin) if gap_center > arena.get_center().x else arena.end.x - maxf(105.0, center_margin)
		gaps.append(Vector2(second_center - gap_width * 0.5, second_center + gap_width * 0.5))
	var drift := 0.0
	if phase >= 2:
		drift = float(params.get("gap_speed", 54.0 if phase == 2 else 66.0)) * (-1.0 if gap_center > arena.get_center().x else 1.0)
	context.hazard({"kind":"wall", "origin":Vector2(arena.get_center().x, start_y),
		"width":float(params.get("width", 28.0)), "warning":tell, "active":active, "gaps":gaps,
		"gap_speed":drift, "gap_bounds":Vector2(arena.position.x + 6.0, arena.end.x - 6.0),
		"velocity":Vector2(0.0, direction * float(params.get("speed", 132.0))), "damage":int(params.get("damage", 23)),
		"attack":display_name, "owner":attack_id, "color":Color("ffd250"),
		"label":"BLUE GAP"})
