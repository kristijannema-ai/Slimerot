extends BLProfile

func _init() -> void:
	id = "sand"
	display_name = "Sand Router"
	subtitle = "Read the blue route; redirect before the desert closes"
	arena_color = Color("493927")
	accent = Color("efd379")
	max_hp = 19500.0
	phase_thresholds = [0.70, 0.35]
	attacks = {
		"sand_fan": {"script":preload("res://attacks/sand/SandFan.gd"), "min_phase":1,
			"weight":3.0, "phase_weights":[3.0,2.5,2.0], "major":false, "duration":4.45,
			"tell":0.50, "damage":12, "response":"The second five-shot fan offsets between the first spokes; weave instead of circling blindly.", "params":{}},
		"sand_wall": {"script":preload("res://attacks/sand/SandWall.gd"), "min_phase":1,
			"weight":3.0, "phase_weights":[3.0,3.0,3.0], "major":true, "duration":6.65,
			"tell":0.90, "damage":23, "response":"Cross through a visible blue gap. From phase 2 track the reflected sideways drift.", "params":{}},
		"quicksand_nodes": {"script":preload("res://attacks/sand/QuicksandNodes.gd"), "min_phase":1,
			"weight":2.0, "phase_weights":[2.0,2.0,1.5], "major":false, "duration":4.80,
			"tell":0.65, "damage":12, "response":"Purple nodes slow to 65%; steer around them or Dash out, then weave the light fan. They never disable controls.", "params":{}},
		"route_recalculation": {"script":preload("res://attacks/sand/RouteRecalculation.gd"), "min_phase":2,
			"weight":2.5, "phase_weights":[0.0,2.5,3.0], "major":true, "duration":2.95,
			"tell":0.95, "damage":20, "response":"Identify the one blue vertical route before orange routes ignite. At most one route-width relocation.", "params":{}},
		"mirage_routers": {"script":preload("res://attacks/sand/MirageRouters.gd"), "min_phase":2,
			"weight":2.0, "phase_weights":[0.0,2.0,2.5], "major":false, "duration":4.90,
			"tell":0.55, "damage":12, "response":"Only the copy with a blue ground rune fires. Purple decoy tells are harmless.", "params":{}},
		"sand_collapse": {"script":preload("res://attacks/sand/SandCollapse.gd"), "min_phase":3,
			"weight":2.5, "phase_weights":[0.0,0.0,2.5], "major":true, "duration":6.35,
			"tell":1.10, "damage":30, "response":"Move inward as orange edge bands advance. A broad center survives while two light fans fire.", "params":{}}
	}
	combos = [
		{"primary":"sand_wall", "secondary":"sand_fan", "min_phase":2, "delay":1.20, "secondary_params":{"light":true}}
	]
