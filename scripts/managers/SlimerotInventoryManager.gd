extends Node

# Slimerot keeps legacy copy IDs and compact inclusive serial ranges in the same stacks.
# Bulk rewards never allocate an object or a String for every owned copy.
signal team_changed
signal inventory_changed

var inventory: Dictionary = {}
var equipped_copy_ids: Array[String] = []
var next_copy_id := 1
var discoveries: Dictionary = {}
const LOOKUP_CACHE_LIMIT := 128
const COMPACT_COPY_THRESHOLD := 512
var copy_lookup_cache: Dictionary = {}

func invalidate_lookup_cache() -> void:
	copy_lookup_cache.clear()

func remember_copy(copy_id: String, key: String) -> void:
	if copy_lookup_cache.size() >= LOOKUP_CACHE_LIMIT:
		copy_lookup_cache.erase(copy_lookup_cache.keys()[0])
	copy_lookup_cache[copy_id] = key

func compact_inventory() -> void:
	# Called after validating a loaded save. Keep stable IDs while making subsequent
	# critical saves proportional to ownership ranges instead of legacy copy arrays.
	for pair in inventory.values(): compact_stack(pair)

func compact_stack(pair: Dictionary) -> void:
	if pair.copy_ids.size() >= COMPACT_COPY_THRESHOLD:
		pair.copy_ranges = merged_intervals(identity_intervals(pair))
		pair.copy_ids = []
	if pair.favorite_copy_ids.size() >= COMPACT_COPY_THRESHOLD:
		pair.favorite_copy_ranges = merged_intervals(identity_intervals(pair, true))
		pair.favorite_copy_ids = []

func add_copy(slime_id: String, variant: Variant = "normal", notify: bool = true) -> String:
	variant = SlimerotVariants.key(SlimerotVariants.mask(variant))
	if SlimeDatabase.get_slime(slime_id) == null or variant not in SlimerotBalance.VARIANTS:
		return ""
	if next_copy_id >= SlimerotSaveFormat.MAX_EXACT_INTEGER: return ""
	var key: String = slime_id + ":" + variant
	if not inventory.has(key):
		inventory[key] = {"slime_id": slime_id, "variant": variant, "variant_flags": SlimerotVariants.mask(variant), "quantity": 0, "favorite": false, "copy_ids": [], "favorite_copy_ids": []}
	var copy_id := "slimerot_copy_%d" % next_copy_id
	next_copy_id += 1
	var pair: Dictionary = inventory[key]
	if not pair.get("copy_ranges", []).is_empty(): append_range(pair.copy_ranges, next_copy_id - 1, next_copy_id - 1)
	else: pair.copy_ids.append(copy_id)
	pair.quantity += 1
	compact_stack(pair)
	remember_copy(copy_id, key)
	if not discoveries.has(slime_id):
		discoveries[slime_id] = []
	if variant not in discoveries[slime_id]:
		discoveries[slime_id].append(variant)
	record_acquisition(slime_id, variant)
	if notify:
		GameState.changed.emit()
	return copy_id

func add_copies(slime_id: String, variant: Variant, quantity: int, notify: bool = false, apply_auto_sell: bool = false) -> Dictionary:
	variant = SlimerotVariants.key(SlimerotVariants.mask(variant))
	if quantity <= 0 or SlimeDatabase.get_slime(slime_id) == null or variant not in SlimerotBalance.VARIANTS:
		return {}
	if quantity > SlimerotSaveFormat.MAX_EXACT_INTEGER - next_copy_id: return {}
	var key: String = slime_id + ":" + variant
	if not inventory.has(key):
		inventory[key] = {"slime_id": slime_id, "variant": variant, "variant_flags": SlimerotVariants.mask(variant), "quantity": 0, "favorite": false, "copy_ids": [], "favorite_copy_ids": []}
	var pair: Dictionary = inventory[key]
	var first := next_copy_id
	var last := first + quantity - 1
	if last < first: return {}
	next_copy_id = last + 1
	var kept := quantity
	var sold := 0
	if not discoveries.has(slime_id): discoveries[slime_id] = []
	if variant not in discoveries[slime_id]: discoveries[slime_id].append(variant)
	record_acquisition(slime_id, variant)
	if apply_auto_sell and auto_sell_pair_eligible(pair) and not pair.favorite:
		kept = 1 if pair.quantity == 0 else 0
		sold = quantity - kept
	if kept > 0:
		if not pair.has("copy_ranges"): pair.copy_ranges = []
		append_range(pair.copy_ranges, first, first + kept - 1)
		pair.quantity += kept
	var coins := sold * sell_value(key) if sold > 0 else 0
	if coins > 0: GameState.award_coins(coins, false)
	if notify:
		inventory_changed.emit()
		GameState.changed.emit()
	return {"first_copy_id": copy_name(first), "last_copy_id": copy_name(last), "quantity": quantity, "kept": kept, "sold": sold, "coins": coins}

