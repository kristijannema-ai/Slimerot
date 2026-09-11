extends Node

signal zone_changed(zone_id: int)
signal respawn_requested
var structures: Dictionary = {}

func _ready() -> void:
	for data in SlimerotData.structures():
		structures[data.id] = data

func travel(zone_id: int) -> bool:
	if zone_id < 0 or zone_id > 1 or zone_id > GameState.highest_zone_unlocked:
		return false
	GameState.current_zone = zone_id
	GameState.player_hp = SkillTreeManager.derived_stats().max_hp
	zone_changed.emit(zone_id)
	GameState.changed.emit()
	GameState.critical_change.emit("zone_transition")
	return true

func repair(id: String) -> bool:
	var data: SlimerotData.StructureData = structures.get(id)
	if data == null or GameState.current_zone != data.zone or GameState.structure_unlocked_flags.get(data.unlock_flag, false):
		return false
	if not GameState.spend("Coins", data.coin_cost):
		return false
	GameState.structure_unlocked_flags[data.unlock_flag] = true
	GameState.changed.emit()
	GameState.critical_change.emit("structure_purchase")
	return true

func record_kill(zone_id: int, coins: int) -> void:
	var key := str(zone_id)
	GameState.zone_kill_counts[key] = int(GameState.zone_kill_counts.get(key, 0)) + 1
	GameState.award_coins(roundi(coins * (1.0 + SkillTreeManager.derived_stats().coin_scavenger)))

func is_boss_zone_defeated(zone_id: int) -> bool:
	return GameState.boss_defeated_flags.get("zone_%d" % zone_id, false)

func award_boss_reward(zone_id: int, coins: int) -> bool:
	if is_boss_zone_defeated(zone_id):
		return false
	GameState.boss_defeated_flags["zone_%d" % zone_id] = true
	GameState.award_coins(coins)
	GameState.critical_change.emit("boss_defeat")
	return true

func respawn() -> void:
	GameState.player_hp = SkillTreeManager.derived_stats().max_hp
	respawn_requested.emit()
	GameState.changed.emit()
