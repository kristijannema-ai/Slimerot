extends Node

signal revealed(slime_id: String, variant: String, first_roll: bool)
signal result_committed(result: Dictionary)
signal reveal_finished
var cooldown_remaining := 0.0
var completing := false
var rng := RandomNumberGenerator.new()
var variant_rng := RandomNumberGenerator.new()
var reveal_remaining := 0.0
var reveal_queue: Array[Dictionary] = []
var active_reveal: Dictionary = {}
var last_result: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	variant_rng.randomize()

func _process(delta: float) -> void:
	if GameState.is_paused():
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if not active_reveal.is_empty():
		reveal_remaining = maxf(0.0, reveal_remaining - delta)
		if reveal_remaining == 0.0:
			finish_reveal()
	if GameState.settings.auto_roll_state and SkillTreeManager.derived_stats().auto_roll:
		request_roll()

func effective_luck(single_roll_multiplier: float = 1.0) -> float:
	var stats := SkillTreeManager.derived_stats()
	var luck: float = stats.luck
	if GameState.potion_remaining_seconds > 0.0:
		luck *= GameState.active_potion_multiplier
	return luck * single_roll_multiplier

func rolling_luck(single_roll_multiplier: float = 1.0) -> float:
	var luck := effective_luck()
	if SkillTreeManager.derived_stats().breakthrough_count > 0:
		var cap: float = GameState.settings.luck_cap
		if cap in SlimerotBalance.LUCK_CAPS.values() and cap > 0.0:
			luck = minf(luck, cap)
	# The cap selects persistent rolling luck; a Super Roll remains exactly ×5 in every mode.
	return luck * single_roll_multiplier

func next_roll_multiplier() -> float:
	if SkillTreeManager.derived_stats().super_roll and (GameState.lifetime_rolls + 1) % SlimerotRollTree.SUPER_ROLL_INTERVAL == 0:
		return SlimerotRollTree.SUPER_ROLL_MULTIPLIER
	return 1.0

func rolls_until_super() -> int:
	return SlimerotRollTree.SUPER_ROLL_INTERVAL - GameState.lifetime_rolls % SlimerotRollTree.SUPER_ROLL_INTERVAL

func set_luck_cap(cap: float) -> bool:
	if cap not in SlimerotBalance.LUCK_CAPS.values() or SkillTreeManager.derived_stats().breakthrough_count == 0:
		return false
	GameState.settings.luck_cap = cap
	GameState.changed.emit()
	GameState.critical_change.emit("settings")
	return true

func select_base(luck: float, uniform: float, highest_zone: int) -> String:
	assert(uniform > 0.0 and uniform <= 1.0)
	var score := luck / uniform
	var selected := SlimerotBalance.FIRST_SLIME
	for slime in SlimeDatabase.eligible(highest_zone):
		if slime.rarity_threshold <= score:
			selected = slime.id
	return selected

func select_variant(uniform: float, variant_sense: bool = false) -> String:
	assert(uniform >= 0.0 and uniform < 1.0)
	var multiplier := SlimerotBalance.VARIANT_SENSE_MULTIPLIER if variant_sense else 1.0
	var cumulative := 0.0
	# Exclusive intervals preserve each listed marginal chance.
	for variant in ["golden", "glitched", "shiny"]:
		cumulative += SlimerotBalance.VARIANT_DATA[variant].chance * multiplier
		if uniform < cumulative:
			return variant
	return "normal"

func request_roll() -> bool:
	if completing or cooldown_remaining > 0.0 or GameState.is_paused() or GameState.player_dead:
		return false
	completing = true
	var first := GameState.lifetime_rolls == 0
	var multiplier := next_roll_multiplier()
	var luck_used := rolling_luck(multiplier)
	var uncapped_luck := effective_luck(multiplier)
	# randi spans 0..2^32-1: U is strictly (0,1], with no clamped tail.
	var uniform := (float(rng.randi()) + 1.0) / 4294967296.0
	var selected := SlimerotBalance.FIRST_SLIME if first else select_base(luck_used, uniform, GameState.highest_zone_unlocked)
	var variant := select_variant(float(variant_rng.randi()) / 4294967296.0, SkillTreeManager.derived_stats().variant_sense)
	var first_discovery := not InventoryManager.discoveries.has(selected)
	var copy_id := InventoryManager.add_copy(selected, variant, false)
	if copy_id.is_empty():
		completing = false
		return false
	# This is the sole Rolls minting path. UI skipping never repeats the transaction.
	GameState.rolls_balance += 1
	GameState.lifetime_rolls += 1
	cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown
	if first:
		InventoryManager.equipped_copy_ids.assign([copy_id])
	var auto_sold_coins := InventoryManager.auto_sell_roll(copy_id)
	var slime := SlimeDatabase.get_slime(selected)
	GameState.rarest_threshold_reached = maxi(GameState.rarest_threshold_reached, slime.rarity_threshold)
	GameState.highest_luck = maxf(GameState.highest_luck, uncapped_luck)
	GameState.best_team_dps = maxf(GameState.best_team_dps, InventoryManager.team_dps())
	last_result = {"slime_id": selected, "variant": variant, "first_roll": first, "first_discovery": first_discovery,
		"threshold": slime.rarity_threshold, "copy_id": copy_id,
		"lifetime_roll": GameState.lifetime_rolls, "luck_used": luck_used, "effective_luck": uncapped_luck,
		"super_roll": multiplier > 1.0, "auto_sold_coins": auto_sold_coins}
	GameState.changed.emit()
	result_committed.emit(last_result.duplicate())
	queue_reveal(last_result)
	if first or slime.rarity_threshold >= 10000 or multiplier > 1.0 or auto_sold_coins > 0:
		GameState.critical_change.emit("first_or_rare_roll")
	completing = false
	return true

func reveal_duration(threshold: int, first_discovery: bool) -> float:
	if threshold < 100:
		return 0.20 if SkillTreeManager.derived_stats().skip_common else 0.35
	if threshold < 10000: return 0.65
	if threshold < 100000: return 1.10
	if threshold < 1000000: return 1.70
	return 2.80 if first_discovery else 1.0

func queue_reveal(result: Dictionary) -> void:
	if active_reveal.is_empty():
		start_reveal(result)
	elif active_reveal.threshold >= 1000000 and active_reveal.first_discovery:
		reveal_queue.append(result.duplicate())
	else:
		# Replace skippable visual feedback; committed ownership and currency persist.
		active_reveal.clear()
		reveal_finished.emit()
		start_reveal(result)

func start_reveal(result: Dictionary) -> void:
	active_reveal = result.duplicate()
	reveal_remaining = reveal_duration(result.threshold, result.first_discovery)
	revealed.emit(result.slime_id, result.variant, result.first_roll)

func skip_reveal() -> bool:
	if active_reveal.is_empty() or (active_reveal.threshold >= 1000000 and active_reveal.first_discovery):
		return false
	finish_reveal()
	return true

func finish_reveal() -> void:
	active_reveal.clear()
	reveal_remaining = 0.0
	reveal_finished.emit()
	if not reveal_queue.is_empty():
		start_reveal(reveal_queue.pop_front())

func reset() -> void:
	cooldown_remaining = 0.0
	completing = false
	reveal_queue.clear()
	last_result.clear()
	finish_reveal()