func copy_name(serial: int) -> String:
	return "slimerot_copy_%d" % serial

func record_acquisition(slime_id: String, variant: Variant) -> void:
	var rarity := SlimeDatabase.get_effective_rarity(slime_id, variant)
	if rarity > GameState.best_ever_effective_rarity:
		GameState.best_ever_effective_rarity = rarity
		GameState.rolls_since_last_power_improvement = 0

func copy_serial(copy_id: Variant) -> int:
	if not copy_id is String or not copy_id.begins_with("slimerot_copy_"): return -1
	var serial: String = copy_id.trim_prefix("slimerot_copy_")
	if not serial.is_valid_int() or int(serial) <= 0 or serial != str(int(serial)): return -1
	return int(serial)

func range_contains(ranges: Array, serial: int) -> bool:
	for span in ranges:
		if serial >= int(span[0]) and serial <= int(span[1]): return true
	return false

func pair_contains_copy(pair: Dictionary, copy_id: String) -> bool:
	return copy_id in pair.get("copy_ids", []) or range_contains(pair.get("copy_ranges", []), copy_serial(copy_id))

func copy_is_favorite(pair: Dictionary, copy_id: String) -> bool:
	return pair.get("favorite", false) or copy_id in pair.get("favorite_copy_ids", []) or range_contains(pair.get("favorite_copy_ranges", []), copy_serial(copy_id))

func append_range(ranges: Array, first: int, last: int) -> void:
	if not ranges.is_empty() and int(ranges.back()[1]) + 1 == first:
		ranges.back()[1] = last
	else:
		ranges.append([first, last])

func remove_range_copy(ranges: Array, serial: int) -> bool:
	for index in ranges.size():
		var first := int(ranges[index][0])
		var last := int(ranges[index][1])
		if serial < first or serial > last: continue
		ranges.remove_at(index)
		if serial < last: ranges.insert(index, [serial + 1, last])
		if serial > first: ranges.insert(index, [first, serial - 1])
		return true
	return false

func remove_copy(pair: Dictionary, copy_id: String) -> bool:
	if copy_id in pair.copy_ids:
		pair.copy_ids.erase(copy_id)
	elif not remove_range_copy(pair.get("copy_ranges", []), copy_serial(copy_id)):
		return false
	pair.favorite_copy_ids.erase(copy_id)
	remove_range_copy(pair.get("favorite_copy_ranges", []), copy_serial(copy_id))
	pair.quantity -= 1
	copy_lookup_cache.erase(copy_id)
	return true

func copies_page(pair: Dictionary, offset: int = 0, limit: int = 12) -> Array[String]:
	var result: Array[String] = []
	if offset < 0 or limit <= 0: return result
	var explicit: Array = pair.get("copy_ids", [])
	if offset < explicit.size(): result.assign(explicit.slice(offset, mini(explicit.size(), offset + limit)))
	offset = maxi(0, offset - explicit.size())
	for span in pair.get("copy_ranges", []):
		if result.size() >= limit: break
		var length := int(span[1]) - int(span[0]) + 1
		if offset >= length:
			offset -= length
			continue
		var take := mini(limit - result.size(), length - offset)
		for index in take: result.append(copy_name(int(span[0]) + offset + index))
		offset = 0
	return result

