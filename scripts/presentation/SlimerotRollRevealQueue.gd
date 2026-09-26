class_name SlimerotRollRevealQueue
extends RefCounted

signal started(result: Dictionary)
signal finished
var active: Dictionary = {}
var pending: Array[Dictionary] = []
var remaining := 0.0
var major_gap_remaining := 0.0
var record_summary: Dictionary = {}

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
			if not pending[index].get("power_improvement", false):
				drop = index
				if not pending[index].major: break
		remember_record(pending[drop])
		pending.remove_at(drop)
	pending.append(item)
	advance(0.0)

func remember_record(item: Dictionary) -> void:
	if not item.get("power_improvement", false): return
	# Overflow may compress records, but never silently discard their presentation.
	# One bounded summary retains the strongest result and counts every compressed
	# record. It does not own or grant any rewards.
	var count := int(record_summary.get("summarized_best_count", 0)) + int(item.get("summarized_best_count", 1))
	if record_summary.is_empty() or int(item.get("effective_rarity", 0)) > int(record_summary.get("effective_rarity", 0)):
		record_summary = item.duplicate(true)
	record_summary.summarized_best_count = count

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
	if not record_summary.is_empty() and major_gap_remaining <= 0.0:
		var summary := record_summary
		record_summary = {}
		start(summary)
		return
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
	record_summary.clear()
	active.clear()
	remaining = 0.0
	major_gap_remaining = 0.0
	finished.emit()
