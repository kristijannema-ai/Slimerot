extends Node

# Copies have stable IDs; quantities/favorites remain grouped by slime + variant.
var inventory: Dictionary = {}
var equipped_copy_ids: Array[String] = []
var next_copy_id := 1

func add_copy(slime_id: String, variant: String = "normal") -> String:
	if SlimeDatabase.get_slime(slime_id) == null or variant not in SlimerotBalance.VARIANTS:
		return ""
	var key := slime_id + ":" + variant
	if not inventory.has(key):
		inventory[key] = {"slime_id": slime_id, "variant": variant, "quantity": 0, "favorite": false, "copy_ids": []}
	var copy_id := "slimerot_copy_%d" % next_copy_id
	next_copy_id += 1
	inventory[key].copy_ids.append(copy_id)
	inventory[key].quantity = inventory[key].copy_ids.size()
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
	GameState.changed.emit()
	GameState.critical_change.emit("team_change")
	return true

func unequip(copy_id: String) -> void:
	equipped_copy_ids.erase(copy_id)
	GameState.changed.emit()
	GameState.critical_change.emit("team_change")

func toggle_favorite(key: String) -> void:
	if inventory.has(key):
		inventory[key].favorite = not inventory[key].favorite
		GameState.changed.emit()
		GameState.critical_change.emit("favorite_change")

func sell_duplicates() -> int:
	if not GameState.structure_unlocked_flags.get("sell_terminal", false):
		return 0
	var earned := 0
	for pair in inventory.values():
		if pair.favorite:
			continue
		var remaining: Array = []
		for copy_id in pair.copy_ids:
			if copy_id in equipped_copy_ids:
				remaining.append(copy_id)
		for copy_id in pair.copy_ids:
			if copy_id in equipped_copy_ids:
				continue
			if remaining.is_empty():
				remaining.append(copy_id)
			else:
				earned += SlimeDatabase.get_slime(pair.slime_id).base_sell
		pair.copy_ids = remaining
		pair.quantity = remaining.size()
	GameState.award_coins(earned)
	GameState.critical_change.emit("sell_duplicates")
	return earned

func damage_for_copy(copy_id: String) -> float:
	var pair := pair_for_copy(copy_id)
	if pair.is_empty():
		return 0.0
	return SlimeDatabase.get_slime(pair.slime_id).base_damage * SkillTreeManager.derived_stats().damage_multiplier

func team_dps() -> float:
	var damage := 0.0
	for copy_id in equipped_copy_ids:
		damage += damage_for_copy(copy_id)
	return damage / SkillTreeManager.derived_stats().attack_interval