func first_candidates(pair: Dictionary, limit: int) -> Array[String]:
	# Every identity in one stack has identical damage. Inspect only K explicit
	# copies and K range representatives, including for a large legacy save.
	limit = clampi(limit, 0, SlimerotBalance.MAX_SLOTS)
	if limit == 0: return []
	var serials: Array[int] = []
	for copy_id in pair.copy_ids.slice(0, limit):
		var serial := copy_serial(copy_id)
		if serials.size() == limit and serial >= serials.back(): continue
		serials.append(serial)
		serials.sort()
		if serials.size() > limit: serials.pop_back()
	for span in pair.get("copy_ranges", []).slice(0, limit):
		for serial in range(int(span[0]), mini(int(span[1]) + 1, int(span[0]) + limit)):
			if serials.size() == limit and serial >= serials.back(): break
			serials.append(serial)
			serials.sort()
			if serials.size() > limit: serials.pop_back()
	var result: Array[String] = []
	for serial in serials: result.append(copy_name(serial))
	return result

func range_quantity(ranges: Array) -> int:
	var total := 0
	for span in ranges: total += int(span[1]) - int(span[0]) + 1
	return total

func identity_intervals(pair: Dictionary, favorites: bool = false) -> Array:
	var spans: Array = pair.get("favorite_copy_ranges" if favorites else "copy_ranges", []).duplicate(true)
	# Legacy arrays were appended in serial order. Coalesce their adjacent IDs
	# before sorting so validating an old large stack does not allocate N ranges.
	var run_first := -1
	var run_last := -1
	for copy_id in pair.get("favorite_copy_ids" if favorites else "copy_ids", []):
		var serial := copy_serial(copy_id)
		if serial == run_last + 1 and run_first >= 0:
			run_last = serial
		else:
			if run_first >= 0: spans.append([run_first, run_last])
			run_first = serial
			run_last = serial
	if run_first >= 0: spans.append([run_first, run_last])
	spans.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return spans

func merged_intervals(spans: Array) -> Array:
	var result: Array = []
	for span in spans:
		if not result.is_empty() and int(span[0]) <= int(result.back()[1]) + 1:
			result.back()[1] = maxi(int(result.back()[1]), int(span[1]))
		else: result.append([int(span[0]), int(span[1])])
	return result

func available_intervals(pair: Dictionary) -> Array:
	if pair.is_empty() or pair.get("favorite", false): return []
	var owned := merged_intervals(identity_intervals(pair))
	var protected := identity_intervals(pair, true)
	for copy_id in equipped_copy_ids:
		if pair_contains_copy(pair, copy_id):
			var serial := copy_serial(copy_id)
			protected.append([serial, serial])
	protected.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	protected = merged_intervals(protected)
	var available: Array = []
	var protected_index := 0
	for span in owned:
		var cursor := int(span[0])
		var last := int(span[1])
		while protected_index < protected.size() and int(protected[protected_index][1]) < cursor: protected_index += 1
		var index := protected_index
		while index < protected.size() and int(protected[index][0]) <= last:
			if int(protected[index][0]) > cursor: available.append([cursor, int(protected[index][0]) - 1])
			cursor = maxi(cursor, int(protected[index][1]) + 1)
			index += 1
		if cursor <= last: available.append([cursor, last])
	return available

func valid_identity_intervals(pair: Dictionary, next_id: int, favorites: bool = false) -> bool:
	var ids: Variant = pair.get("favorite_copy_ids" if favorites else "copy_ids")
	var spans: Variant = pair.get("favorite_copy_ranges" if favorites else "copy_ranges", [])
	if not ids is Array or not spans is Array: return false
	for copy_id in ids:
		var serial := copy_serial(copy_id)
		if serial < 1 or serial >= next_id: return false
	for span in spans:
		if not span is Array or span.size() != 2: return false
		if not SlimerotSaveFormat.integer(span[0]) or not SlimerotSaveFormat.integer(span[1]): return false
		if int(span[0]) < 1 or int(span[1]) < int(span[0]) or int(span[1]) >= next_id: return false
	var end := 0
	for span in identity_intervals(pair, favorites):
		if int(span[0]) <= end: return false
		end = int(span[1])
	return true

