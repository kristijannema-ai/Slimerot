extends Node

signal zone_changed(zone_id: int)
signal respawn_requested
signal boss_requested(zone_id: int)
signal completion_reached
var boss_active := false
var structures: Dictionary = {}
var arriving_from_next := false

func _ready() -> void:
	for data in SlimerotData.structures():
		structures[data.id] = data

func travel(zone_id: int, from_next: bool = false) -> bool:
	if zone_id < 0 or zone_id > SlimerotBalance.MAX_ZONE or zone_id > GameState.highest_zone_unlocked or GameState.player_dead:
		return false
	arriving_from_next = from_next and zone_id > 0
	boss_active = false
	GameState.current_zone = zone_id
	CombatManager.reset_combat()
	GameState.player_hp = SkillTreeManager.derived_stats().max_hp
	zone_changed.emit(zone_id)
	GameState.changed.emit()
	GameState.critical_change.emit("zone_transition")
	return true

func gate_open(zone_id: int) -> bool:
	return GameState.unlocked_gate_flags.get(str(zone_id),false)

func gate_blocker(zone_id: int) -> String:
	if zone_id < 1 or zone_id > 8: return "Invalid gate"
	if gate_open(zone_id): return ""
	var data := SlimerotCampaign.zone(zone_id)
	var kills := int(GameState.zone_kill_counts.get(str(zone_id),0))
	if kills < data.kill_requirement: return "%d / %d kills" % [kills,data.kill_requirement]
	if not data.boss_id_or_null.is_empty() and not is_boss_zone_defeated(zone_id): return "Defeat this zone's boss"
	if GameState.coins < data.gate_coin_cost: return "Need %s more Coins" % SlimeDatabase.format_number(data.gate_coin_cost-GameState.coins)
	return ""

func gate_prompt(zone_id: int) -> String:
	var data := SlimerotCampaign.zone(zone_id)
	var destination := SlimerotCampaign.zone(zone_id+1).name if zone_id < 8 else "Campaign finale"
	if gate_open(zone_id): return "Enter " + destination if zone_id < 8 else "Campaign complete"
	var requirements := "%d / %d kills · %s Coins" % [int(GameState.zone_kill_counts.get(str(zone_id),0)),data.kill_requirement,SlimeDatabase.format_number(data.gate_coin_cost)]
	if not data.boss_id_or_null.is_empty(): requirements += " · Boss " + ("defeated" if is_boss_zone_defeated(zone_id) else "required")
	return destination + "\n" + requirements

func unlock_gate(zone_id: int) -> bool:
	if GameState.current_zone != zone_id or GameState.player_dead or GameState.is_paused() or gate_open(zone_id) or not gate_blocker(zone_id).is_empty(): return false
	var data := SlimerotCampaign.zone(zone_id)
	if not GameState.spend("Coins",data.gate_coin_cost,false): return false
	GameState.unlocked_gate_flags[str(zone_id)] = true
	GameState.highest_zone_unlocked = maxi(GameState.highest_zone_unlocked,mini(8,zone_id+1))
	GameState.changed.emit()
	GameState.critical_change.emit("gate_purchase")
	return true

func use_exit() -> bool:
	var zone := GameState.current_zone
	if boss_active: return false
	if zone == 0: return travel(1)
	if zone == 8 and GameState.completion_portal_unlocked: return complete_campaign()
	if not gate_open(zone) and not unlock_gate(zone): return false
	return travel(zone+1) if zone < 8 else true

func return_through_gate() -> bool:
	if GameState.current_zone < 1: return false
	return travel(GameState.current_zone-1,true)

func boss_encounter_prompt(zone_id: int) -> String:
	var data := SlimerotCampaign.zone(zone_id)
	if is_boss_zone_defeated(zone_id): return "Boss defeated. Return to the exit gate."
	if int(GameState.zone_kill_counts.get(str(zone_id),0)) < data.kill_requirement:
		return "Defeat %d enemies to reach the boss encounter." % data.kill_requirement
	return "Enter " + str(SlimerotEncounters.BOSSES[zone_id].name)

