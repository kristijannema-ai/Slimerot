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
var offline_completed_count := 0

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
	# Manual and offline completions share exactly the same currency grant.
	grant_completed_rolls(1)
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

func grant_completed_rolls(count: int) -> void:
	GameState.rolls_balance += count
	GameState.lifetime_rolls += count

func process_offline_rolls(count: int) -> Dictionary:
	var summary := {"rolls": 0, "rolls_earned": 0, "new_discoveries": [], "best_drop": {}, "auto_sold_coins": 0}
	if count <= 0 or completing or count > SlimerotSaveFormat.MAX_EXACT_INTEGER - GameState.lifetime_rolls or count > SlimerotSaveFormat.MAX_EXACT_INTEGER - InventoryManager.next_copy_id:
		return summary
	completing = true
	offline_completed_count = 0
	var stats := SkillTreeManager.derived_stats()
	var luck := rolling_luck()
	var uncapped_luck := effective_luck()
	var pool := SlimeDatabase.eligible(GameState.highest_zone_unlocked)
	var stacks: Dictionary = {}
	var discovered: Dictionary = {}
	var best_power := -1.0
	var strongest_luck := uncapped_luck
	var first_result: Dictionary = {}
	var starting_rolls := GameState.lifetime_rolls
	var slice_started := Time.get_ticks_usec()
	# Sampling is data-only. Inventory, currency and discovery commit together below;
	# a process kill during sampling leaves the previous checkpoint authoritative.
	for index in count:
		var multiplier: float = SlimerotRollTree.SUPER_ROLL_MULTIPLIER if stats.super_roll and (starting_rolls + index + 1) % SlimerotRollTree.SUPER_ROLL_INTERVAL == 0 else 1.0
		var uniform := (float(rng.randi()) + 1.0) / 4294967296.0
		var score := luck * multiplier / uniform
		var selected := SlimerotBalance.FIRST_SLIME
		if starting_rolls + index > 0:
			for slime in pool:
				if slime.rarity_threshold <= score: selected = slime.id
		var variant := select_variant(float(variant_rng.randi()) / 4294967296.0, stats.variant_sense)
		var key := selected + ":" + variant
		if not stacks.has(key): stacks[key] = {"slime_id": selected, "variant": variant, "quantity": 0}
		stacks[key].quantity += 1
		if not InventoryManager.discoveries.has(selected): discovered[selected] = true
		var data := SlimeDatabase.get_slime(selected)
		var power: float = data.base_damage * SlimerotBalance.VARIANT_DATA[variant].damage
		if power > best_power:
			best_power = power
			summary.best_drop = {"slime_id": selected, "variant": variant, "threshold": data.rarity_threshold}
		strongest_luck = maxf(strongest_luck, uncapped_luck * multiplier)
		if starting_rolls == 0 and index == 0: first_result = {"slime_id": selected, "variant": variant, "key": key}
		offline_completed_count = index + 1
		if (index + 1) % SlimerotBalance.OFFLINE_SLICE_ROLLS == 0 and Time.get_ticks_usec() - slice_started >= SlimerotBalance.OFFLINE_SLICE_MICROSECONDS:
			await get_tree().process_frame
			slice_started = Time.get_ticks_usec()
	# Discover all sampled bases before applying discovered-threshold sale filters.
	for stack in stacks.values():
		if not InventoryManager.discoveries.has(stack.slime_id): InventoryManager.discoveries[stack.slime_id] = []
		if stack.variant not in InventoryManager.discoveries[stack.slime_id]: InventoryManager.discoveries[stack.slime_id].append(stack.variant)
	if not first_result.is_empty():
		var starter := InventoryManager.add_copy(first_result.slime_id, first_result.variant, false)
		InventoryManager.equipped_copy_ids.assign([starter])
		stacks[first_result.key].quantity -= 1
	for stack in stacks.values():
		if stack.quantity <= 0: continue
		var added: Dictionary = InventoryManager.add_copies(stack.slime_id, stack.variant, stack.quantity, false, true)
		summary.auto_sold_coins += int(added.coins)
		GameState.rarest_threshold_reached = maxi(GameState.rarest_threshold_reached, SlimeDatabase.get_slime(stack.slime_id).rarity_threshold)
	grant_completed_rolls(count)
	GameState.highest_luck = maxf(GameState.highest_luck, strongest_luck)
	GameState.rarest_threshold_reached = maxi(GameState.rarest_threshold_reached, int(summary.best_drop.get("threshold", 0)))
	GameState.best_team_dps = maxf(GameState.best_team_dps, InventoryManager.team_dps())
	summary.rolls = count
	summary.rolls_earned = count
	summary.new_discoveries.assign(discovered.keys())
	# No reveal queue, per-copy signals, projectiles or active potion clock updates.
	completing = false
	return summary

func reveal_duration(threshold: int, first_discovery: bool) -> float:
	return SlimerotPresentation.reveal_duration(threshold, first_discovery, SkillTreeManager.derived_stats().skip_common)

func queue_reveal(result: Dictionary) -> void:
	if active_reveal.is_empty():
		start_reveal(result)
	else:
		# Feedback never shortens a tier's duration when a faster roll completes.
		# Explicit skipping advances this queue; rolling/combat continue independently.
		# At late-game luck, coalesce pending repeats to bound mobile memory/latency.
		if not result.first_discovery:
			for index in reveal_queue.size():
				var pending := reveal_queue[index]
				if not pending.first_discovery and pending.slime_id == result.slime_id and pending.variant == result.variant:
					reveal_queue[index] = result.duplicate()
					return
		if reveal_queue.size() >= SlimerotPresentation.MAX_PENDING_REVEALS:
			for index in reveal_queue.size():
				if not reveal_queue[index].first_discovery:
					reveal_queue.remove_at(index)
					break
		reveal_queue.append(result.duplicate())

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
