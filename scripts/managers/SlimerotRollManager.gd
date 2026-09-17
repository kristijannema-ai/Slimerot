extends Node

signal revealed(slime_id: String, variant: String, first_roll: bool)
signal result_committed(result: Dictionary)
signal reveal_finished
var cooldown_remaining := 0.0
var completing := false
var rng := RandomNumberGenerator.new()
var variant_rng := RandomNumberGenerator.new()
var presentation := SlimerotRollRevealQueue.new()
var reveal_remaining: float:
	get: return presentation.remaining
var reveal_queue: Array[Dictionary]:
	get: return presentation.pending
var active_reveal: Dictionary:
	get: return presentation.active
var last_result: Dictionary = {}
var offline_completed_count := 0
var _offline_state: Dictionary = {}
var _offline_stacks: Dictionary = {}
var _offline_first: Dictionary = {}
var _generation := 0
var _pending: SlimerotRollResult
var _pity_cache_key: Array = []
var _pity_cache: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	variant_rng.randomize()
	presentation.started.connect(func(result): revealed.emit(result.slime_id, result.variant, result.get("first_roll", false)))
	presentation.finished.connect(func(): reveal_finished.emit())

func _process(delta: float) -> void:
	if GameState.is_paused(): return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	presentation.advance(delta)
	if GameState.settings.auto_roll_state and SkillTreeManager.derived_stats().auto_roll: request_roll()

func zone_luck_multiplier() -> int:
	# Gameplay zones unlock contiguously. Bedroom Hub never counts.
	return clampi(GameState.highest_zone_unlocked, 1, SlimerotBalance.MAX_ZONE)

func effective_luck(single_roll_multiplier: float = 1.0) -> float:
	return get_effective_luck({"super_roll_multiplier": single_roll_multiplier})

func rolling_luck(single_roll_multiplier: float = 1.0) -> float:
	return get_effective_luck({"super_roll_multiplier": single_roll_multiplier, "apply_cap": true})

func get_luck_breakdown(context: Dictionary = {}) -> Dictionary:
	var stats := SkillTreeManager.derived_stats(context.get("node_ids", null))
	var parts := {"minor_roll_tree_product": float(stats.minor_roll_tree_product),
		"breakthrough_product": float(stats.breakthrough_product),
		"zone_luck_multiplier": float(clampi(int(context.get("highest_zone_unlocked", GameState.highest_zone_unlocked)), 1, SlimerotBalance.MAX_ZONE)),
		"coin_tree_luck_product": float(stats.coin_tree_luck_product),
		"active_potion_multiplier": float(context.get("active_potion_multiplier", GameState.active_potion_multiplier)),
		"super_roll_multiplier": float(context.get("super_roll_multiplier", 1.0))}
	var base: float = parts.minor_roll_tree_product * parts.breakthrough_product * parts.zone_luck_multiplier * parts.coin_tree_luck_product * parts.active_potion_multiplier
	parts.total = base * parts.super_roll_multiplier
	var cap := float(context.get("luck_cap", GameState.settings.luck_cap))
	if stats.breakthrough_count > 0 and cap in SlimerotBalance.LUCK_CAPS.values() and cap > 0.0: base = minf(base, cap)
	parts.capped_total = base * parts.super_roll_multiplier
	return parts

func get_effective_luck(context: Dictionary = {}) -> float:
	var breakdown := get_luck_breakdown(context)
	return breakdown.capped_total if context.get("apply_cap", false) else breakdown.total

func super_schedule_initial(lifetime: int, interval: int = 100) -> int:
	return SlimerotSuperRoll.initial(lifetime, interval)

