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
const INK := Color("183b47")
const CREAM := Color("f3ffe3")
const MINT := Color("b9f578")
const TEAL := Color("28535c")

static func reveal_tier(threshold: int) -> int:
	for index in REVEAL_LIMITS.size():
		if threshold < REVEAL_LIMITS[index]: return index
	return 4

static func reveal_duration(threshold: int, first_discovery: bool, skip_common: bool) -> float:
	var tier := reveal_tier(threshold)
	if tier == 0 and skip_common: return SKIP_COMMON_SECONDS
	if tier == 4 and not first_discovery: return REPEAT_JACKPOT_SECONDS
	return REVEAL_SECONDS[tier]
