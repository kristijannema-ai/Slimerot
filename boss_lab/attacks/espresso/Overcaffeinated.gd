extends BLAttack
## Reuses the actual Charge and Slam modules; tempo rises without damage inflation.

const CHARGE := preload("res://attacks/espresso/CaffeineCharge.gd")
const SLAM := preload("res://attacks/espresso/EspressoSlam.gd")
var children: Array[BLAttack] = []

func begin() -> void:
	attack_id = "overcaffeinated"
	display_name = "Overcaffeinated"
	duration = float(params.get("duration", 8.40))
	recovery = float(params.get("recovery", 0.30))
	context.hazard({"kind":"circle", "origin":context.boss.global_position,
		"radius":70.0, "warning":float(params.get("power_tell", 0.35)), "active":maxf(0.0, duration - 0.50),
		"damage":0, "attack":display_name, "owner":attack_id,
		"follow_boss":true, "color":Color("ff4c25"), "label":"OVERCAFFEINATED"})
	context.fx(context.boss.global_position, Color("ff7438"), 20)
	var charge_values := {"tell":0.42, "travel":0.24, "single":true}
	charge_values.merge(params.get("charge_params", {}), true)
	var slam_values := {"tell":0.52}
	slam_values.merge(params.get("slam_params", {}), true)
	for time in params.get("charge_times", [0.35, 4.20]):
		at(float(time), func(): start_child(CHARGE, charge_values))
	for time in params.get("slam_times", [1.60, 5.00]):
		at(float(time), func(): start_child(SLAM, slam_values))

func start_child(script: Script, values: Dictionary) -> void:
	var child: BLAttack = script.new()
	child.setup(context, phase)
	child.params = values
	child.begin()
	duration = maxf(duration, elapsed + child.duration + 0.03)
	children.append(child)

func tick(delta: float) -> void:
	super.tick(delta)
	for child in children.duplicate():
		child.tick(delta)
		if child.ended:
			child.cleanup()
			children.erase(child)

func cleanup() -> void:
	for child in children:
		child.cleanup()
	children.clear()
	super.cleanup()
