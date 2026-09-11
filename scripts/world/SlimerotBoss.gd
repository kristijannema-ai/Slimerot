class_name SlimerotBoss
extends CharacterBody2D

signal defeated
var zone_id := 2
var data: Dictionary
var hp := 0.0
var dead := false
var phase := "chase"
var phase_time := 0.0
var cycle_time := 0.0
var contact_remaining := 0.0
var teleport_index := 0
var bursts_fired := 0
var admin_teleport := false
var enraged := false
var aoe_clock := 0.0
var warnings: Array[Dictionary] = []
var aim := Vector2.DOWN
var attack_label := ""

func _ready() -> void:
	data = SlimerotEncounters.BOSSES[zone_id]
	hp = data.hp
	phase = "teleport_wait" if zone_id == 6 else "chase"
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42
	shape.shape = circle
	add_child(shape)
	add_to_group("slimerot_enemies")
	add_to_group("slimerot_bosses")

func _physics_process(delta: float) -> void:
	if dead or GameState.is_paused() or GameState.player_dead: return
	step(delta)
	queue_redraw()

func step(delta: float) -> void:
	var player := CombatManager.player
	if not is_instance_valid(player): return
	contact_remaining = maxf(0,contact_remaining-delta)
	if global_position.distance_to(player.global_position) < 62 and contact_remaining == 0:
		contact_remaining = 1.0
		CombatManager.damage_player(data.contact)
	phase_time += delta
	cycle_time += delta
	velocity = Vector2.ZERO
	if zone_id == 2:
		if phase == "chase":
			attack_label = "Chasing · slam warning next"
			velocity = global_position.direction_to(player.global_position)*data.speed
			if phase_time >= 3: enter_phase("slam_warning")
		else:
			attack_label = "SLAM · leave the circle"
			if phase_time >= 0.8:
				if global_position.distance_to(player.global_position) <= SlimerotEncounters.SLAM_RADIUS: CombatManager.damage_player(data.slam)
				enter_phase("chase")
	elif zone_id == 4 or (zone_id == 8 and not admin_teleport):
		if phase == "chase":
			attack_label = "Chasing · sand fan next"
			velocity = global_position.direction_to(player.global_position)*data.speed
			if phase_time >= 3.2:
				aim = global_position.direction_to(player.global_position)
				enter_phase("fan_warning")
		else:
			attack_label = "FAN · move between the five lanes"
			if phase_time >= 0.8:
				fire_spread(5,0.27)
				if zone_id == 8:
					admin_teleport = true
					cycle_time = 0
					enter_phase("teleport_wait")
				else: enter_phase("chase")
	else:
		attack_label = "Teleport in %.1fs" % maxf(0,6-cycle_time)
		if phase == "teleport_wait" and cycle_time >= 6:
			position = SlimerotEncounters.TELEPORT_POINTS[teleport_index%4]
			teleport_index += 1
			cycle_time = 0
			bursts_fired = 0
			aim = global_position.direction_to(player.global_position)
			enter_phase("burst_warning")
		elif phase == "burst_warning":
			attack_label = "AIMED BURST · sidestep"
			if phase_time >= 0.5:
				fire_spread(3,0.13)
				bursts_fired += 1
				aim = global_position.direction_to(player.global_position)
				if bursts_fired == 2:
					if zone_id == 8:
						admin_teleport = false
						enter_phase("chase")
					else: enter_phase("teleport_wait")
				else: enter_phase("burst_warning")
	move_and_slide()
	if zone_id == 8 and hp <= float(data.hp)*0.4: enraged = true
	for warning in warnings:
		warning.remaining -= delta
		if warning.remaining <= 0 and warning.at.distance_to(player.global_position) <= SlimerotEncounters.AOE_RADIUS:
			CombatManager.damage_player(data.aoe)
	warnings = warnings.filter(func(w): return w.remaining > 0)
	if enraged:
		aoe_clock += delta
		if aoe_clock >= 4:
			aoe_clock = 0
			warnings.append({"at":player.global_position,"remaining":SlimerotEncounters.AOE_WARNING})

func enter_phase(next: String) -> void:
	phase = next
	phase_time = 0

func fire_spread(count: int, spacing: float) -> void:
	for index in count:
		CombatManager.fire_enemy_projectile(global_position,aim.rotated((index-(count-1)*0.5)*spacing),data.shot,SlimerotEncounters.SHOT_SPEED)

func take_damage(amount: float) -> void:
	if dead: return
	hp = maxf(0,hp-maxf(0,amount))
	if zone_id == 8 and hp <= float(data.hp)*0.4: enraged = true
	if hp == 0:
		dead = true
		defeated.emit()
	queue_redraw()

func _draw() -> void:
	var color := Color("b6987c") if zone_id == 2 else Color("dfbd7d") if zone_id == 4 else Color("b4c586") if zone_id == 6 else Color("bc7be4")
	draw_circle(Vector2(0,15),55,Color(0,0,0,0.3))
	draw_rect(Rect2(-43,-45,86,86),color)
	draw_circle(Vector2(-17,-9),7,Color("251e31"))
	draw_circle(Vector2(17,-9),7,Color("251e31"))
	draw_arc(Vector2.ZERO,57,0,TAU,32,color.lightened(0.4),4)
	if phase == "slam_warning":
		draw_circle(Vector2.ZERO,SlimerotEncounters.SLAM_RADIUS,Color(1,0.25,0.2,0.18))
		draw_arc(Vector2.ZERO,SlimerotEncounters.SLAM_RADIUS,0,TAU,48,Color("ffb987"),5)
	if phase in ["fan_warning","burst_warning"]:
		var count := 5 if phase == "fan_warning" else 3
		var spacing := 0.27 if count == 5 else 0.13
		for index in count: draw_line(Vector2.ZERO,aim.rotated((index-(count-1)*0.5)*spacing)*320,Color(1,0.7,0.3,0.65),4)
	for warning in warnings:
		var point := to_local(warning.at)
		draw_circle(point,SlimerotEncounters.AOE_RADIUS,Color(1,0.2,0.4,0.2))
		draw_arc(point,SlimerotEncounters.AOE_RADIUS+75*clampf(warning.remaining/SlimerotEncounters.AOE_WARNING,0,1),0,TAU,40,Color("ff86b7"),5)
