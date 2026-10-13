extends BLProfile

func _init() -> void:
	id = "janitor"
	display_name = "BACKROOMS JANITOR"
	subtitle = "Read the last door. Respect the mop."
	arena_color = Color("514d36")
	accent = Color("e1d981")
	max_hp = 19500.0
	phase_thresholds = [0.70, 0.35]
	phase_recovery = [0.35, 0.25, 0.20]
	attacks = {
		"janitor_teleport": _move(preload("res://attacks/janitor/JanitorTeleport.gd"), "Janitor Teleport", 1, [3.0, 2.7, 2.3], false, 2.05, 0.70, 22, "Watch destination, then leave or Dash through the sweep.", {"followup_tell": 0.46, "radius": 145.0, "damage": 22}),
		"mop_sweep": _move(preload("res://attacks/janitor/MopSweep.gd"), "Mop Sweep", 1, [3.0, 2.4, 2.8], false, 2.30, 0.65, 27, "Step beyond 175 px or Dash through; phase 3 reverses direction.", {"radius": 175.0, "arc": 1.22, "sweep_speed": 4.2, "damage": 27}),
		"cleaning_cart": _move(preload("res://attacks/janitor/CleaningCart.gd"), "Cleaning Cart", 1, [2.5, 1.8, 1.5], false, 4.65, 0.80, 24, "Go ahead or behind the cart; watch bottles at the far wall.", {"tell": 0.80, "cart_damage": 24, "bottle_damage": 12}),
		"wet_floor": _move(preload("res://attacks/janitor/WetFloor.gd"), "Wet Floor", 2, [0.0, 2.1, 2.2], false, 3.15, 0.65, 0, "Avoid blue strips or correct bounded slide; controls stay active.", {"tell": 0.65, "width": 48.0, "slow": 0.86}),
		"wrong_door": _move(preload("res://attacks/janitor/WrongDoor.gd"), "Wrong Door", 2, [0.0, 2.5, 2.3], true, 3.70, 1.60, 30, "Remember the fourth/last flashing door; leave its 420 px sweep.", {"sweep_tell": 0.60, "radius": 420.0, "damage": 30}),
		"lights_out": _move(preload("res://attacks/janitor/LightsOut.gd"), "Lights Out", 3, [0.0, 0.0, 2.4], true, 3.10, 1.05, 22, "Read bright warning circles in the dim arena; change your route.", {"darkness": 0.54, "radius": 76.0, "tell": 1.05, "damage": 22})
	}
	combos = [
		{"primary": "wet_floor", "secondary": "janitor_teleport", "min_phase": 2, "delay": 0.85, "chance": 1.0},
		{"primary": "lights_out", "secondary": "wet_floor", "min_phase": 3, "delay": 0.10, "chance": 1.0}
	]

func _move(script: Script, name: String, first_phase: int, weights: Array, major: bool, seconds: float, tell: float, damage: int, response: String, values: Dictionary) -> Dictionary:
	return {"script": script, "name": name, "min_phase": first_phase, "weight": weights[first_phase - 1], "phase_weights": weights, "major": major, "duration": seconds, "tell": tell, "damage": damage, "response": response, "params": values}
