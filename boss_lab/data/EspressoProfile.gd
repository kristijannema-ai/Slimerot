extends BLProfile
## All numbers here are provisional encounter-design values, not proven clear rates.

func _init() -> void:
	id = "espresso"
	display_name = "Espresso Golem"
	subtitle = "Rhythm, locked charges, and patient Dash timing"
	arena_color = Color("442c30")
	accent = Color("ffb257")
	max_hp = 18000.0
	phase_thresholds = [0.70, 0.35]
	attacks = {
		"espresso_slam": {"script":preload("res://attacks/espresso/EspressoSlam.gd"), "min_phase":1,
			"weight":3.0, "phase_weights":[3.0,3.5,3.0], "major":false, "duration":2.97,
			"tell":0.65, "damage":24, "response":"Leave the orange circle; use the blue ring gap or Dash through the wave.", "params":{}},
		"caffeine_charge": {"script":preload("res://attacks/espresso/CaffeineCharge.gd"), "min_phase":1,
			"weight":3.0, "phase_weights":[3.0,3.5,3.0], "major":false, "duration":1.30,
			"tell":0.55, "damage":27, "response":"The yellow lane locks. Sidestep or Dash at ignition; phase 3 repeats sideways.", "params":{}},
		"espresso_shots": {"script":preload("res://attacks/espresso/EspressoShots.gd"), "min_phase":1,
			"weight":3.0, "phase_weights":[3.0,2.5,2.0], "major":false, "duration":4.75,
			"tell":0.45, "damage":12, "response":"Weave through alternating left/right fan spokes. Phase 2 leaves briefly warned puddles.", "params":{}},
		"double_shot": {"script":preload("res://attacks/espresso/DoubleShot.gd"), "min_phase":2,
			"weight":2.5, "phase_weights":[0.0,2.5,3.0], "major":false, "duration":1.65,
			"tell":0.70, "damage":22, "response":"Two future-position circles explode at different times. Reverse, stop, or delay Dash until TWO.", "params":{}},
		"overcaffeinated": {"script":preload("res://attacks/espresso/Overcaffeinated.gd"), "min_phase":3,
			"weight":2.0, "phase_weights":[0.0,0.0,2.0], "major":true, "duration":8.40,
			"tell":0.35, "damage":27, "response":"An eight-second Charge/Slam rhythm. Reuse gap routes; conserve Dash for charges.", "params":{}}
	}
	combos = [{"primary":"espresso_shots", "secondary":"caffeine_charge", "min_phase":3,
		"delay":0.95, "primary_params":{"light":true}, "secondary_params":{"single":true}}]
