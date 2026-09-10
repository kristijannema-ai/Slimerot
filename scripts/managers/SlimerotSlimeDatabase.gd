extends Node

var slimes: Dictionary = {}

func _ready() -> void:
	var starter := SlimerotData.SlimeData.new()
	starter.id = SlimerotBalance.FIRST_SLIME
	starter.display_name = "Tung Tung Tung Sahur"
	starter.zone_unlock = 0
	starter.rarity_threshold = 1
	starter.base_damage = SlimerotBalance.STARTER_DAMAGE
	starter.base_sell = SlimerotBalance.STARTER_SELL
	starter.sprite_path = "res://assets/Slimerot.svg"
	starter.aura_tier = 0
	slimes[starter.id] = starter

func eligible(zone_id: int) -> Array:
	return slimes.values().filter(func(data): return data.zone_unlock <= zone_id)

func get_slime(id: String) -> SlimerotData.SlimeData:
	return slimes.get(id)
