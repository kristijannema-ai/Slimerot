class_name BLProfile
extends Resource

@export var id := ""
@export var display_name := ""
@export var subtitle := ""
@export var arena_color := Color("382d33")
@export var accent := Color("f5b764")
@export var max_hp := 18000.0
@export var phase_thresholds: Array[float] = [0.70, 0.35]
@export var phase_recovery: Array[float] = [0.45, 0.32, 0.22]
var attacks: Dictionary = {}
var combos: Array[Dictionary] = []
@export var phase_arena_insets: Dictionary = {}
@export var attack_overrides: Dictionary = {}

func phase_for(fraction: float) -> int:
	var result := 1
	for threshold in phase_thresholds:
		if fraction <= threshold: result += 1
	return result

