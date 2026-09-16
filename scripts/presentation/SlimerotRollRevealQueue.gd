class_name SlimerotRollRevealQueue
extends RefCounted

signal started(result: Dictionary)
signal finished
var active: Dictionary = {}
var pending: Array[Dictionary] = []
var remaining := 0.0
var major_gap_remaining := 0.0

func prepare(result: Dictionary) -> Dictionary:
	var item := result.duplicate(true)
	item.tier = SlimerotPresentation.adaptive_tier(item)
	item.major = item.tier >= 2
	return item

func enqueue(result: Dictionary) -> void:
	var item := prepare(result)
	for index in pending.size():
		var old := pending[index]
		if not old.get("first_discovery", false) and not old.get("power_improvement", false) and old.slime_id == item.slime_id and old.variant == item.variant:
			pending[index] = item
			return
	if pending.size() >= SlimerotPresentation.MAX_PENDING_REVEALS:
		var drop := 0
		for index in pending.size():
			if not pending[index].major:
				drop = index
				break
		pending.remove_at(drop)
	pending.append(item)
	advance(0.0)

func start(result: Dictionary) -> void:
	active = prepare(result)
	remaining = SlimerotPresentation.adaptive_duration(active)
	started.emit(active.duplicate(true))

func advance(delta: float) -> void:
	major_gap_remaining = maxf(0.0, major_gap_remaining - delta)
	if not active.is_empty():
		remaining = maxf(0.0, remaining - delta)
		if remaining > 0.0: return
		finish()
	if not active.is_empty(): return
	for index in pending.size():
		if not pending[index].major or major_gap_remaining <= 0.0:
			var item := pending[index]
			pending.remove_at(index)
			start(item)
			return

func finish() -> void:
	if active.get("major", false): major_gap_remaining = SlimerotPresentation.MAJOR_REVEAL_BREAK
	active.clear()
	remaining = 0.0
	finished.emit()

func skip() -> bool:
	if active.is_empty() or (active.tier == 4 and active.get("first_discovery", false)): return false
	finish()
	advance(0.0)
	return true

func clear() -> void:
	pending.clear()
	active.clear()
	remaining = 0.0
	major_gap_remaining = 0.0
	finished.emit()