func update_super_roll_schedule(previous_tier: int) -> void:
	var stats := SkillTreeManager.derived_stats()
	if not stats.super_roll:
		GameState.super_roll_next_trigger = 0
	elif previous_tier == 0:
		GameState.super_roll_next_trigger = SlimerotSuperRoll.initial(GameState.lifetime_rolls, stats.super_roll_interval)
	elif stats.super_roll_tier > previous_tier:
		GameState.super_roll_next_trigger = SlimerotSuperRoll.upgrade(GameState.lifetime_rolls, GameState.super_roll_next_trigger, stats.super_roll_interval)

func current_super_trigger(state: Dictionary, stats: Dictionary) -> int:
	if not stats.super_roll: return 0
	var trigger := int(state.super_roll_next_trigger)
	if trigger == 0 and int(state.lifetime_rolls) > SlimerotSaveFormat.MAX_EXACT_INTEGER - int(stats.super_roll_interval): return 0
	# Migration initializes old profiles. This fallback also supports dev fixtures
	# with directly assigned nodes; normal gameplay always persists a future target.
	return trigger if trigger > int(state.lifetime_rolls) else SlimerotSuperRoll.initial(int(state.lifetime_rolls), stats.super_roll_interval)

func next_roll_multiplier() -> float:
	var stats := SkillTreeManager.derived_stats()
	var state := roll_state()
	if SlimerotSuperRoll.due(state.lifetime_rolls, current_super_trigger(state, stats)): return stats.super_roll_multiplier
	return 1.0

func rolls_until_super() -> int:
	var state := roll_state()
	var trigger := current_super_trigger(state, SkillTreeManager.derived_stats())
	return maxi(0, trigger - int(state.lifetime_rolls)) if trigger > 0 else 0

func set_luck_cap(cap: float) -> bool:
	if cap not in SlimerotBalance.LUCK_CAPS.values() or SkillTreeManager.derived_stats().breakthrough_count == 0: return false
	GameState.settings.luck_cap = cap
	GameState.changed.emit()
	GameState.critical_change.emit("settings")
	return true

func select_base(luck: float, uniform: float, _highest_zone: int = 1) -> String:
	assert(uniform > 0.0 and uniform <= 1.0)
	var selected := SlimerotBalance.FIRST_SLIME
	for slime in SlimeDatabase.eligible():
		if slime.rarity_threshold <= luck / uniform: selected = slime.id
	return selected

func variant_probabilities(variant_sense: bool = false) -> Array[float]:
	var probabilities: Array[float] = []
	var modifier := SlimerotBalance.VARIANT_SENSE_MULTIPLIER if variant_sense else 1.0
	for flag in SlimerotVariants.FLAGS:
		probabilities.append(SlimerotVariants.probability(flag, InventoryManager.shrine_count(flag), modifier))
	return probabilities

func select_variant_flags(uniforms: Array, probabilities: Array[float]) -> int:
	assert(uniforms.size() == 3 and probabilities.size() == 3)
	var flags := 0
	for index in 3:
		assert(float(uniforms[index]) >= 0.0 and float(uniforms[index]) < 1.0)
		if float(uniforms[index]) < probabilities[index]: flags |= 1 << index
	return flags

func select_variant(uniform: float, variant_sense: bool = false) -> String:
	# Legacy diagnostic maps one uniform through the joint distribution.
	# Actual rolls sample three independent uniforms below.
	assert(uniform >= 0.0 and uniform < 1.0)
	var probabilities := variant_probabilities(variant_sense)
	var cumulative := 0.0
	for flags in 8:
		var mass := 1.0
		for index in 3: mass *= probabilities[index] if flags & (1 << index) else 1.0 - probabilities[index]
		cumulative += mass
		if uniform < cumulative: return SlimerotVariants.key(flags)
	return SlimerotVariants.key(7)

func pity_distribution(luck: float, probabilities: Array[float], best: int = -1) -> Dictionary:
	if best < 0: best = GameState.best_ever_effective_rarity
	var cache_key: Array = [luck, best, probabilities]
	if cache_key != _pity_cache_key:
		_pity_cache_key = cache_key.duplicate(true)
		_pity_cache = SlimerotPity.distribution(SlimeDatabase.eligible(), luck, probabilities, best)
	return _pity_cache

