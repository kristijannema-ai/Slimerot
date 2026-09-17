class_name SlimerotSuperRoll
extends RefCounted

# Lifetime trigger numbers survive purchases, saves and offline batches. A zero
# trigger means disabled or no future trigger fits the exact save-number range.
static func initial(lifetime: int, interval: int = 100) -> int:
	if interval <= 0: return 0
	return after_trigger(lifetime, interval - lifetime % interval)

static func after_trigger(lifetime: int, interval: int) -> int:
	if interval <= 0 or lifetime > SlimerotSaveFormat.MAX_EXACT_INTEGER - interval: return 0
	return lifetime + interval

static func upgrade(lifetime: int, next_trigger: int, interval: int) -> int:
	var latest := after_trigger(lifetime, interval)
	if next_trigger > lifetime:
		return next_trigger if latest == 0 else mini(next_trigger, latest)
	return latest

static func due(lifetime: int, next_trigger: int) -> bool:
	return next_trigger > 0 and lifetime < SlimerotSaveFormat.MAX_EXACT_INTEGER and lifetime + 1 == next_trigger
