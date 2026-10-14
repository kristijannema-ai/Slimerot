extends BLAttack
## Delayed future-position marks punish a single unchanging movement line.

func begin() -> void:
	attack_id = "double_shot"
	display_name = "Double Shot"
	var first_tell := float(params.get("first_tell", 0.70))
	var second_tell := float(params.get("second_tell", 1.00))
	var second_delay := float(params.get("second_delay", 0.12))
	duration = maxf(first_tell, second_delay + second_tell) + float(params.get("active", 0.18)) + 0.35
	recovery = float(params.get("recovery", 0.22))
	mark(context.predicted(float(params.get("first_lead", 0.35))), first_tell, "ONE")
	at(second_delay, func(): mark(context.predicted(float(params.get("second_lead", 0.80))), second_tell, "TWO"))

func mark(point: Vector2, tell: float, label: String) -> void:
	var radius := float(params.get("radius", 72.0))
	var destination := context.clamp_point(point, radius + 2.0)
	context.hazard({"kind":"circle", "origin":destination, "radius":radius,
		"warning":tell, "active":float(params.get("active", 0.18)), "damage":int(params.get("damage", 22)),
		"attack":display_name, "owner":attack_id,
		"color":Color("ff7841"), "label":label})
	at(elapsed + tell, func():
		context.fx(destination, Color("ffb356"), 14)
		context.shake(0.35))