func validate_saved_inventory(saved_inventory: Dictionary, saved_team: Array, saved_next_id: Variant) -> String:
	# Validation sorts interval boundaries, never every serial inside a bulk range.
	if not SlimerotSaveFormat.integer(saved_next_id) or int(saved_next_id) < 1: return "Invalid next copy ID"
	var global_spans: Array = []
	for key in saved_inventory:
		var pair: Variant = saved_inventory[key]
		if not pair is Dictionary or not pair.get("slime_id") is String or not pair.get("variant") is String: return "Invalid inventory stack"
		if SlimeDatabase.get_slime(pair.slime_id) == null or pair.variant not in SlimerotBalance.VARIANTS or key != pair.slime_id + ":" + pair.variant: return "Unknown slime or variant"
		if not SlimerotSaveFormat.integer(pair.get("variant_flags")) or int(pair.variant_flags) != SlimerotVariants.mask(pair.variant): return "Invalid variant flags"
		if not pair.get("favorite") is bool or not SlimerotSaveFormat.integer(pair.get("quantity")): return "Invalid inventory quantity or favorite"
		if not valid_identity_intervals(pair, int(saved_next_id)) or not valid_identity_intervals(pair, int(saved_next_id), true): return "Invalid or overlapping copy identities"
		var owned := identity_intervals(pair)
		if range_quantity(owned) != int(pair.quantity): return "Inventory quantity does not match owned identities"
		global_spans.append_array(owned)
		owned = merged_intervals(owned)
		var index := 0
		for favorite in identity_intervals(pair, true):
			while index < owned.size() and int(owned[index][1]) < int(favorite[0]): index += 1
			if index >= owned.size() or int(owned[index][0]) > int(favorite[0]) or int(owned[index][1]) < int(favorite[1]): return "Favorite is not owned"
	global_spans.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var end := 0
	for span in global_spans:
		if int(span[0]) <= end: return "A copy belongs to more than one stack"
		end = int(span[1])
	if saved_team.size() > SlimerotBalance.MAX_SLOTS: return "Too many equipped copies"
	var seen: Dictionary = {}
	for copy_id in saved_team:
		if not copy_id is String or seen.has(copy_id): return "Invalid or duplicate equipped copy"
		seen[copy_id] = true
		var owned := false
		for pair in saved_inventory.values():
			if pair_contains_copy(pair, copy_id):
				owned = true
				break
		if not owned: return "Equipped copy is not owned"
	return ""

func pair_for_copy(copy_id: String) -> Dictionary:
	var cached_key: String = copy_lookup_cache.get(copy_id, "")
	if inventory.has(cached_key): return inventory[cached_key]
	for key in inventory:
		var pair: Dictionary = inventory[key]
		if pair_contains_copy(pair, copy_id):
			remember_copy(copy_id, key)
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
	if copy_id not in equipped_copy_ids: return
	equipped_copy_ids.erase(copy_id)
	notify_change("team_change")

func auto_equip_strongest() -> bool:
	# Slimerot needs at most five winners, not a full copy sort with repeated
	# inventory searches and derived-stat calculations in every comparison.
	var strongest: Array[Dictionary] = []
	var stats := SkillTreeManager.derived_stats()
	var slots: int = clampi(stats.equipped_slots, 1, SlimerotBalance.MAX_SLOTS)
	for pair in inventory.values():
		var damage := calculate_pair_damage(pair, stats)
		if strongest.size() == slots and damage < strongest.back().damage: continue
		for copy_id: String in first_candidates(pair, slots):
			if strongest.size() == slots:
				var weakest: Dictionary = strongest.back()
				if damage < weakest.damage or (is_equal_approx(damage, weakest.damage) and copy_id.naturalnocasecmp_to(weakest.id) >= 0): continue
			strongest.append({"id": copy_id, "damage": damage, "key": pair.slime_id + ":" + pair.variant})
			strongest.sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0 if is_equal_approx(a.damage, b.damage) else a.damage > b.damage)
			if strongest.size() > slots: strongest.pop_back()
	var selected: Array[String] = []
	for entry in strongest:
		selected.append(entry.id)
		remember_copy(entry.id, entry.key)
	if selected == equipped_copy_ids: return false
	equipped_copy_ids.assign(selected)
	notify_change("team_change")
	return true

func toggle_favorite(key: String) -> void:
	if inventory.has(key):
		var pair: Dictionary = inventory[key]
		pair.favorite = not pair.favorite
		# The group flag protects every current and future copy without duplicating
		# a potentially large legacy array just to mark the entire stack favorite.
		pair.favorite_copy_ids = []
		pair.favorite_copy_ranges = []
		notify_change("favorite_change")

