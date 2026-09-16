class_name SlimerotPresentation
extends RefCounted

# Slimerot presentation tuning; gameplay balance remains in SlimerotBalance.
const JOYSTICK_RADIUS := 90.0
const TOUCH_TARGET := 62.0
const SCROLL_DEADZONE := 14.0
const BREAKTHROUGH_SECONDS := 1.8
const REVEAL_LIMITS := [100, 10000, 100000, 1000000]
const REVEAL_SECONDS := [0.35, 0.65, 1.10, 1.70, 2.80]
const SKIP_COMMON_SECONDS := 0.20
const REPEAT_JACKPOT_SECONDS := 1.0
const MAX_PENDING_REVEALS := 32
const MAJOR_REVEAL_BREAK := 5.0
const RELEVANT_DAMAGE_RATIO := 0.85
const SURPRISE_MEDIUM := 25.0
const SURPRISE_RARE := 100.0
const SURPRISE_JACKPOT := 1000.0
const ADAPTIVE_REVEAL_SECONDS := [0.50, 1.40, 3.0, 4.0, 5.0]
const INK := Color("101c2d")
const CREAM := Color("f0f5ed")
const MINT := Color("c8fa7c")
const TEAL := Color("22354b")
const MUTED := Color("9fb1bd")
const SURFACE := Color("172639")
const BORDER := Color("34475c")
const GOLD := Color("ffd47d")

static func reveal_tier(threshold: int) -> int:
	for index in REVEAL_LIMITS.size():
		if threshold < REVEAL_LIMITS[index]: return index
	return 4

static func reveal_duration(threshold: int, first_discovery: bool, skip_common: bool) -> float:
	var tier := reveal_tier(threshold)
	if tier == 0 and skip_common: return SKIP_COMMON_SECONDS
	if tier == 4 and not first_discovery: return REPEAT_JACKPOT_SECONDS
	return REVEAL_SECONDS[tier]

static func adaptive_tier(result: Dictionary) -> int:
	var rarity := float(result.get("effective_rarity", result.get("threshold", 2)))
	var surprise := rarity / maxf(1.0, float(result.get("luck_used", 1.0)))
	var tier := 0
	if surprise >= SURPRISE_MEDIUM: tier = 1
	if surprise >= SURPRISE_RARE: tier = 2
	if surprise >= SURPRISE_JACKPOT: tier = 4
	var weakest := float(result.get("weakest_equipped_damage", INF))
	var damage := float(result.get("damage", result.get("base_damage", 0)))
	if (damage > 0.0 and damage >= weakest * RELEVANT_DAMAGE_RATIO) or result.get("team_has_space", false): tier = maxi(tier, 2)
	if result.get("power_improvement", false): tier = maxi(tier, 2)
	if result.get("first_discovery", false) or result.get("variant_discovery", false) or result.get("first_roll", false): tier = maxi(tier, 1)
	var flags := SlimerotVariants.mask(result.get("variant_flags", result.get("variant", "normal")))
	if flags & SlimerotVariants.SHINY: tier = maxi(tier, 1)
	if flags & SlimerotVariants.GLITCHED: tier = maxi(tier, 2)
	if flags & SlimerotVariants.GOLDEN: tier = maxi(tier, 3)
	if flags == 7: tier = 4
	return tier

static func adaptive_duration(result: Dictionary) -> float:
	var tier := int(result.get("tier", adaptive_tier(result)))
	if tier == 0 and SkillTreeManager.derived_stats().skip_common: return SKIP_COMMON_SECONDS
	return ADAPTIVE_REVEAL_SECONDS[tier]
