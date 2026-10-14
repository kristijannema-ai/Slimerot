extends BLAttack
## Aim is locked at the tell, giving a reliable dash/sidestep rule.

func begin() -> void:
	attack_id = "caffeine_charge"
	display_name = "Caffeine Charge"
	var tell := float(params.get("tell", 0.55))
	var travel := float(params.get("travel", 0.30))
	var follow_up := phase >= 3 and not bool(params.get("single", false))
	var follow_delay := float(params.get("follow_delay", 0.35))
	var follow_tell := float(params.get("follow_tell", 0.55))
	duration = tell + travel + (follow_delay + follow_tell + travel + float(params.get("follow_recovery", 0.35)) if follow_up else float(params.get("wall_recovery", 0.45)))
	recovery = float(params.get("recovery", 0.40))
	charge(context.boss.global_position, context.predicted(float(params.get("lead", 0.45))), tell, travel)
	if follow_up:
		at(tell + travel + follow_delay, func():
			var start := context.boss.global_position
			var to_player := (context.predicted(float(params.get("follow_lead", 0.40))) - start).normalized()
			var turn := float(params.get("follow_turn", 0.18)) * (-1.0 if context.rng.randf() < 0.5 else 1.0)
			var side := to_player.rotated(turn)
			charge(start, start + side * float(params.get("distance", 700.0)), follow_tell, travel))

func charge(start: Vector2, target: Vector2, tell: float, travel: float) -> void:
	var direction := (target - start).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.DOWN
	var destination := context.clamp_point(start + direction * float(params.get("distance", 700.0)), 38.0)
	context.hazard({"kind":"lane", "origin":start, "end":destination,
		"width":float(params.get("width", 160.0)), "warning":tell, "active":travel,
		"damage":int(params.get("damage", 27)), "attack":display_name, "owner":attack_id,
		"color":Color("ffce51"), "label":"LOCKED CHARGE"})
	at(elapsed + tell, func():
		context.move_boss_to(destination, travel, attack_id)
		context.fx(start, Color("ffc94a"), 12))
	at(elapsed + tell + travel, func():
		context.fx(destination, Color("f4b85a"), 10)
		context.shake(0.35))
