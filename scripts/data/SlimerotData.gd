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
	var data := EnemyData.new()
	data.id = "lagling"
	data.zone = 1
	data.level = 1
	data.archetype = "chaser"
	data.max_hp = SlimerotBalance.LAGLING_HP
	data.attack_damage = SlimerotBalance.LAGLING_DAMAGE
	data.attack_interval = SlimerotBalance.LAGLING_ATTACK_INTERVAL
	data.coin_reward = SlimerotBalance.LAGLING_COINS
	data.move_speed = SlimerotBalance.LAGLING_SPEED
	return data

static func zone(zone_id: int) -> ZoneData:
	var data := ZoneData.new()
	data.id = zone_id
	data.name = "Bedroom Hub" if zone_id == 0 else "Backyard"
	data.enemy_level_range = Vector2i.ZERO if zone_id == 0 else Vector2i(1, 1)
	data.kill_requirement = 0 if zone_id == 0 else SlimerotBalance.BACKYARD_GATE_KILLS
	data.gate_coin_cost = 0 if zone_id == 0 else SlimerotBalance.BACKYARD_GATE_COINS
	for row in SlimerotRoster.ROWS:
		if row[2] == zone_id:
			data.slime_unlock_ids.append(row[0])
	return data

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
