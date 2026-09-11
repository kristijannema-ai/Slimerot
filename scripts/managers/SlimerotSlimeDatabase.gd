extends Node

var slimes: Dictionary = {}

func _ready() -> void:
	for row in SlimerotRoster.ROWS:
		var slime := SlimerotData.SlimeData.new()
		slime.id = row[0]
		slime.display_name = row[1]
		slime.zone_unlock = row[2]
		slime.rarity_threshold = row[3]
		slime.base_damage = SlimerotRoster.damage(slime.rarity_threshold)
		slime.base_sell = SlimerotRoster.sell_value(slime.rarity_threshold)
		slime.sprite_path = "res://assets/Slimerot.svg"
		slime.aura_tier = 0 if slime.rarity_threshold < 100 else (1 if slime.rarity_threshold < 10000 else (2 if slime.rarity_threshold < 100000 else (3 if slime.rarity_threshold < 1000000 else 4)))
		slimes[slime.id] = slime

func eligible(zone_id: int) -> Array:
	var pool := slimes.values().filter(func(data): return data.zone_unlock <= zone_id)
	pool.sort_custom(func(a, b): return a.rarity_threshold < b.rarity_threshold)
	return pool

func get_slime(id: String) -> SlimerotData.SlimeData:
	return slimes.get(id)

func threshold_label(id: String) -> String:
	return "Rarity threshold: 1 in %s" % format_number(get_slime(id).rarity_threshold)

func format_number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
