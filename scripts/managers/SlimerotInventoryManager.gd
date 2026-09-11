extends Node

# Slimerot copy identity protects equipment and individual favorites without a capacity limit.
var inventory: Dictionary = {}
var equipped_copy_ids: Array[String] = []
var next_copy_id := 1
var discoveries: Dictionary = {}

func add_copy(slime_id: String, variant: String = "normal", notify: bool = true) -> String:
	if SlimeDatabase.get_slime(slime_id) == null or variant not in SlimerotBalance.VARIANTS:
		return ""
	var key := slime_id + ":" + variant
	if not inventory.has(key):
		inventory[key] = {"slime_id": slime_id, "variant": variant, "quantity": 0, "favorite": false, "copy_ids": [], "favorite_copy_ids": []}
	var copy_id := "slimerot_copy_%d" % next_copy_id
	next_copy_id += 1
	inventory[key].copy_ids.append(copy_id)
	inventory[key].quantity = inventory[key].copy_ids.size()
	if inventory[key].favorite:
		inventory[key].favorite_copy_ids.append(copy_id)
	if not discoveries.has(slime_id):
		discoveries[slime_id] = []
	if variant not in discoveries[slime_id]:
		discoveries[slime_id].append(variant)
	if notify:
		GameState.changed.emit()
	return copy_id

func pair_for_copy(copy_id: String) -> Dictionary:
	for pair in inventory.values():
		if copy_id in pair.copy_ids:
			return pair
	return {}

func equip(copy_id: String) -> bool:
	if pair_for_copy(copy_id).is_empty() or copy_id in equipped_copy_ids:
		return false
	if equipped_copy_ids.size() >= SkillTreeManager.derived_stats().equipped_slots:
		return false
	equipped_copy_ids.append(copy_id)
	notify_change("team_change")
	return true

func unequip(copy_id: String) -> void:
	equipped_copy_ids.erase(copy_id)
	notify_change("team_change")

func auto_equip_strongest() -> void:
	var copies: Array[String] = []
	for pair in inventory.values():
		copies.append_array(pair.copy_ids)
	copies.sort_custom(func(a, b):
		var a_damage := damage_for_copy(a)
		var b_damage := damage_for_copy(b)
		return a.naturalnocasecmp_to(b) < 0 if is_equal_approx(a_damage, b_damage) else a_damage > b_damage)
	equipped_copy_ids.assign(copies.slice(0, SkillTreeManager.derived_stats().equipped_slots))
	notify_change("team_change")

func toggle_favorite(key: String) -> void:
	if inventory.has(key):
		var pair: Dictionary = inventory[key]
		pair.favorite = not pair.favorite
		pair.favorite_copy_ids = pair.copy_ids.duplicate() if pair.favorite else []
		notify_change("favorite_change")

func toggle_copy_favorite(copy_id: String) -> void:
	var pair := pair_for_copy(copy_id)
	if pair.is_empty():
		return
	if copy_id in pair.favorite_copy_ids:
		pair.favorite_copy_ids.erase(copy_id)
		pair.favorite = false
	else:
		pair.favorite_copy_ids.append(copy_id)
	notify_change("favorite_change")

func is_protected(copy_id: String) -> bool:
	var pair := pair_for_copy(copy_id)
	return pair.is_empty() or copy_id in equipped_copy_ids or pair.favorite or copy_id in pair.favorite_copy_ids

func sell_value(key: String) -> int:
	var pair: Dictionary = inventory[key]
	return roundi(SlimeDatabase.get_slime(pair.slime_id).base_sell * SlimerotBalance.VARIANT_DATA[pair.variant].sell * (1.0 + SkillTreeManager.derived_stats().duplicate_dealer))

func sell_copy(copy_id: String) -> int:
	if not GameState.structure_unlocked_flags.get("sell_terminal", false) or is_protected(copy_id):
		return 0
	var pair := pair_for_copy(copy_id)
	var value := sell_value(pair.slime_id + ":" + pair.variant)
	pair.copy_ids.erase(copy_id)
	pair.quantity = pair.copy_ids.size()
	GameState.award_coins(value)
	notify_change("sale")
	return value

func sell_duplicates() -> int:
	if not GameState.structure_unlocked_flags.get("sell_terminal", false):
		return 0
	var earned := 0
	for key in inventory:
		var pair: Dictionary = inventory[key]
		var remaining: Array = []
		for copy_id in pair.copy_ids:
			if is_protected(copy_id):
				remaining.append(copy_id)
		for copy_id in pair.copy_ids:
			if copy_id in remaining:
				continue
			if remaining.is_empty():
				remaining.append(copy_id)
			else:
				earned += sell_value(key)
		pair.copy_ids = remaining
		pair.quantity = remaining.size()
	GameState.award_coins(earned)
	notify_change("sell_duplicates")
	return earned