func toggle_copy_favorite(copy_id: String) -> void:
	var pair := pair_for_copy(copy_id)
	if pair.is_empty():
		return
	if pair.favorite:
		pair.favorite_copy_ranges = merged_intervals(identity_intervals(pair))
		pair.favorite_copy_ids = []
		pair.favorite = false
	if copy_is_favorite(pair, copy_id):
		pair.favorite_copy_ids.erase(copy_id)
		remove_range_copy(pair.get("favorite_copy_ranges", []), copy_serial(copy_id))
	else:
		pair.favorite_copy_ids.append(copy_id)
	notify_change("favorite_change")

func is_protected(copy_id: String) -> bool:
	var pair := pair_for_copy(copy_id)
	return pair.is_empty() or copy_id in equipped_copy_ids or copy_is_favorite(pair, copy_id)

func sell_value(key: String) -> int:
	var pair: Dictionary = inventory[key]
	return roundi(SlimeDatabase.get_slime(pair.slime_id).base_sell * SlimerotBalance.VARIANT_DATA[pair.variant].sell * (1.0 + SkillTreeManager.derived_stats().duplicate_dealer))

func sell_copy(copy_id: String) -> int:
	if not GameState.structure_unlocked_flags.get("sell_terminal", false) or is_protected(copy_id):
		return 0
	var pair := pair_for_copy(copy_id)
	var value := sell_value(pair.slime_id + ":" + pair.variant)
	remove_copy(pair, copy_id)
	GameState.award_coins(value, false)
	notify_change("sale")
	return value

func sell_duplicates() -> int:
	if not GameState.structure_unlocked_flags.get("sell_terminal", false):
		return 0
	var earned := 0
	for key in inventory:
		var pair: Dictionary = inventory[key]
		if pair.favorite: continue
		var retained: Array = pair.favorite_copy_ids.duplicate()
		var retained_set: Dictionary = {}
		for id in retained: retained_set[id] = true
		var ranges: Array = pair.get("favorite_copy_ranges", []).duplicate(true)
		for copy_id in equipped_copy_ids:
			if pair_contains_copy(pair, copy_id) and not retained_set.has(copy_id) and not range_contains(ranges, copy_serial(copy_id)):
				retained.append(copy_id)
		if retained.is_empty() and ranges.is_empty() and pair.quantity > 0: retained.append(first_candidates(pair, 1)[0])
		var quantity := retained.size() + range_quantity(ranges)
		earned += (int(pair.quantity) - quantity) * sell_value(key)
		pair.copy_ids = retained
		pair.copy_ranges = ranges
		pair.quantity = quantity
	if earned > 0:
		invalidate_lookup_cache()
		GameState.award_coins(earned, false)
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
	var pair := pair_for_copy(copy_id)
	if pair.is_empty() or pair.variant != "normal" or pair.quantity <= 1 or is_protected(copy_id):
		return 0
	if not auto_sell_pair_eligible(pair): return 0
	var value := sell_value(pair.slime_id + ":normal")
	remove_copy(pair, copy_id)
	GameState.award_coins(value, false)
	return value

func auto_sell_pair_eligible(pair: Dictionary) -> bool:
	if pair.variant != "normal" or not SkillTreeManager.derived_stats().auto_sell or not GameState.settings.auto_sell_settings.enabled: return false
	var threshold := int(GameState.settings.auto_sell_settings.threshold)
	if threshold not in auto_sell_thresholds(): threshold = SlimerotRollTree.DEFAULT_SELL_THRESHOLD
	return SlimeDatabase.get_slime(pair.slime_id).rarity_threshold <= threshold

func damage_for_pair(pair: Dictionary, boss: bool = false) -> float:
	return calculate_pair_damage(pair, SkillTreeManager.derived_stats(), boss)

func calculate_pair_damage(pair: Dictionary, stats: Dictionary, boss: bool = false) -> float:
	var brew := SlimerotEncounters.BREW_MULTIPLIER if boss and GameState.boss_brew_seconds > 0 else 1.0
	return roundf(SlimeDatabase.get_base_combat_damage(pair.slime_id, pair.variant) * stats.damage_multiplier * (1.0 + stats.boss_damage_bonus if boss else 1.0) * brew)

func mutation_candidates(slime_id: String, limit: int = SlimerotEncounters.MUTATION_COPIES) -> Array[String]:
	var result: Array[String] = []
	var pair: Dictionary = inventory.get(slime_id+":normal", {})
	if pair.get("favorite", false): return result
	for span in available_intervals(pair):
		for serial in range(int(span[0]), mini(int(span[1]) + 1, int(span[0]) + limit - result.size())):
			result.append(copy_name(serial))
		if result.size() == limit: break
	return result

