class_name SlimerotProjectile
extends Node2D

var target: Node2D
var destination := Vector2.ZERO
var damage := 0.0
var speed := SlimerotBalance.PROJECTILE_SPEED
var hostile := false
var direction := Vector2.ZERO
var lifetime := 0.0
var spent := false

func _ready() -> void:
	z_index = 5

func _physics_process(delta: float) -> void:
	if spent or GameState.is_paused() or GameState.player_dead: return
	lifetime += delta
	if hostile:
		var next := global_position + direction*speed*delta
		var query := PhysicsRayQueryParameters2D.create(global_position, next, 3)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider == CombatManager.player: CombatManager.damage_player(damage)
			finish()
		else:
			global_position = next
			if lifetime > 6: finish()
	else:
		if not is_instance_valid(target) or not target.is_inside_tree() or target.dead:
			finish()
			return
		# Slimerot locks a straight flight segment at firing. Impact is guaranteed
		# for this target even if it moves; no retargeting or terrain collision.
		global_position = global_position.move_toward(destination, speed*delta)
		if global_position.is_equal_approx(destination):
			target.take_damage(damage)
			finish()
	queue_redraw()

func finish() -> void:
	spent = true
	hide()
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7, Color("ef91a3") if hostile else Color("b6ed78"))
	draw_circle(Vector2(-2,-2), 3, Color("f6ffe1"))
