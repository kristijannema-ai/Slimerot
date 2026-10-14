class_name BLContext
extends Node2D

signal shook(amount: float)
var arena := Rect2(40, 220, 640, 760)
var player: BLPlayer
var boss: Node2D
var rng := RandomNumberGenerator.new()
var phase := 1
var hazards: BLHazardPool
var projectiles: BLProjectilePool
var effects: BLEffects
var balanced: BLBalance
var darkness := 0.0
var moves: Array[Dictionary] = []
var clip: Control

func setup(data: BLBalance, actor: BLPlayer, target: Node2D) -> void:
	balanced = data
	player = actor
	boss = target
	clip = Control.new()
	clip.position = arena.position
	clip.size = arena.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	hazards = BLHazardPool.new()
	clip.add_child(hazards)
	hazards.position = -arena.position
	hazards.setup(self, data.hazard_capacity)
	projectiles = BLProjectilePool.new()
	clip.add_child(projectiles)
	projectiles.position = -arena.position
	projectiles.setup(self, data.projectile_capacity)
	effects = BLEffects.new()
	clip.add_child(effects)
	effects.position = -arena.position
	effects.setup(data.fx_capacity)

func hazard(spec: Dictionary) -> int:
	return hazards.add(spec)

func hazard_update(index: int, changes: Dictionary) -> void:
	hazards.update_slot(index, changes)

func shot(origin: Vector2, direction: Vector2, speed: float, damage: int, attack: String, owner: String = "", params: Dictionary = {}) -> void:
	projectiles.add(origin, direction, speed, damage, attack, owner, params)

func fan(origin: Vector2, direction: Vector2, count: int, spread: float, speed: float, damage: int, attack: String, owner: String = "", params: Dictionary = {}) -> void:
	var angle := direction.angle()
	for index in count:
		var offset := 0.0 if count <= 1 else -spread * 0.5 + spread * float(index) / float(count - 1)
		shot(origin, Vector2.from_angle(angle + offset), speed, damage, attack, owner, params)

func move_boss_to(destination: Vector2, seconds: float, owner: String = "") -> void:
	moves.clear()
	moves.append({"start":boss.global_position, "end":clamp_point(destination, 40), "duration":maxf(0.01, seconds), "age":0.0, "owner":owner})

func tell_destination(destination: Vector2, warning: float, attack: String) -> void:
	hazard({"kind":"circle", "origin":clamp_point(destination), "radius":36.0, "warning":warning, "active":0.20,
		"damage":0, "color":Color("c89fff"), "label":"ARRIVAL", "attack":attack, "owner":attack})

func cleanup(owner: String) -> void:
	hazards.clear(owner)
	projectiles.clear(owner)
	for index in range(moves.size() - 1, -1, -1):
		if moves[index].owner == owner: moves.remove_at(index)

func clear() -> void:
	hazards.clear()
	projectiles.clear()
	effects.clear()
	moves.clear()
	darkness = 0.0
	if boss != null: boss.modulate = Color.WHITE

func fx(point: Vector2, color: Color, count: int = 12) -> void:
	effects.burst(point, color, count)

func shake(amount: float = 0.7) -> void:
	shook.emit(clampf(amount, 0.0, 2.0))

func clamp_point(point: Vector2, margin: float = 24.0) -> Vector2:
	return point.clamp(arena.position + Vector2.ONE * margin, arena.end - Vector2.ONE * margin)

func aim() -> Vector2:
	return (player.global_position - boss.global_position).normalized()

func predicted(seconds: float = 0.45) -> Vector2:
	return clamp_point(player.global_position + player.velocity.limit_length(balanced.move_speed) * seconds, 35)

func free_angle() -> float:
	return (arena.get_center() - boss.global_position).angle() if boss.global_position.distance_to(arena.get_center()) > 100 else aim().angle() + PI * 0.5

func step(delta: float) -> void:
	clip.position = arena.position
	clip.size = arena.size
	for drawing in [hazards, projectiles, effects]: drawing.position = -arena.position
	for index in range(moves.size() - 1, -1, -1):
		moves[index].age += delta
		var ratio := minf(1.0, float(moves[index].age) / float(moves[index].duration))
		boss.global_position = Vector2(moves[index].start).lerp(moves[index].end, ratio)
		if ratio >= 1.0: moves.remove_at(index)
	player.speed_modifier = 1.0
	player.external_force = Vector2.ZERO
	player.sliding = false
	hazards.step(delta)
	projectiles.step(delta)
	effects.step(delta)
