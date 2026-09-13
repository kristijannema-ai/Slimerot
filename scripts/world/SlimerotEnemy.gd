class_name SlimerotEnemy
extends CharacterBody2D

var data: SlimerotData.EnemyData
var hp := 0.0
var dead := false
var attack_remaining := 0.0
var home := Vector2.ZERO
var respawn_remaining := 0.0

func _ready() -> void:
	if data == null: data = SlimerotData.lagling()
	hp = data.max_hp
	home = position
	collision_layer = 4
	collision_mask = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	shape.shape = circle
	add_child(shape)
	add_to_group("slimerot_enemies")

func _physics_process(delta: float) -> void:
	if GameState.is_paused() or GameState.player_dead:
		return
	if dead:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			if is_instance_valid(CombatManager.player) and home.distance_to(CombatManager.player.global_position) < 100: return
			dead = false
			hp = data.max_hp
			position = home
			collision_layer = 4
			attack_remaining = 0
			show()
		return
	var player := CombatManager.player
	if not is_instance_valid(player):
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
	var distance := position.distance_to(player.position)
	var destination := player.global_position
	var engaged := distance < SlimerotCampaign.AGGRO_RANGE and home.distance_to(player.global_position) < SlimerotCampaign.LEASH_RANGE
	var direction := Vector2.ZERO
	if not engaged:
		destination = home
		if position.distance_to(home) > 5: direction = position.direction_to(home)
	elif data.archetype == "shooter":
		if distance < SlimerotCampaign.SHOOTER_NEAR: direction = player.position.direction_to(position)
		elif distance > SlimerotCampaign.SHOOTER_FAR: direction = position.direction_to(player.position)
	elif distance > 38: direction = position.direction_to(player.position)
	if direction != Vector2.ZERO and get_parent().has_method("direction_to_point"):
		if data.archetype != "shooter" or distance >= SlimerotCampaign.SHOOTER_NEAR:
			direction = get_parent().direction_to_point(global_position,destination)
	velocity = direction * data.move_speed
	for other in get_tree().get_nodes_in_group("slimerot_enemies"):
		if other == self or other.dead: continue
		var separation: Vector2 = global_position-other.global_position
		if separation.length() < 50 and separation.length() > 0.01:
			velocity += separation.normalized() * data.move_speed * (1.0-separation.length()/50.0)
	velocity = velocity.limit_length(data.move_speed)
	move_and_slide()
	if engaged and attack_remaining == 0.0:
		if data.archetype == "shooter" and distance <= SlimerotCampaign.AGGRO_RANGE:
			var ray := PhysicsRayQueryParameters2D.create(global_position,player.global_position,1)
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				CombatManager.fire_enemy_projectile(global_position,global_position.direction_to(player.global_position),data.attack_damage,SlimerotCampaign.ENEMY_SHOT_SPEED)
				attack_remaining = data.attack_interval
		elif data.archetype != "shooter" and position.distance_to(player.position) < 45:
			attack_remaining = data.attack_interval
			CombatManager.damage_player(data.attack_damage)
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		dead = true
		collision_layer = 0
		hide()
		respawn_remaining = SlimerotCampaign.RESPAWN_SECONDS
		WorldManager.record_kill(data.zone, data.coin_reward)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 12), 26, Color(0, 0, 0, 0.2))
	var tint := Color(SlimerotCampaign.PALETTES[data.zone-1][3])
	draw_circle(Vector2.ZERO, 28 if data.archetype == "tank" else 23, tint)
	if data.archetype == "tank": draw_arc(Vector2.ZERO,29,0,TAU,24,tint.darkened(0.4),5)
	if data.archetype == "shooter": draw_colored_polygon(PackedVector2Array([Vector2(-16,-16),Vector2(0,-37),Vector2(16,-16)]),tint.lightened(0.3))
	draw_circle(Vector2(-8, -3), 4, Color("442e44"))
	draw_circle(Vector2(8, -3), 4, Color("442e44"))
	draw_line(Vector2(-9, 9), Vector2(9, 9), Color("442e44"), 3)
	draw_rect(Rect2(-26, -37, 52, 5), Color("273f39"))
	draw_rect(Rect2(-26, -37, 52 * hp / data.max_hp, 5), Color("e8abbd"))
	var title := "Lagling" if data.id == "lagling" else data.archetype.capitalize()
	draw_string(ThemeDB.fallback_font, Vector2(-70, -47), "Lv. %d %s" % [data.level,title], HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color("e7e9df"))
