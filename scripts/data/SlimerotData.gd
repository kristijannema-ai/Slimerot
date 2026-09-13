class_name SlimerotData
extends RefCounted

# Typed Slimerot content contracts; unprovided later-stage content is not fabricated.
class SlimeData extends Resource:
	@export var id: String
	@export var display_name: String
	@export var zone_unlock: int
	@export var rarity_threshold: int = 1
	@export var base_damage: float
	@export var base_sell: int
	@export var sprite_path: String
	@export var aura_tier: int

class EnemyData extends Resource:
	@export var id: String
	@export var zone: int
	@export var level: int
	@export var archetype: String
	@export var max_hp: float
	@export var attack_damage: float
	@export var attack_interval: float
	@export var coin_reward: int
	@export var move_speed: float

class BossData extends Resource:
	@export var id: String
	@export var zone: int
	@export var level: int
	@export var max_hp: float
	@export var attacks: Array[Dictionary] = []
	@export var reward_coins: int
	@export var defeated_flag: String

class SkillNodeData extends Resource:
	@export var id: String
	@export var display_name: String
	@export var description: String
	@export var optional: bool = false
	@export var tree_type: String
	@export var prerequisite_ids: Array[String] = []
	@export var currency_type: String
	@export var cost: int
	@export var effect_type: String
	@export var effect_value: float
	@export var required_boss_zone: int = 0
	@export var required_zone: int = 1
	@export var required_structure: String = ""

class ZoneData extends Resource:
	@export var id: int
	@export var name: String
	@export var enemy_level_range: Vector2i
	@export var kill_requirement: int
	@export var gate_coin_cost: int
	@export var boss_id_or_null: String = ""
	@export var slime_unlock_ids: Array[String] = []

class StructureData extends Resource:
	@export var id: String
	@export var zone: int
	@export var coin_cost: int
	@export var unlock_flag: String
	@export var function_type: String

static func lagling() -> EnemyData:
	return SlimerotCampaign.enemy(1, "chaser")

static func zone(zone_id: int) -> ZoneData:
	return SlimerotCampaign.zone(zone_id)

static func structures() -> Array[StructureData]:
	var result: Array[StructureData] = []
	for row in SlimerotBalance.EARLY_STRUCTURES:
		var data := StructureData.new()
		data.id = row[0]
		data.zone = 1
		data.coin_cost = row[1]
		data.unlock_flag = data.id
		data.function_type = row[2]
		result.append(data)
	return result
