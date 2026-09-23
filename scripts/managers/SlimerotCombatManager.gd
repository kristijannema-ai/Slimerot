extends Node

signal slime_attacked(origin: Vector2, destination: Vector2)
var player: CharacterBody2D
var attack_timers: Dictionary = {}
var invulnerable_remaining := 0.0
var damage_free_seconds := 0.0
var death_remaining := 0.0
const PROJECTILE_CAPACITY := 128
var projectile_pool: Array[SlimerotProjectile] = []
var feedback: SlimerotCombatFeedback

func _ready() -> void:
	feedback = SlimerotCombatFeedback.new()
	add_child(feedback)
	for index in PROJECTILE_CAPACITY:
		var shot := SlimerotProjectile.new()
		add_child(shot)
		shot.deactivate()
		projectile_pool.append(shot)

func acquire_projectile() -> SlimerotProjectile:
	for shot in projectile_pool:
		if shot.spent:
			shot.activate()
			return shot
	return null

func active_projectiles() -> Array[SlimerotProjectile]:
	var result: Array[SlimerotProjectile] = []
	for shot in projectile_pool:
		if not shot.spent: result.append(shot)
	return result

func active_projectile_count() -> int:
	var count := 0
	for shot in projectile_pool:
		if not shot.spent: count += 1
	return count

func slime_position(slot: int) -> Vector2:
	if not is_instance_valid(player): return Vector2.ZERO
	var angle := float(slot) / maxf(1, InventoryManager.equipped_copy_ids.size()) * TAU
	return player.global_position + Vector2(cos(angle), sin(angle)) * SlimerotBalance.SLIME_ORBIT_RADIUS

func _physics_process(delta: float) -> void:
	if GameState.is_paused() or not is_instance_valid(player): return
	if GameState.player_dead:
		death_remaining = maxf(0, death_remaining-delta)
		if death_remaining == 0:
			GameState.player_dead = false
			reset_combat()
			WorldManager.respawn()
		return
	invulnerable_remaining = maxf(0, invulnerable_remaining-delta)
	var previous := damage_free_seconds
	damage_free_seconds += delta
	var healing_time := maxf(0, damage_free_seconds - maxf(previous, SlimerotBalance.REGEN_DELAY))
	var max_hp: float = SkillTreeManager.derived_stats().max_hp
	if healing_time > 0 and GameState.player_hp < max_hp:
		GameState.player_hp = minf(max_hp, GameState.player_hp + max_hp * SlimerotBalance.REGEN_FRACTION * healing_time)
		GameState.changed.emit()
	for id in attack_timers.keys():
		if id not in InventoryManager.equipped_copy_ids: attack_timers.erase(id)
	for slot in InventoryManager.equipped_copy_ids.size():
		var copy_id: String = InventoryManager.equipped_copy_ids[slot]
		attack_timers[copy_id] = maxf(0, float(attack_timers.get(copy_id, 0))-delta)
		if attack_timers[copy_id] > 0: continue
		var origin := slime_position(slot)
		var target := find_target(origin)
		if target != null:
			attack_timers[copy_id] = SlimerotBalance.ATTACK_INTERVAL
			fire_slime_projectile(origin, target, InventoryManager.damage_for_copy(copy_id, target.is_in_group("slimerot_bosses")))

func fire_slime_projectile(origin: Vector2, target: Node2D, damage: float) -> Node2D:
	var shot := acquire_projectile()
	if shot == null: return null
	shot.position = origin
	shot.target = target
	shot.destination = target.global_position
	shot.damage = damage
	slime_attacked.emit(origin, shot.destination)
	return shot

func fire_enemy_projectile(origin: Vector2, direction: Vector2, damage: float, speed: float = SlimerotBalance.PROJECTILE_SPEED, source: Node2D = null, allow_friendly_fire: bool = false, style_zone: int = 0) -> Node2D:
	var shot := acquire_projectile()
	if shot == null: return null
	shot.position = origin
	shot.hostile = true
	shot.direction = direction.normalized()
	shot.damage = damage
	shot.speed = speed
	shot.source = source
	shot.allow_friendly_fire = allow_friendly_fire
	shot.style_zone = style_zone
	return shot

func find_target(origin: Vector2) -> Node2D:
	var target: Node2D
	var nearest := SlimerotBalance.ATTACK_RANGE
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"):
		if enemy.dead: continue
		var distance: float = origin.distance_to(enemy.global_position)
		if distance <= nearest:
			target = enemy
			nearest = distance
	return target

func damage_player(amount: float) -> void:
	if amount <= 0 or invulnerable_remaining > 0 or GameState.is_paused() or GameState.player_dead: return
	if is_instance_valid(player) and player.has_method("is_dashing") and player.is_dashing(): return
	feedback.player_hit(player.global_position if is_instance_valid(player) else Vector2.ZERO)
	damage_free_seconds = 0
	GameState.player_hp = maxf(0, GameState.player_hp-amount)
	if GameState.player_hp == 0:
		GameState.player_dead = true
		death_remaining = SlimerotBalance.DEATH_FADE_SECONDS
		clear_projectiles()
	GameState.changed.emit()

func clear_projectiles() -> void:
	for shot in projectile_pool: shot.deactivate()

func reset_combat() -> void:
	if is_instance_valid(player) and player.has_method("cancel_dash"): player.cancel_dash(true)
	if is_instance_valid(feedback): feedback.clear()
	attack_timers.clear()
	clear_projectiles()
	damage_free_seconds = 0
	death_remaining = 0
	invulnerable_remaining = 0
	GameState.player_dead = false