func resolve_roll() -> SlimerotRollResult:
	if _pending != null: return _pending
	var state := roll_state()
	if state.lifetime_rolls >= SlimerotSaveFormat.MAX_EXACT_INTEGER or InventoryManager.next_copy_id >= SlimerotSaveFormat.MAX_EXACT_INTEGER: return null
	var result := SlimerotRollResult.new()
	result.expected_lifetime = state.lifetime_rolls
	result.generation = _generation
	var first: bool = state.lifetime_rolls == 0
	var multiplier := next_roll_multiplier()
	var luck_used := rolling_luck(multiplier)
	var probabilities := variant_probabilities(SkillTreeManager.derived_stats().variant_sense)
	var uniform := (float(rng.randi()) + 1.0) / SlimerotPity.UNIFORM_STEPS
	var selected := SlimerotBalance.FIRST_SLIME if first else select_base(luck_used, uniform)
	var uniforms: Array = []
	for index in 3: uniforms.append(float(variant_rng.randi()) / SlimerotPity.UNIFORM_STEPS)
	var flags := select_variant_flags(uniforms, probabilities)
	var best: int = state.best_ever_effective_rarity
	var rarity := SlimeDatabase.get_effective_rarity(selected, flags)
	var assisted := false
	var forced := false
	if not first and rarity <= best:
		var distribution := pity_distribution(luck_used, probabilities, best)
		if distribution.p_better > 0.0:
			var next_miss: int = state.rolls_since_last_power_improvement + 1
			forced = next_miss >= int(distribution.guarantee_roll)
			var chance := SlimerotPity.assist_chance(next_miss, distribution.expected_rolls)
			if forced or (chance > 0.0 and float(rng.randi()) / SlimerotPity.UNIFORM_STEPS < chance):
				var outcome := SlimerotPity.select_stronger(distribution, float(rng.randi()) / SlimerotPity.UNIFORM_STEPS)
				selected = outcome.slime_id
				flags = outcome.variant_flags
				rarity = SlimeDatabase.get_effective_rarity(selected, flags)
				assisted = true
	var weakest := INF
	for copy_id in InventoryManager.equipped_copy_ids: weakest = minf(weakest, InventoryManager.damage_for_copy(copy_id))
	var variant := SlimerotVariants.key(flags)
	var raw_damage := SlimeDatabase.get_base_combat_damage(selected, flags)
	result.data = {"slime_id": selected, "variant": variant, "variant_flags": flags, "first_roll": first,
		"first_discovery": not state.discoveries.has(selected), "variant_discovery": variant not in state.discoveries.get(selected, []),
		"threshold": SlimeDatabase.get_slime(selected).rarity_threshold, "effective_rarity": rarity, "base_damage": raw_damage,
		"damage": roundf(raw_damage * SkillTreeManager.derived_stats().damage_multiplier),
		"weakest_equipped_damage": weakest if is_finite(weakest) else 0.0,
		"team_has_space": InventoryManager.equipped_copy_ids.size() < SkillTreeManager.derived_stats().equipped_slots,
		"power_improvement": rarity > best, "luck_used": luck_used, "effective_luck": effective_luck(multiplier),
		"super_roll": multiplier > 1.0, "super_roll_multiplier": multiplier,
		"super_roll_interval": SkillTreeManager.derived_stats().super_roll_interval,
		"super_roll_next_trigger": current_super_trigger(state, SkillTreeManager.derived_stats()),
		"pity_assisted": assisted, "hard_pity": forced}
	_pending = result
	return result

