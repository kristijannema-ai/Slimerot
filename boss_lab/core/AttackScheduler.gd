class_name BLAttackScheduler
extends RefCounted

var previous := ""
var previous_major := ""

func reset() -> void:
	previous = ""
	previous_major = ""

func choose(profile: BLProfile, phase: int, rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for id in profile.attacks:
		var data: Dictionary = profile.attacks[id]
		if phase < int(data.min_phase) or id == previous: continue
		if data.get("major", false) and id == previous_major: continue
		var by_phase: Array = data.get("phase_weights", [])
		var weight := float(by_phase[mini(phase - 1, by_phase.size() - 1)]) if not by_phase.is_empty() else float(data.get("weight", 1.0))
		if weight <= 0.0: continue
		candidates.append(id)
		weights.append(weight)
		total += weight
	if candidates.is_empty():
		for id in profile.attacks:
			if int(profile.attacks[id].min_phase) <= phase: candidates.append(id)
		return candidates[0] if not candidates.is_empty() else ""
	var draw := rng.randf() * total
	for index in candidates.size():
		draw -= weights[index]
		if draw <= 0.0: return candidates[index]
	return candidates.back()

func remember(profile: BLProfile, id: String) -> void:
	previous = id
	previous_major = id if profile.attacks[id].get("major", false) else ""

func companion(profile: BLProfile, primary: String, phase: int, rng: RandomNumberGenerator) -> Dictionary:
	for combo in profile.combos:
		if combo.primary == primary and int(combo.get("min_phase", 2)) <= phase:
			if rng.randf() < float(combo.get("chance", 0.35)): return combo.duplicate(true)
	return {}

