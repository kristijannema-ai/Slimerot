extends Node

signal revealed(slime_id: String, variant: String, first_roll: bool)
var cooldown_remaining := 0.0
var completing := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	if GameState.suspended:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if GameState.settings.auto_roll_state and SkillTreeManager.derived_stats().auto_roll:
		request_roll()

func request_roll() -> bool:
	if completing or cooldown_remaining > 0.0 or GameState.suspended:
		return false
	completing = true
	var first := GameState.lifetime_rolls == 0
	var selected := SlimerotBalance.FIRST_SLIME
	if not first:
		# Threshold selection is extensible; only supplied stage-one content is in the pool.
		var luck: float = SkillTreeManager.derived_stats().luck
		var score := luck / maxf(rng.randf(), 0.000000001)
		var best := 0
		for slime in SlimeDatabase.eligible(GameState.highest_zone_unlocked):
			if slime.rarity_threshold <= score and slime.rarity_threshold > best:
				selected = slime.id
				best = slime.rarity_threshold
	var copy_id := InventoryManager.add_copy(selected)
	if copy_id.is_empty():
		completing = false
		return false
	# One synchronous transaction, independent of movement and reveal animation.
	GameState.rolls_balance += 1
	GameState.lifetime_rolls += 1
	cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown
	if first:
		InventoryManager.equip(copy_id)
	GameState.changed.emit()
	revealed.emit(selected, "normal", first)
	if first or SlimeDatabase.get_slime(selected).rarity_threshold >= 10000:
		GameState.critical_change.emit("first_or_rare_roll")
	completing = false
	return true