func auto_sell_thresholds(node_ids: Variant = null, discovered: Variant = null) -> Array[int]:
	var stats := SkillTreeManager.derived_stats(node_ids)
	var available: Array[int] = [SlimerotRollTree.DEFAULT_SELL_THRESHOLD]
	if stats.filter_1: available.assign(SlimerotRollTree.FILTER_I_THRESHOLDS)
	var history: Dictionary = discoveries if discovered == null else discovered
	if stats.filter_2:
		for id in history:
			var slime := SlimeDatabase.get_slime(id)
			if slime != null and slime.rarity_threshold not in available:
				available.append(slime.rarity_threshold)
	available.sort()
	return available

func set_auto_sell(enabled: bool) -> bool:
	if not SkillTreeManager.derived_stats().auto_sell: return false
	GameState.settings.auto_sell_settings.enabled = enabled
	GameState.changed.emit()
	GameState.critical_change.emit("settings")
	return true

func set_auto_sell_threshold(threshold: int) -> bool:
	if threshold not in auto_sell_thresholds(): return false
	if not SkillTreeManager.derived_stats().auto_sell: return false
	GameState.settings.auto_sell_settings.threshold = threshold
	GameState.changed.emit()
	GameState.critical_change.emit("settings")
	return true

func auto_sell_roll(copy_id: String) -> int:
	# Only the newly committed copy is considered. No retroactive inventory sweep.
	if not SkillTreeManager.derived_stats().auto_sell or not GameState.settings.auto_sell_settings.enabled:
		return 0
	var pair := pair_for_copy(copy_id)
	if pair.is_empty() or pair.variant != "normal" or pair.quantity <= 1 or is_protected(copy_id):
		return 0
	var threshold := int(GameState.settings.auto_sell_settings.threshold)
	if threshold not in auto_sell_thresholds(): threshold = SlimerotRollTree.DEFAULT_SELL_THRESHOLD
	if SlimeDatabase.get_slime(pair.slime_id).rarity_threshold > threshold: return 0
	var value := sell_value(pair.slime_id + ":normal")
	pair.copy_ids.erase(copy_id)
	pair.quantity = pair.copy_ids.size()
	GameState.award_coins(value, false)
	return value

func damage_for_pair(pair: Dictionary, boss: bool = false) -> float:
	var stats := SkillTreeManager.derived_stats()
	return roundf(SlimeDatabase.get_slime(pair.slime_id).base_damage * SlimerotBalance.VARIANT_DATA[pair.variant].damage * stats.damage_multiplier * (1.0 + stats.boss_damage_bonus if boss else 1.0))

func damage_for_copy(copy_id: String, boss: bool = false) -> float:
	var pair := pair_for_copy(copy_id)
	return 0.0 if pair.is_empty() else damage_for_pair(pair, boss)

func team_dps() -> float:
	var damage := 0.0
	for copy_id in equipped_copy_ids:
		damage += damage_for_copy(copy_id)
	return damage / SkillTreeManager.derived_stats().attack_interval

func best_variant_owned(slime_id: String) -> String:
	for variant in ["golden", "glitched", "shiny", "normal"]:
		if inventory.get(slime_id + ":" + variant, {}).get("quantity", 0) > 0:
			return variant
	return ""

func collection() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for row in SlimerotRoster.ROWS:
		entries.append({"slime": SlimeDatabase.get_slime(row[0]), "discovered": discoveries.has(row[0]), "best_variant": best_variant_owned(row[0])})
	return entries

func sorted_pairs(order: String) -> Array:
	var pairs: Array = inventory.values().filter(func(pair): return pair.quantity > 0)
	pairs.sort_custom(func(a, b):
		var first := SlimeDatabase.get_slime(a.slime_id)
		var second := SlimeDatabase.get_slime(b.slime_id)
		if order == "Name" and first.display_name != second.display_name:
			return first.display_name < second.display_name
		if order == "Rarity" and first.rarity_threshold != second.rarity_threshold:
			return first.rarity_threshold > second.rarity_threshold
		if order == "DPS" and damage_for_pair(a) != damage_for_pair(b):
			return damage_for_pair(a) > damage_for_pair(b)
		return (a.slime_id + a.variant) < (b.slime_id + b.variant))
	return pairs

func notify_change(reason: String) -> void:
	GameState.best_team_dps = maxf(GameState.best_team_dps, team_dps())
	GameState.changed.emit()
	GameState.critical_change.emit(reason)

func reset() -> void:
	inventory.clear()
	equipped_copy_ids.clear()
	discoveries.clear()
	next_copy_id = 1
