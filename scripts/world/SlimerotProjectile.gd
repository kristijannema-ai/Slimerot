class_name SlimerotProjectile
extends Node2D

# Swept rays retain the original collision backend. Layers: world=1, player=2,
# normal enemy=4, boss=8. Normal Shooter rays add layer 4; bosses never do.
var target: Node2D
var source: Node2D
var destination := Vector2.ZERO
var damage := 0.0
var speed := SlimerotBalance.PROJECTILE_SPEED
var hostile := false
var allow_friendly_fire := false
var style_zone := 0
var direction := Vector2.ZERO
var lifetime := 0.0
var spent := true

func _ready() -> void:
	z_index = 5

func activate() -> void:
	target = null
	source = null
	destination = Vector2.ZERO
	damage = 0.0
	speed = SlimerotBalance.PROJECTILE_SPEED
	hostile = false
	allow_friendly_fire = false
	style_zone = 0
	direction = Vector2.ZERO
	lifetime = 0.0
	spent = false
	show()
	set_physics_process(true)

func deactivate() -> void:
	spent = true
	target = null
	source = null
	hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if spent or GameState.is_paused() or GameState.player_dead: return
	lifetime += delta
	if hostile:
		var next := global_position + direction * speed * delta
		var query := PhysicsRayQueryParameters2D.create(global_position, next, 7 if allow_friendly_fire else 3)
		if is_instance_valid(source) and source is CollisionObject2D: query.exclude = [source.get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit.position
			if hit.collider == CombatManager.player:
				CombatManager.damage_player(damage)
			elif can_hit_normal_enemy(hit.collider):
				hit.collider.take_damage(roundf(hit.collider.data.max_hp * 0.20))
			finish()
		else:
			global_position = next
			if lifetime > 6: finish(false)
	else:
		if not is_instance_valid(target) or not target.is_inside_tree() or target.dead:
			finish(false)
			return
		# Friendly slime shots preserve one committed straight flight and one hit.
		direction = global_position.direction_to(destination)
		global_position = global_position.move_toward(destination, speed * delta)
		if global_position.is_equal_approx(destination):
			target.take_damage(damage)
			finish()
	queue_redraw()

func can_hit_normal_enemy(candidate: Object) -> bool:
	return allow_friendly_fire and candidate is SlimerotEnemy and candidate != source and not candidate.dead

func finish(impact: bool = true) -> void:
	if spent: return
	if impact and is_instance_valid(CombatManager.feedback): CombatManager.feedback.projectile_impact(global_position, hostile)
	deactivate()

func _draw() -> void:
	if spent: return
	var color := Color("bcff83")
	if hostile:
		color = Color(["ff839e", "ffd17d", "ffae76", "96ddff", "f5d18e", "ffa48c", "cdf292", "b0a3ff", "f89aff"][clampi(style_zone, 0, 8)])
	var facing := direction.angle()
	var spawn := minf(1.0, 0.35 + lifetime / 0.09)
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * spawn)
	# A tapered tail, dark outline and bright diamond core remain readable on props.
	draw_colored_polygon(PackedVector2Array([Vector2(2,-6),Vector2(-38,-2),Vector2(-49,0),Vector2(-38,2),Vector2(2,6)]), Color(color, 0.4))
	var shell := PackedVector2Array([Vector2(13,0),Vector2(-1,-10),Vector2(-11,-6),Vector2(-8,0),Vector2(-11,6),Vector2(-1,10)])
	draw_colored_polygon(shell, Color("211c35"))
	draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(-1,-6),Vector2(-7,0),Vector2(-1,6)]), color)
	draw_line(Vector2(-2,0),Vector2(5,0),Color("fffbe4"),3,true)
	draw_set_transform(Vector2.ZERO)
