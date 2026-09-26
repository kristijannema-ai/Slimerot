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
		slime.sprite_path = "res://assets/art/slimes/Slimerot_%s.svg" % slime.id
		slime.aura_tier = SlimerotPresentation.reveal_tier(slime.rarity_threshold)
		slimes[slime.id] = slime

func eligible(_zone_id: int = 1) -> Array:
	# Zone is origin metadata only; every base is rollable from the start.
	var pool := slimes.values()
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

func get_effective_rarity(base_id: String, variant_flags: Variant = 0) -> int:
	var data := get_slime(base_id)
	return 0 if data == null else data.rarity_threshold * SlimerotVariants.rarity_multiplier(variant_flags)

func get_base_combat_damage(base_id: String, variant_flags: Variant = 0) -> int:
	var rarity := get_effective_rarity(base_id, variant_flags)
	return roundi(6.0 * pow(float(rarity), 0.32)) if rarity > 0 else 0

func power_audit_rows() -> Array[Dictionary]:
	# Diagnostic data uses the same canonical helpers as inventory and combat.
	var rows: Array[Dictionary] = []
	for slime in eligible():
		for flags in 8:
			rows.append({"base_id":slime.id, "base_threshold":slime.rarity_threshold,
				"origin_zone":slime.zone_unlock, "variant_mask":flags, "variant":SlimerotVariants.key(flags),
				"effective_rarity":get_effective_rarity(slime.id, flags), "raw_damage":get_base_combat_damage(slime.id, flags)})
	rows.sort_custom(func(a, b): return a.effective_rarity < b.effective_rarity)
	return rows
