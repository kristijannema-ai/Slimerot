extends Node

var nodes: Dictionary = {}
signal purchased(id: String, previous_luck: float, new_luck: float)

func _ready() -> void:
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL:
		var data := SlimerotData.SkillNodeData.new()
		data.id = row[0]
		data.display_name = row[1]
		if not row[2].is_empty(): data.prerequisite_ids.append(row[2])
		data.tree_type = "Roll"
		data.currency_type = "Rolls"
		data.cost = row[3]
		data.effect_type = row[4]
		data.effect_value = row[5]
		data.description = row[6]
		data.optional = data.id.begins_with("RO")
		nodes[data.id] = data
	for row in SlimerotCoinTree.ROWS:
		var data := SlimerotData.SkillNodeData.new()
		data.id = row[0]
		data.display_name = row[1]
		data.prerequisite_ids.assign(row[2])
		data.tree_type = "Coin"
		data.currency_type = "Coins"
		data.cost = row[3]
		data.effect_type = row[4]
		data.effect_value = row[5]
		data.required_zone = row[6]
		data.required_boss_zone = row[7]
		data.required_structure = row[8]
		data.description = SlimerotCoinTree.description(data.effect_type, data.effect_value)
		nodes[data.id] = data

func derived_stats(node_ids: Variant = null) -> Dictionary:
	var stats := {"luck": 1.0, "roll_cooldown": SlimerotBalance.ROLL_COOLDOWN,
		"max_hp": SlimerotBalance.PLAYER_HP, "move_speed": SlimerotBalance.MOVE_SPEED,
		"attack_interval": SlimerotBalance.ATTACK_INTERVAL, "attack_range": SlimerotBalance.ATTACK_RANGE,
		"damage_multiplier": 1.0, "team_damage_bonus": 0.0, "boss_damage_bonus": 0.0, "move_speed_bonus": 0.0, "equipped_slots": 1, "auto_roll": false,
		"breakthrough_count": 0, "variant_sense": false, "skip_common": false,
		"auto_sell": false, "filter_1": false, "filter_2": false, "super_roll": false,
		"coin_scavenger": 0.0, "duplicate_dealer": 0.0}
	var owned_nodes: Array = (GameState.purchased_skill_node_ids if node_ids == null else node_ids).duplicate()
	owned_nodes.sort()
	var minor_luck := 1.0
	var seen: Dictionary = {}
	for id in owned_nodes:
		if seen.has(id): continue
		seen[id] = true
		var data: SlimerotData.SkillNodeData = nodes.get(id)
		if data == null:
			continue
		match data.effect_type:
			"team_damage_add": stats.team_damage_bonus += data.effect_value
			"boss_damage_add": stats.boss_damage_bonus += data.effect_value
			"move_speed_add": stats.move_speed_bonus += data.effect_value
			"slot_set": stats.equipped_slots = maxi(stats.equipped_slots, int(data.effect_value))
			"luck_multiplier": minor_luck *= data.effect_value
			"checkpoint_luck":
				stats.breakthrough_count += 1
			"cooldown_set": stats.roll_cooldown = minf(stats.roll_cooldown, data.effect_value)
			"auto_sell": stats.auto_sell = true
			"filter_1": stats.filter_1 = true
			"filter_2": stats.filter_2 = true
			"super_roll": stats.super_roll = true
			"variant_sense": stats.variant_sense = true
			"skip_common": stats.skip_common = true
			"coin_scavenger": stats.coin_scavenger += data.effect_value
			"duplicate_dealer": stats.duplicate_dealer += data.effect_value
			"cooldown_multiplier": stats.roll_cooldown *= data.effect_value
			"damage_multiplier": stats.damage_multiplier *= data.effect_value
			"hp_add": stats.max_hp += data.effect_value
			"speed_add": stats.move_speed += data.effect_value
			"slot_add": stats.equipped_slots += int(data.effect_value)
			"auto_roll": stats.auto_roll = true
	stats.luck = minor_luck * pow(20.0, stats.breakthrough_count)
	stats.damage_multiplier *= 1.0 + stats.team_damage_bonus
	stats.move_speed *= 1.0 + stats.move_speed_bonus
	stats.equipped_slots = clampi(stats.equipped_slots, 1, SlimerotBalance.MAX_SLOTS)
	stats.roll_cooldown = maxf(0.1, stats.roll_cooldown)
	return stats

func purchase(id: String) -> bool:
	if not purchase_blocker(id).is_empty(): return false
	var data: SlimerotData.SkillNodeData = nodes.get(id)
	var previous_luck := RollManager.effective_luck()
	if not GameState.spend(data.currency_type, data.cost, false): return false
	GameState.purchased_skill_node_ids.append(id)
	if data.currency_type == "Rolls": GameState.roll_skill_spend[id] = data.cost
	if id == "R08": GameState.settings.luck_cap = 0.0
	RollManager.cooldown_remaining = minf(RollManager.cooldown_remaining, derived_stats().roll_cooldown)
	GameState.highest_luck = maxf(GameState.highest_luck, RollManager.effective_luck())
	GameState.best_team_dps = maxf(GameState.best_team_dps, InventoryManager.team_dps())
	GameState.changed.emit()
	GameState.critical_change.emit("skill_purchase")
	purchased.emit(id, previous_luck, RollManager.effective_luck())
	return true

func purchase_blocker(id: String) -> String:
	var data: SlimerotData.SkillNodeData = nodes.get(id)
	if data == null or id in GameState.purchased_skill_node_ids:
		return "Owned" if data != null else "Unknown node"
	# R01 explicitly starts the Roll mainline. The Shrine still opens Coin upgrades.
	if data.tree_type == "Coin" and not GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
		return "Repair the Skill Tree Shrine"
	if data.required_boss_zone > 0 and not WorldManager.is_boss_zone_defeated(data.required_boss_zone):
		return "Defeat the Z%d boss" % data.required_boss_zone
	if GameState.highest_zone_unlocked < data.required_zone: return "Unlock Z%d" % data.required_zone
	if not data.required_structure.is_empty() and not GameState.structure_unlocked_flags.get(data.required_structure, false): return "Repair Sell Terminal"
	for prerequisite in data.prerequisite_ids:
		if prerequisite not in GameState.purchased_skill_node_ids:
			return "Requires " + prerequisite
	var balance: int = GameState.rolls_balance if data.currency_type == "Rolls" else GameState.coins
	if balance < data.cost: return "Need %d more %s" % [data.cost - balance, data.currency_type]
	return ""

func rolls_spent(node_ids: Array, paid_costs: Variant = null) -> int:
	var total := 0
	var ledger: Dictionary = GameState.roll_skill_spend if paid_costs == null else paid_costs
	for id in node_ids:
		if nodes.has(id) and nodes[id].currency_type == "Rolls":
			total += int(ledger.get(id, nodes[id].cost))
	return total
