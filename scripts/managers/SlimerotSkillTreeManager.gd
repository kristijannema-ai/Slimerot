extends Node

var nodes: Dictionary = {}

func _ready() -> void:
	# Provisional Slimerot early-node costs; canonical numeric tables were not supplied.
	for row in SlimerotBalance.EARLY_ROLL_NODES:
		var data := SlimerotData.SkillNodeData.new()
		data.id = row[0]
		data.tree_type = "Roll"
		data.currency_type = "Rolls"
		data.cost = row[1]
		data.effect_type = row[2]
		data.effect_value = row[3]
		nodes[data.id] = data

func derived_stats(node_ids: Variant = null) -> Dictionary:
	var stats := {"luck": 1.0, "roll_cooldown": SlimerotBalance.ROLL_COOLDOWN,
		"max_hp": SlimerotBalance.PLAYER_HP, "move_speed": SlimerotBalance.MOVE_SPEED,
		"attack_interval": SlimerotBalance.ATTACK_INTERVAL, "attack_range": SlimerotBalance.ATTACK_RANGE,
		"damage_multiplier": 1.0, "equipped_slots": 1, "auto_roll": false}
	var purchased: Array = GameState.purchased_skill_node_ids if node_ids == null else node_ids
	for id in purchased:
		var data: SlimerotData.SkillNodeData = nodes.get(id)
		if data == null:
			continue
		match data.effect_type:
			"luck_multiplier": stats.luck *= data.effect_value
			"checkpoint_luck": stats.luck *= 20.0
			"cooldown_multiplier": stats.roll_cooldown *= data.effect_value
			"damage_multiplier": stats.damage_multiplier *= data.effect_value
			"hp_add": stats.max_hp += data.effect_value
			"speed_add": stats.move_speed += data.effect_value
			"slot_add": stats.equipped_slots += int(data.effect_value)
			"auto_roll": stats.auto_roll = true
	stats.equipped_slots = clampi(stats.equipped_slots, 1, SlimerotBalance.MAX_SLOTS)
	stats.roll_cooldown = maxf(0.1, stats.roll_cooldown)
	return stats

func purchase(id: String) -> bool:
	if not GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
		return false
	var data: SlimerotData.SkillNodeData = nodes.get(id)
	if data == null or id in GameState.purchased_skill_node_ids:
		return false
	for prerequisite in data.prerequisite_ids:
		if prerequisite not in GameState.purchased_skill_node_ids:
			return false
	if not GameState.spend(data.currency_type, data.cost):
		return false
	GameState.purchased_skill_node_ids.append(id)
	GameState.changed.emit()
	GameState.critical_change.emit("skill_purchase")
	return true
