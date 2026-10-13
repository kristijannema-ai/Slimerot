extends BLProfile

func _init() -> void:
	id = "admin"
	display_name = "SINGULARITY ADMIN"
	subtitle = "Space obeys commands. Your controls do not."
	arena_color = Color("221a39")
	accent = Color("c58cff")
	max_hp = 22500.0
	phase_thresholds = [0.70, 0.40, 0.15]
	phase_recovery = [0.35, 0.27, 0.20, 0.16]
	phase_arena_insets = {4: 24.0}
	attacks = {
		"gravity_well": _move(preload("res://attacks/admin/GravityWell.gd"), "Gravity Well", 1, [3.0, 2.5, 2.2, 2.6], false, 5.25, 0.85, 10, "Move against 48 px/s pull; weave three lightly spread fans.", {"radius": 220.0, "tell": 0.85, "pull": 48.0, "projectile_damage": 10}),
		"orbital_projectiles": _move(preload("res://attacks/admin/OrbitalProjectiles.gd"), "Orbital Projectiles", 1, [3.0, 2.4, 2.0, 2.4], false, 4.55, 1.15, 12, "Harmless orbit, then staggered telegraphed launches; keep changing direction.", {"radius": 96.0, "orbit_speed": 1.70, "stagger": 0.32, "speed": 225.0, "damage": 12}),
		"singularity_dash": _move(preload("res://attacks/admin/SingularityDash.gd"), "Singularity Dash", 1, [3.0, 2.8, 2.5, 3.3], false, 2.70, 0.78, 30, "Leave yellow lane or Dash; purple wake pulls but never locks you.", {"width": 70.0, "damage": 30, "wake_radius": 180.0, "wake_pull": 42.0}),
		"repulsion": _move(preload("res://attacks/admin/Repulsion.gd"), "Repulsion", 2, [0.0, 2.0, 1.8, 2.4], false, 2.85, 1.05, 26, "Position inward before the push; edge rectangles deal damage.", {"tell": 1.05, "push": 95.0, "damage": 26}),
		"admin_delete": _move(preload("res://attacks/admin/AdminDelete.gd"), "Admin Delete", 2, [0.0, 2.1, 2.4, 3.0], false, 3.00, 1.05, 28, "Leave red rectangles; the broad central cross always stays connected.", {"tell": 1.05, "active": 1.45, "damage": 28}),
		"freeze_fields": _move(preload("res://attacks/admin/FreezeFields.gd"), "Admin Command: Freeze", 2, [0.0, 1.8, 1.5, 1.0], false, 4.85, 0.85, 10, "Navigate between fields; inside speed 45%, inputs remain active.", {"radius": 78.0, "tell": 0.85, "slow": 0.45, "projectile_damage": 10}),
		"event_horizon": _move(preload("res://attacks/admin/EventHorizon.gd"), "Event Horizon", 3, [0.0, 0.0, 2.8, 2.5], true, 6.10, 1.45, 32, "Get into blue 160 px wide moving safe band, then track its expansion.", {"safe_radius": 170.0, "safe_width": 160.0, "growth": 40.0, "tell": 1.45, "damage": 32, "projectile_damage": 10}),
		"collapse": _move(preload("res://attacks/admin/Collapse.gd"), "Collapse", 3, [0.0, 0.0, 2.3, 2.6], true, 5.15, 1.25, 32, "Leave selected quadrants; 96 px wide center paths connect safe space.", {"corridor": 96.0, "tell": 1.25, "active": 3.45, "damage": 32, "projectile_damage": 10})
	}
	combos = [
		{"primary": "gravity_well", "secondary": "orbital_projectiles", "min_phase": 2, "delay": 0.80, "chance": 0.35},
		{"primary": "admin_delete", "secondary": "singularity_dash", "min_phase": 4, "delay": 0.45, "chance": 0.50}
	]

func _move(script: Script, name: String, first_phase: int, weights: Array, major: bool, seconds: float, tell: float, damage: int, response: String, values: Dictionary) -> Dictionary:
	return {"script": script, "name": name, "min_phase": first_phase, "weight": weights[first_phase - 1], "phase_weights": weights, "major": major, "duration": seconds, "tell": tell, "damage": damage, "response": response, "params": values}
