class_name SlimerotCombatFeedback
extends Node2D

# One drawing node, fixed reusable records: hits never allocate scene nodes.
const CAPACITY := 48
var effects: Array[Dictionary] = []
var cursor := 0
var clock := 0.0
var shake_remaining := 0.0
var shake_strength := 0.0
var player_hit_events := 0
var camera_events := 0
var particle_events := 0
var unlock_events := 0

func _ready() -> void:
	z_index = 8
	for index in CAPACITY:
		effects.append({"at":Vector2.ZERO,"remaining":0.0,"duration":0.4,"color":Color.WHITE,"count":6,"radius":36.0,"ring":false})

func burst(at: Vector2, color: Color, count: int = 6, radius: float = 36.0, ring: bool = false) -> void:
	if effects.is_empty(): return
	var effect := effects[cursor]
	cursor = (cursor + 1) % CAPACITY
	effect.at = at
	effect.remaining = 0.42
	effect.duration = 0.42
	effect.color = color
	effect.count = count
	effect.radius = radius
	effect.ring = ring
	particle_events += 1
	queue_redraw()

func shake(strength: float, seconds: float) -> void:
	camera_events += 1
	shake_strength = maxf(shake_strength, strength)
	shake_remaining = maxf(shake_remaining, seconds)

func player_hit(at: Vector2) -> void:
	player_hit_events += 1
	shake(7.0, 0.18)
	burst(at, Color("ff778e"), 8, 44)
	if is_instance_valid(CombatManager.player) and CombatManager.player.has_method("combat_hit_flash"):
		CombatManager.player.combat_hit_flash()

func enemy_hit(at: Vector2) -> void:
	burst(at, Color("e6ff98"))

func enemy_died(at: Vector2) -> void:
	burst(at, Color("ffcf78"), 12, 72, true)

func boss_hit(at: Vector2) -> void:
	burst(at, Color("ff9de8"), 8, 48)

func dash_started(at: Vector2) -> void:
	burst(at, Color("9effe8"), 7, 46, true)

func dash_finished(at: Vector2) -> void:
	burst(at, Color("9effe8"), 4, 26)

func projectile_impact(at: Vector2, hostile: bool) -> void:
	burst(at, Color("ff9b78") if hostile else Color("c8ff89"), 4, 24)

func zone_unlocked(at: Vector2) -> void:
	unlock_events += 1
	shake(3.0, 0.22)
	burst(at, Color("f6db87"), 14, 140, true)

func camera_offset() -> Vector2:
	if GameState.is_paused() or not GameState.settings.screen_shake or shake_remaining <= 0.0: return Vector2.ZERO
	return Vector2(sin(clock * 67.0), cos(clock * 53.0)) * shake_strength * minf(1.0, shake_remaining / 0.18)

func clear() -> void:
	for effect in effects: effect.remaining = 0.0
	shake_remaining = 0.0
	shake_strength = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if GameState.is_paused(): return
	clock += delta
	shake_remaining = maxf(0.0, shake_remaining - delta)
	if shake_remaining == 0.0: shake_strength = 0.0
	var dirty := false
	for effect in effects:
		if effect.remaining <= 0.0: continue
		effect.remaining = maxf(0.0, effect.remaining - delta)
		dirty = true
	if dirty: queue_redraw()

func _draw() -> void:
	for effect in effects:
		if effect.remaining <= 0.0: continue
		var progress: float = 1.0 - effect.remaining / effect.duration
		var color: Color = effect.color
		color.a *= 1.0 - progress
		if effect.ring: draw_arc(effect.at, 8 + progress * effect.radius, 0, TAU, 28, color, 3.0, true)
		for index in int(effect.count):
			var direction := Vector2.from_angle(index * TAU / effect.count + index * 0.21)
			var point: Vector2 = effect.at + direction * effect.radius * progress
			draw_line(point, point + direction * (9.0 - 5.0 * progress), color, 4.0 * (1.0 - progress) + 1, true)
