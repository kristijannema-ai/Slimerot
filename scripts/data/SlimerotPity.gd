class_name SlimerotPity
extends RefCounted

const PITY_START_RATIO := 1.0
const PITY_FORCE_RATIO := 3.0
const PITY_MAX_SOFT_CHANCE := 0.25
const UNIFORM_STEPS := 4294967296.0

static func threshold_probability(luck: float, threshold: int) -> float:
	# Exact mass for the live U=(randi+1)/2^32 score sampler, including boundaries.
	return floor(minf(1.0, luck / float(threshold)) * UNIFORM_STEPS) / UNIFORM_STEPS

static func distribution(pool: Array, luck: float, chances: Array[float], best: int) -> Dictionary:
	var stronger: Array[Dictionary] = []
	var probability := 0.0
	for index in pool.size():
		var slime: SlimerotData.SlimeData = pool[index]
		var lower := 1.0 if index == 0 else threshold_probability(luck, slime.rarity_threshold)
		var upper := threshold_probability(luck, pool[index + 1].rarity_threshold) if index + 1 < pool.size() else 0.0
		var base_mass := maxf(0.0, lower - upper)
		if base_mass <= 0.0: continue
		for flags in 8:
			var rarity: int = slime.rarity_threshold * SlimerotVariants.rarity_multiplier(flags)
			if rarity <= best: continue
			var mass := base_mass
			for bit in 3:
				var p: float = ceil(chances[bit] * UNIFORM_STEPS) / UNIFORM_STEPS
				mass *= p if flags & (1 << bit) else 1.0 - p
			if mass <= 0.0: continue
			probability += mass
			stronger.append({"slime_id": slime.id, "variant_flags": flags, "mass": mass})
	return {"p_better": probability, "outcomes": stronger, "expected_rolls": 1.0 / probability if probability > 0.0 else 0.0,
		"guarantee_roll": ceili(PITY_FORCE_RATIO / probability) if probability > 0.0 else 0}

static func assist_chance(next_non_improvement: int, expected: float) -> float:
	if expected <= 0.0: return 0.0
	var progress := clampf((float(next_non_improvement) / expected - PITY_START_RATIO) / (PITY_FORCE_RATIO - PITY_START_RATIO), 0.0, 1.0)
	return progress * progress * (3.0 - 2.0 * progress) * PITY_MAX_SOFT_CHANCE

static func select_stronger(distribution_data: Dictionary, uniform: float) -> Dictionary:
	var outcomes: Array = distribution_data.outcomes
	if outcomes.is_empty(): return {}
	var target := clampf(uniform, 0.0, 1.0) * float(distribution_data.p_better)
	for outcome in outcomes:
		target -= float(outcome.mass)
		if target <= 0.0: return outcome
	return outcomes.back()
