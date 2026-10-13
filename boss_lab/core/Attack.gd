class_name BLAttack
extends RefCounted

var context: BLContext
var phase := 1
var elapsed := 0.0
var ended := false
var attack_id := ""
var display_name := ""
var recovery := 0.35
var duration := 4.0
# Opt-in: after authored events finish, recover when this owner has no live combat.
# Duration remains the bounded maximum if distant projectiles are still in flight.
var finish_when_clear_after := -1.0
var params: Dictionary = {}
var events: Array[Dictionary] = []

func setup(ctx: BLContext, current_phase: int) -> void:
	context = ctx
	phase = current_phase
	elapsed = 0.0
	ended = false
	events.clear()
	finish_when_clear_after = -1.0

func can_start() -> bool:
	return context != null and context.player.hp > 0.0

func begin() -> void:
	pass

func telegraph() -> void:
	pass

func execute() -> void:
	pass

func recover() -> void:
	pass

func at(seconds: float, callback: Callable) -> void:
	events.append({"time": seconds, "callback": callback, "done": false})

func tick(delta: float) -> void:
	if ended: return
	elapsed += delta
	# A callback may schedule additional events. Index iteration is deterministic.
	var count := events.size()
	for index in count:
		if not events[index].done and elapsed >= float(events[index].time):
			events[index].done = true
			events[index].callback.call()
	if elapsed >= duration:
		finish()
	elif finish_when_clear_after >= 0.0 and elapsed >= finish_when_clear_after and _owner_combat_clear():
		finish()

func finish() -> void:
	ended = true

func cleanup() -> void:
	context.cleanup(attack_id)
	events.clear()


func _owner_combat_clear() -> bool:
	for event in events:
		if not event.done: return false
	for hazard in context.hazards.slots:
		if not hazard.is_empty() and str(hazard.get("owner", "")) == attack_id: return false
	for projectile in context.projectiles.slots:
		if not projectile.is_empty() and str(projectile.get("owner", "")) == attack_id: return false
	return true

func flight_allowance(origin: Vector2, speed: float) -> float:
	# Conservative maximum across this arena, plus a small physics-frame margin.
	var farthest := 0.0
	for corner in [context.arena.position, Vector2(context.arena.end.x, context.arena.position.y), context.arena.end, Vector2(context.arena.position.x, context.arena.end.y)]:
		farthest = maxf(farthest, origin.distance_to(corner))
	return farthest / maxf(1.0, speed) + 0.15
