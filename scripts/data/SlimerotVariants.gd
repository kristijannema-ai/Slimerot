class_name SlimerotVariants
extends RefCounted

# Slimerot canonical rarity never changes when a Shrine improves the odds.
const SHINY := 1
const GLITCHED := 2
const GOLDEN := 4
const FLAGS := [SHINY, GLITCHED, GOLDEN]
const KEYS := ["normal", "shiny", "glitched", "shiny+glitched", "golden", "shiny+golden", "glitched+golden", "shiny+glitched+golden"]
const DENOMINATORS := {SHINY: 100, GLITCHED: 400, GOLDEN: 1600}
const SHRINE_FACTOR := 1.05

static func mask(value: Variant) -> int:
	if value is int: return value if value >= 0 and value <= 7 else -1
	if value is float: return int(value) if is_finite(value) and value == floor(value) and value >= 0 and value <= 7 else -1
	if value is String: return KEYS.find(value)
	return -1

static func key(value: int) -> String:
	return KEYS[value] if value >= 0 and value <= 7 else ""

static func label(value: Variant) -> String:
	var flags := mask(value)
	return key(flags).replace("+", " + ").capitalize() if flags >= 0 else "Unknown"

static func rarity_multiplier(value: Variant) -> int:
	var flags := mask(value)
	if flags < 0: return 0
	var multiplier := 1
	for flag in FLAGS:
		if flags & flag: multiplier *= DENOMINATORS[flag]
	return multiplier

static func sell_multiplier(value: Variant) -> float:
	var flags := mask(value)
	var multiplier := 1.0
	for flag in FLAGS:
		if flags & flag: multiplier *= {SHINY: 2.0, GLITCHED: 5.0, GOLDEN: 10.0}[flag]
	return multiplier

static func probability(flag: int, shrine_count: int = 0, modifier: float = 1.0) -> float:
	if flag not in FLAGS: return 0.0
	return minf(1.0, modifier * pow(SHRINE_FACTOR, clampi(shrine_count, 0, 24)) / DENOMINATORS[flag])

static func color(value: Variant) -> Color:
	var flags := mask(value)
	if flags & GOLDEN: return Color("ffdc77")
	if flags & GLITCHED: return Color("e894ff")
	if flags & SHINY: return Color("bcfaff")
	return Color("b6ed78")

static func all_metadata() -> Dictionary:
	var result := {}
	for flags in 8:
		var chance := 1.0
		for flag in FLAGS:
			var p := probability(flag)
			chance *= p if flags & flag else 1.0 - p
		# damage is retained only as a legacy display ratio. Combat rounds from rarity.
		result[key(flags)] = {"chance": chance, "damage": pow(rarity_multiplier(flags), 0.32), "sell": sell_multiplier(flags), "color": color(flags)}
	return result
