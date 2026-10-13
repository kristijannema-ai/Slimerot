extends BLAttack

func begin() -> void:
	duration = 2.05
	recovery = 0.25
	var approach := Vector2.from_angle(context.free_angle()) * 96.0
	var destination := context.clamp_point(context.predicted(0.35) + approach, 50.0)
	if destination.distance_to(context.player.global_position) < 60.0:
		destination = context.clamp_point(context.predicted(0.35) - approach, 50.0)
	var windup := float(params.get("arrival", 0.70 if phase == 1 else 0.60))
	context.darkness = 0.18
	context.hazard({"kind": "circle", "origin": destination, "radius": 36.0, "warning": windup, "active": 0.20, "damage": 0, "attack": display_name, "owner": attack_id, "color": Color("c89fff"), "label": "ARRIVAL"})
	context.fx(context.boss.global_position, Color("b2a1d9"), 8)
	at(windup - 0.08, func() -> void: context.move_boss_to(destination, 0.08, attack_id))
	at(windup, func() -> void:
		context.darkness = 0.0
		var angle := (context.player.global_position - destination).angle()
		context.hazard({"kind": "sector", "origin": destination, "radius": float(params.get("radius", 145.0)), "angle": angle - 0.5, "arc": 1.4, "angular_speed": 2.3, "warning": float(params.get("followup_tell", 0.46)), "active": 0.40, "damage": int(params.get("damage", 22)), "attack": display_name, "owner": attack_id, "color": Color("ed9e4b"), "label": "EMERGE / SWEEP"})
	)

func cleanup() -> void:
	context.darkness = 0.0
	super.cleanup()
