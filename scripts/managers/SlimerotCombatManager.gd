extends Node

signal slime_attacked(origin: Vector2, destination: Vector2)
var player: CharacterBody2D
var attack_timers: Dictionary = {}
var invulnerable_remaining := 0.0

func _physics_process(delta: float) -> void:
	if GameState.is_paused() or not is_instance_valid(player):
		return
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	for copy_id in InventoryManager.equipped_copy_ids:
		attack_timers[copy_id] = maxf(0.0, float(attack_timers.get(copy_id, 0.0)) - delta)
		if attack_timers[copy_id] > 0.0:
			continue
		var target := find_target(player.global_position)
		if target != null:
			attack_timers[copy_id] = SkillTreeManager.derived_stats().attack_interval
			slime_attacked.emit(player.global_position, target.global_position)
			target.take_damage(InventoryManager.damage_for_copy(copy_id))

func find_target(origin: Vector2) -> Node2D:
	var target: Node2D
	var nearest: float = SkillTreeManager.derived_stats().attack_range
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"):
		if enemy.dead:
			continue
		var distance: float = origin.distance_to(enemy.global_position)
		if distance <= nearest:
			target = enemy
			nearest = distance
	return target

func damage_player(amount: float) -> void:
	if invulnerable_remaining > 0.0 or GameState.is_paused():
		return
	GameState.player_hp = maxf(0.0, GameState.player_hp - maxf(0.0, amount))
	GameState.changed.emit()
	if GameState.player_hp <= 0.0:
		invulnerable_remaining = 2.0
		attack_timers.clear()
		WorldManager.respawn()