func start_boss(zone_id: int) -> bool:
	if not SlimerotEncounters.BOSSES.has(zone_id) or GameState.current_zone != zone_id or boss_active or GameState.is_paused() or GameState.player_dead or is_boss_zone_defeated(zone_id): return false
	if int(GameState.zone_kill_counts.get(str(zone_id),0)) < SlimerotCampaign.zone(zone_id).kill_requirement: return false
	boss_active = true
	CombatManager.clear_projectiles()
	boss_requested.emit(zone_id)
	return true

func finish_boss_reward(zone_id: int) -> bool:
	if not SlimerotEncounters.BOSSES.has(zone_id) or is_boss_zone_defeated(zone_id): return false
	var data: Dictionary = SlimerotEncounters.BOSSES[zone_id]
	GameState.boss_defeated_flags["zone_%d" % zone_id] = true
	GameState.award_coins(data.coins,false)
	if not data.potion.is_empty(): GameState.potion_inventory[data.potion] = int(GameState.potion_inventory.get(data.potion,0))+1
	if zone_id == 8:
		GameState.completion_portal_unlocked = true
		GameState.unlocked_gate_flags["8"] = true
	GameState.changed.emit()
	GameState.critical_change.emit("boss_defeat")
	return true

func complete_campaign() -> bool:
	if GameState.current_zone != 8 or not GameState.completion_portal_unlocked or boss_active or GameState.player_dead: return false
	GameState.campaign_completed = true
	GameState.critical_change.emit("completion_portal")
	completion_reached.emit()
	return true

func fast_travel(zone_id: int) -> bool:
	if not GameState.structure_unlocked_flags.get("fast_travel_pillar",false) or boss_active or GameState.is_paused(): return false
	return travel(zone_id)

func potion_recipe_unlocked(id: String) -> bool:
	if not SlimerotEncounters.POTIONS.has(id) or not GameState.structure_unlocked_flags.get("potion_bench",false): return false
	var boss: int = SlimerotEncounters.POTIONS[id].boss
	return boss == 0 or is_boss_zone_defeated(boss)

func craft_potion(id: String) -> bool:
	if not potion_recipe_unlocked(id) or GameState.current_zone != 2 or boss_active or GameState.is_paused() or GameState.player_dead: return false
	if not GameState.spend("Coins",SlimerotEncounters.POTIONS[id].cost,false): return false
	GameState.potion_inventory[id] = int(GameState.potion_inventory.get(id,0))+1
	GameState.changed.emit()
	GameState.critical_change.emit("potion_craft")
	return true

func drink_potion(id: String) -> bool:
	if not SlimerotEncounters.POTIONS.has(id) or int(GameState.potion_inventory.get(id,0)) < 1 or GameState.is_paused() or GameState.player_dead: return false
	var luck: float = SlimerotEncounters.POTIONS[id].luck
	if id != "boss_brew" and GameState.potion_remaining_seconds > 0 and GameState.active_potion_multiplier > luck: return false
	GameState.potion_inventory[id] -= 1
	if id == "boss_brew": GameState.boss_brew_seconds = SlimerotEncounters.POTION_SECONDS
	else:
		GameState.active_potion_type = id
		GameState.active_potion_multiplier = luck
		GameState.potion_remaining_seconds = SlimerotEncounters.POTION_SECONDS
	GameState.changed.emit()
	GameState.critical_change.emit("potion_use")
	return true

func repair(id: String) -> bool:
	var data: SlimerotData.StructureData = structures.get(id)
	if data == null or boss_active or GameState.is_paused() or GameState.player_dead or GameState.current_zone != data.zone or GameState.structure_unlocked_flags.get(data.unlock_flag, false):
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