func mutation_candidate_count(slime_id: String) -> int:
	return range_quantity(available_intervals(inventory.get(slime_id + ":normal", {})))

func mutate(_slime_id: String) -> bool:
	# Retired recipe; the persistent structure now hosts a Variant Shrine.
	return false

func shrine_count(flag: int) -> int:
	return GameState.shrine_sacrifices.get(SlimerotVariants.key(flag), []).size() if flag in SlimerotVariants.FLAGS else 0

func shrine_multiplier(flag: int) -> float:
	return pow(SlimerotVariants.SHRINE_FACTOR, shrine_count(flag))

func sacrifice(copy_id: String, flag: int) -> bool:
	if flag not in SlimerotVariants.FLAGS or is_protected(copy_id): return false
	if not GameState.structure_unlocked_flags.get("mutation_lab", false) or GameState.current_zone != 6 or WorldManager.boss_active or GameState.is_paused() or GameState.player_dead: return false
	var pair := pair_for_copy(copy_id)
	if not (SlimerotVariants.mask(pair.variant) & flag): return false
	var category := SlimerotVariants.key(flag)
	if pair.slime_id in GameState.shrine_sacrifices[category]: return false
	if not remove_copy(pair, copy_id): return false
	GameState.shrine_sacrifices[category].append(pair.slime_id)
	notify_change("variant_sacrifice")
	return true

func damage_for_copy(copy_id: String, boss: bool = false) -> float:
	var pair := pair_for_copy(copy_id)
	return 0.0 if pair.is_empty() else damage_for_pair(pair, boss)

func team_dps() -> float:
	var damage := 0.0
	for copy_id in equipped_copy_ids:
		damage += damage_for_copy(copy_id)
	return damage / SkillTreeManager.derived_stats().attack_interval

func best_variant_owned(slime_id: String) -> String:
	var best := ""
	var power := -1
	for variant in SlimerotVariants.KEYS:
		if inventory.get(slime_id + ":" + variant, {}).get("quantity", 0) > 0:
			var rarity := SlimeDatabase.get_effective_rarity(slime_id, variant)
			if rarity > power:
				best = variant
				power = rarity
	return best

func collection() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for row in SlimerotRoster.ROWS:
		entries.append({"slime": SlimeDatabase.get_slime(row[0]), "discovered": discoveries.has(row[0]), "best_variant": best_variant_owned(row[0])})
	return entries

func sorted_pairs(order: String) -> Array:
	var pairs: Array = inventory.values().filter(func(pair): return pair.quantity > 0)
	var damages: Dictionary = {}
	if order == "DPS":
		var stats := SkillTreeManager.derived_stats()
		for pair in pairs: damages[pair.slime_id + ":" + pair.variant] = calculate_pair_damage(pair, stats)
	pairs.sort_custom(func(a, b):
		var first := SlimeDatabase.get_slime(a.slime_id)
		var second := SlimeDatabase.get_slime(b.slime_id)
		if order == "Name" and first.display_name != second.display_name:
			return first.display_name < second.display_name
		if order == "Rarity":
			var first_rarity := SlimeDatabase.get_effective_rarity(a.slime_id, a.variant)
			var second_rarity := SlimeDatabase.get_effective_rarity(b.slime_id, b.variant)
			if first_rarity != second_rarity: return first_rarity > second_rarity
		if order == "DPS" and damages[a.slime_id + ":" + a.variant] != damages[b.slime_id + ":" + b.variant]:
			return damages[a.slime_id + ":" + a.variant] > damages[b.slime_id + ":" + b.variant]
		return (a.slime_id + a.variant) < (b.slime_id + b.variant))
	return pairs

func notify_change(reason: String) -> void:
	GameState.best_team_dps = maxf(GameState.best_team_dps, team_dps())
	if reason == "team_change": team_changed.emit()
	else: inventory_changed.emit()
	GameState.changed.emit()
	GameState.critical_change.emit(reason)

func reset() -> void:
	invalidate_lookup_cache()
	inventory.clear()
	equipped_copy_ids.clear()
	discoveries.clear()
	next_copy_id = 1