func roll_state() -> Dictionary:
	if not _offline_state.is_empty(): return _offline_state
	return {"rolls_balance": GameState.rolls_balance, "lifetime_rolls": GameState.lifetime_rolls,
		"super_roll_next_trigger": GameState.super_roll_next_trigger,
		"best_ever_effective_rarity": GameState.best_ever_effective_rarity, "rolls_since_last_power_improvement": GameState.rolls_since_last_power_improvement,
		"rarest_threshold_reached": GameState.rarest_threshold_reached, "highest_luck": GameState.highest_luck, "discoveries": InventoryManager.discoveries}

func apply_roll_state(state: Dictionary) -> void:
	GameState.rolls_balance = state.rolls_balance
	GameState.lifetime_rolls = state.lifetime_rolls
	GameState.super_roll_next_trigger = state.super_roll_next_trigger
	GameState.best_ever_effective_rarity = state.best_ever_effective_rarity
	GameState.rolls_since_last_power_improvement = state.rolls_since_last_power_improvement
	GameState.rarest_threshold_reached = state.rarest_threshold_reached
	GameState.highest_luck = state.highest_luck
	GameState.best_team_dps = maxf(GameState.best_team_dps, InventoryManager.team_dps())

func commit_roll(result: SlimerotRollResult, offline: bool = false) -> bool:
	var state := roll_state()
	if offline != (not _offline_state.is_empty()): return false
	# One issued object, one generation, one sequence. Pending AFK commits belong
	# to the isolated transaction until its whole batch can be published atomically.
	if result == null or result != _pending or result.committed or result.generation != _generation or result.expected_lifetime != int(state.lifetime_rolls): return false
	var data := result.data
	var copy_id := ""
	var sold := 0
	if offline:
		var key: String = data.slime_id + ":" + data.variant
		if not _offline_stacks.has(key): _offline_stacks[key] = {"slime_id": data.slime_id, "variant": data.variant, "quantity": 0}
		_offline_stacks[key].quantity += 1
		if data.first_roll: _offline_first = {"slime_id": data.slime_id, "variant": data.variant, "key": key}
		if not state.discoveries.has(data.slime_id): state.discoveries[data.slime_id] = []
		if data.variant not in state.discoveries[data.slime_id]: state.discoveries[data.slime_id].append(data.variant)
	else:
		copy_id = InventoryManager.add_copy(data.slime_id, data.variant_flags, false)
		if copy_id.is_empty(): return false
		if data.first_roll: InventoryManager.equipped_copy_ids.assign([copy_id])
		sold = InventoryManager.auto_sell_roll(copy_id)
	# The sole reward-counter operation for manual, Auto AND simulated rolls.
	state.rolls_balance += 1
	state.lifetime_rolls += 1
	state.super_roll_next_trigger = SlimerotSuperRoll.after_trigger(state.lifetime_rolls, data.super_roll_interval) if data.super_roll else data.super_roll_next_trigger
	if data.power_improvement:
		state.best_ever_effective_rarity = maxi(state.best_ever_effective_rarity, int(data.effective_rarity))
		state.rolls_since_last_power_improvement = 0
	else: state.rolls_since_last_power_improvement += 1
	state.rarest_threshold_reached = maxi(state.rarest_threshold_reached, data.threshold)
	state.highest_luck = maxf(state.highest_luck, data.effective_luck)
	result.committed = true
	data.copy_id = copy_id
	data.lifetime_roll = state.lifetime_rolls
	data.auto_sold_coins = sold
	_pending = null
	if not offline:
		apply_roll_state(state)
		last_result = data.duplicate(true)
		cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown
		GameState.changed.emit()
		if data.first_roll or data.power_improvement or data.variant_flags != 0 or data.threshold >= 10000 or data.super_roll or sold > 0: GameState.critical_change.emit("first_or_rare_roll")
		result_committed.emit(last_result.duplicate(true))
	return true

func request_roll() -> bool:
	if completing or cooldown_remaining > 0.0 or GameState.is_paused() or GameState.player_dead: return false
	completing = true
	var result := resolve_roll()
	var committed := commit_roll(result)
	if committed: queue_reveal(result.data)
	completing = false
	return committed

func process_offline_rolls(count: int) -> Dictionary:
	var summary := {"rolls": 0, "rolls_earned": 0, "new_discoveries": [], "new_variant_discoveries": [], "best_drop": {}, "auto_sold_coins": 0}
	if count <= 0 or completing or _pending != null or count > SlimerotSaveFormat.MAX_EXACT_INTEGER - GameState.lifetime_rolls or count > SlimerotSaveFormat.MAX_EXACT_INTEGER - InventoryManager.next_copy_id: return summary
	_offline_state = roll_state().duplicate(true)
	_offline_stacks.clear()
	_offline_first.clear()
	completing = true
	offline_completed_count = 0
	var best_rarity := -1
	var slice_started := Time.get_ticks_usec()
	# SaveManager owns the durable checkpoint and blocks writes/input until the
	# rewards and consumed timestamp finish the existing offline transaction.
	for index in count:
		var result := resolve_roll()
		if not commit_roll(result, true): break
		var data := result.data
		if data.first_discovery: summary.new_discoveries.append(data.slime_id)
		if data.variant_discovery: summary.new_variant_discoveries.append({"slime_id": data.slime_id, "variant_flags": data.variant_flags, "variant": data.variant})
		if data.effective_rarity > best_rarity:
			best_rarity = data.effective_rarity
			summary.best_drop = {"slime_id": data.slime_id, "variant": data.variant, "variant_flags": data.variant_flags, "threshold": data.threshold, "effective_rarity": data.effective_rarity, "base_damage": data.base_damage}
		summary.auto_sold_coins += data.auto_sold_coins
		summary.rolls += 1
		summary.rolls_earned += 1
		offline_completed_count = index + 1
		if (index + 1) % SlimerotBalance.OFFLINE_SLICE_ROLLS == 0 and Time.get_ticks_usec() - slice_started >= SlimerotBalance.OFFLINE_SLICE_MICROSECONDS:
			await get_tree().process_frame
			slice_started = Time.get_ticks_usec()
	if summary.rolls == count:
		# Materialize stack quantities once. Currency/pity have already been
		# committed exactly once per result in the isolated state above.
		InventoryManager.discoveries = _offline_state.discoveries.duplicate(true)
		if not _offline_first.is_empty():
			var starter := InventoryManager.add_copy(_offline_first.slime_id, _offline_first.variant, false)
			InventoryManager.equipped_copy_ids.assign([starter])
			_offline_stacks[_offline_first.key].quantity -= 1
		for stack in _offline_stacks.values():
			if stack.quantity <= 0: continue
			var added := InventoryManager.add_copies(stack.slime_id, stack.variant, stack.quantity, false, true)
			summary.auto_sold_coins += int(added.coins)
		apply_roll_state(_offline_state)
	else:
		summary = {"rolls": 0, "rolls_earned": 0}
	_offline_state.clear()
	_offline_stacks.clear()
	_offline_first.clear()
	_pending = null
	completing = false
	return summary

func reveal_duration(threshold: int, first_discovery: bool) -> float:
	return SlimerotPresentation.reveal_duration(threshold, first_discovery, SkillTreeManager.derived_stats().skip_common)

func queue_reveal(result: Dictionary) -> void:
	presentation.enqueue(result)

func start_reveal(result: Dictionary) -> void:
	presentation.start(result)

func skip_reveal() -> bool:
	return presentation.skip()

func finish_reveal() -> void:
	presentation.finish()
	presentation.advance(0.0)

func reset() -> void:
	cooldown_remaining = 0.0
	completing = false
	_offline_state.clear()
	_offline_stacks.clear()
	_offline_first.clear()
	_generation += 1
	_pending = null
	_pity_cache_key.clear()
	_pity_cache.clear()
	last_result.clear()
	presentation.clear()
