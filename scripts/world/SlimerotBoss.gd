class_name SlimerotBoss
extends CharacterBody2D

signal defeated

# Warnings lock their geometry before becoming dangerous. A long frame advances
# only one phase, so it can never skip an entire warning on a slow phone.
const FADE_OUT_SECONDS := 0.35
const TELEPORT_MARKER_SECONDS := 0.65
const FADE_IN_SECONDS := 0.40
const BURST_WARNING_SECONDS := 0.65
const BEAM_WARNING_SECONDS := 1.05
const BEAM_ACTIVE_SECONDS := 0.40
const CHARGE_WARNING_SECONDS := 1.0
const CHARGE_SPEED := 700.0
const CHARGE_DISTANCE := 360.0
const SAFE_GAP_WIDTH := 300.0

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
var sprite: Texture2D
var hit_flash := 0.0
var beam_segments: Array[Dictionary] = []
var beam_stage := 0
var beam_hit := false
var fan_count := 5
var fan_spacing := 0.28
var teleport_destination := Vector2.ZERO
var charge_start := Vector2.ZERO
var charge_end := Vector2.ZERO
var charge_hit := false
var slam_impacts := 0
var pattern_cycle := 0

func _ready() -> void:
	data = SlimerotEncounters.BOSSES[zone_id]
	sprite = SlimerotAssets.boss(zone_id)
	hp = data.hp
	phase = "teleport_wait" if zone_id == 6 else "chase"
	collision_layer = 8 # Separate from normal enemies: Shooter friendly fire excludes bosses.
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
	hit_flash = maxf(0.0, hit_flash - delta)
	step(delta)
	queue_redraw()

func step(delta: float) -> void:
	var player := CombatManager.player
	if dead or not is_instance_valid(player) or GameState.player_dead: return
	contact_remaining = maxf(0, contact_remaining - delta)
	phase_time += delta
	cycle_time += delta
	velocity = Vector2.ZERO
	_update_warnings(delta)
	if zone_id == 8 and hp <= float(data.hp) * 0.4: enraged = true
	if enraged: aoe_clock += delta
	if zone_id == 2: _step_espresso(player)
	elif phase.begins_with("teleport_") or phase.begins_with("burst_"): _step_teleport(player)
	else: _step_ranged(player)
	move_and_slide()
	# Arrival and warnings never deal an unannounced contact hit.
	if phase == "chase" and global_position.distance_to(player.global_position) < 62 and contact_remaining == 0:
		contact_remaining = 1.0
		CombatManager.damage_player(data.contact)
	queue_redraw()

func _step_espresso(player: Node2D) -> void:
	match phase:
		"chase":
			attack_label = "ESPRESSO COMBO · make room"
			velocity = global_position.direction_to(player.global_position) * float(data.speed)
			if phase_time >= 3.0:
				slam_impacts = 0
				enter_phase("slam_warning")
		"slam_warning", "combo_warning":
			attack_label = "SLAM RING · Dash out" if phase == "slam_warning" else "SECOND SLAM · keep moving"
			var duration := 0.8 if phase == "slam_warning" else 0.65
			if phase_time >= duration:
				if global_position.distance_to(player.global_position) <= SlimerotEncounters.SLAM_RADIUS: CombatManager.damage_player(data.slam)
				slam_impacts += 1
				enter_phase("slam_release")
		"slam_release":
			attack_label = "IMPACT"
			if phase_time >= 0.22:
				if slam_impacts < 2: enter_phase("combo_warning")
				else:
					aim = global_position.direction_to(player.global_position)
					charge_start = global_position
					var endpoint := (position + aim * CHARGE_DISTANCE).clamp(Vector2(95, 110), Vector2(805, 1080))
					charge_end = get_parent().to_global(endpoint)
					aim = charge_start.direction_to(charge_end)
					charge_hit = false
					enter_phase("charge_warning")
		"charge_warning":
			attack_label = "CHARGE LANE · Dash sideways"
			if phase_time >= CHARGE_WARNING_SECONDS: enter_phase("charge")
		"charge":
			attack_label = "CHARGE"
			var travelled := charge_start.distance_to(global_position)
			var distance := charge_start.distance_to(charge_end)
			velocity = aim * CHARGE_SPEED
			if not charge_hit and global_position.distance_to(player.global_position) < 62:
				charge_hit = _try_player_damage(data.slam)
			if travelled >= distance - 8 or phase_time >= distance / CHARGE_SPEED:
				velocity = Vector2.ZERO
				enter_phase("recovery")
		"recovery":
			attack_label = "COOLING DOWN · attack!"
			if phase_time >= 1.25:
				pattern_cycle += 1
				enter_phase("chase")

func _step_ranged(player: Node2D) -> void:
	match phase:
		"chase":
			attack_label = "FINAL PROTOCOL · fan next" if enraged else "FAN FORMING · leave a gap"
			velocity = global_position.direction_to(player.global_position) * float(data.speed)
			if phase_time >= (1.8 if enraged else 3.2):
				aim = global_position.direction_to(player.global_position)
				fan_count = 7 if enraged else 5
				fan_spacing = 0.25 if enraged else 0.28
				enter_phase("fan_warning")
		"fan_warning":
			attack_label = "FAN · move between the marked lanes"
			if phase_time >= 0.8:
				fire_spread(fan_count, fan_spacing)
				enter_phase("fan_release")
		"fan_release":
			if phase_time >= 0.3:
				if zone_id == 8:
					admin_teleport = true
					enter_phase("teleport_wait")
				else:
					beam_stage = 0
					_prepare_beams(player, false)
					enter_phase("beam_warning")
		"beam_warning", "sweep_warning":
			attack_label = "SAFE ZONE SHIFT · follow the open floor" if zone_id == 6 else "BEAM LANE · Dash across the warning"
			if phase_time >= (BEAM_WARNING_SECONDS if phase == "beam_warning" else 0.9):
				beam_hit = false
				enter_phase("beam_active")
		"beam_active":
			attack_label = "LIVE BEAM · keep clear"
			if phase_time < BEAM_ACTIVE_SECONDS and not beam_hit and beam_contains(player.global_position):
				beam_hit = _try_player_damage(float(data.shot))
			if phase_time >= BEAM_ACTIVE_SECONDS:
				if beam_stage == 0:
					beam_stage = 1
					_prepare_beams(player, true)
					enter_phase("sweep_warning")
				else:
					beam_segments.clear()
					enter_phase("recovery")
		"recovery":
			attack_label = "RECOVERY · attack!"
			if phase_time >= 1.4:
				pattern_cycle += 1
				admin_teleport = false
				enter_phase("teleport_wait" if zone_id == 6 else "chase")

func _step_teleport(player: Node2D) -> void:
	match phase:
		"teleport_wait":
			var wait_seconds := 1.2 if zone_id == 8 else 2.2
			attack_label = "DISTORTION · teleport approaching"
			if phase_time >= wait_seconds:
				var candidates := SlimerotEncounters.TELEPORT_POINTS
				teleport_destination = candidates[teleport_index % candidates.size()]
				for offset in candidates.size():
					var candidate: Vector2 = candidates[(teleport_index + offset) % candidates.size()]
					if get_parent().to_global(candidate).distance_to(player.global_position) >= 210:
						teleport_destination = candidate
						break
				bursts_fired = 0
				enter_phase("teleport_fadeout")
		"teleport_fadeout":
			attack_label = "FADING · find the arrival marker"
			if phase_time >= FADE_OUT_SECONDS: enter_phase("teleport_marker")
		"teleport_marker":
			attack_label = "ARRIVAL MARKED · move clear"
			if phase_time >= TELEPORT_MARKER_SECONDS:
				position = teleport_destination
				teleport_index += 1
				enter_phase("teleport_fadein")
		"teleport_fadein":
			attack_label = "MATERIALIZING · burst next"
			if phase_time >= FADE_IN_SECONDS:
				aim = global_position.direction_to(player.global_position)
				enter_phase("burst_warning")
		"burst_warning":
			attack_label = "AIMED BURST · sidestep the locked aim"
			if phase_time >= BURST_WARNING_SECONDS:
				fire_spread(3, 0.18)
				bursts_fired += 1
				enter_phase("burst_release")
		"burst_release":
			if phase_time >= 0.2:
				if bursts_fired < 2:
					aim = global_position.direction_to(player.global_position)
					enter_phase("burst_warning")
				else:
					beam_stage = 0
					_prepare_beams(player, false)
					enter_phase("beam_warning")

func _prepare_beams(player: Node2D, sweep: bool) -> void:
	beam_segments.clear()
	if zone_id == 6:
		# Alternating 300px safe columns shift with an explicit new warning.
		var gap_centre := 330.0 if (pattern_cycle + int(sweep)) % 2 == 0 else 570.0
		var left_edge := gap_centre - SAFE_GAP_WIDTH * 0.5
		var right_edge := gap_centre + SAFE_GAP_WIDTH * 0.5
		_add_beam(Vector2((80 + left_edge) * 0.5, 130), Vector2((80 + left_edge) * 0.5, 1060), left_edge - 80)
		_add_beam(Vector2((right_edge + 820) * 0.5, 130), Vector2((right_edge + 820) * 0.5, 1060), 820 - right_edge)
	else:
		var target: Vector2 = get_parent().to_local(player.global_position)
		if sweep:
			var lane_y := clampf(target.y, 240, 960)
			_add_beam(Vector2(95, lane_y), Vector2(805, lane_y), 74)
		else:
			var lane_x := clampf(target.x, 180, 720)
			_add_beam(Vector2(lane_x, 130), Vector2(lane_x, 1060), 74)

func _add_beam(a: Vector2, b: Vector2, width: float) -> void:
	beam_segments.append({"a":get_parent().to_global(a), "b":get_parent().to_global(b), "width":width})

func beam_contains(point: Vector2) -> bool:
	# Exactly the rectangle used for warning borders and active beam fill.
	for beam in beam_segments:
		var along: Vector2 = beam.b - beam.a
		var offset: Vector2 = point - beam.a
		var projection := offset.dot(along.normalized())
		if projection >= 0 and projection <= along.length() and absf(offset.cross(along.normalized())) <= float(beam.width) * 0.5: return true
	return false

func _update_warnings(delta: float) -> void:
	for warning in warnings:
		warning.remaining -= delta
		if warning.remaining <= 0 and warning.at.distance_to(CombatManager.player.global_position) <= SlimerotEncounters.AOE_RADIUS: CombatManager.damage_player(data.aoe)
	warnings = warnings.filter(func(w): return w.remaining > 0)

func enter_phase(next: String) -> void:
	phase = next
	phase_time = 0
	# Final circles occupy a recovery window, never a teleport/beam overlap.
	if next == "recovery" and enraged and aoe_clock >= 4.0 and is_instance_valid(CombatManager.player):
		aoe_clock = 0.0
		warnings.append({"at":CombatManager.player.global_position, "remaining":SlimerotEncounters.AOE_WARNING})

func _try_player_damage(amount: float) -> bool:
	var before := GameState.player_hp
	CombatManager.damage_player(amount)
	# A dash can avoid this frame of a sustained beam, but cannot disable the
	# rest of its active window by touching it during those i-frames.
	return GameState.player_hp < before

func critical_telegraph_active() -> bool:
	return phase.ends_with("warning") or phase in ["charge", "beam_active", "teleport_fadeout", "teleport_marker", "teleport_fadein"] or not warnings.is_empty()

func teleport_opacity() -> float:
	if phase == "teleport_fadeout": return 1.0 - clampf(phase_time / FADE_OUT_SECONDS, 0, 1)
	if phase == "teleport_marker": return 0.0
	if phase == "teleport_fadein": return clampf(phase_time / FADE_IN_SECONDS, 0, 1)
	return 1.0

func fire_spread(count: int, spacing: float) -> void:
	for index in count:
		CombatManager.fire_enemy_projectile(global_position, aim.rotated((index - (count - 1) * 0.5) * spacing), data.shot, SlimerotEncounters.SHOT_SPEED, self, false, zone_id)

func take_damage(amount: float) -> void:
	if dead: return
	hp = maxf(0, hp - maxf(0, amount))
	if amount > 0.0:
		hit_flash = 0.10
		SlimerotSound.play_cue("hit")
		if is_instance_valid(CombatManager.feedback): CombatManager.feedback.boss_hit(global_position)
	if zone_id == 8 and hp <= float(data.hp) * 0.4: enraged = true
	if hp == 0:
		dead = true
		warnings.clear()
		beam_segments.clear()
		if is_instance_valid(CombatManager.feedback): CombatManager.feedback.enemy_died(global_position)
		defeated.emit()
	queue_redraw()

func _draw() -> void:
	var color := Color("b6987c") if zone_id == 2 else Color("dfbd7d") if zone_id == 4 else Color("b4c586") if zone_id == 6 else Color("bc7be4")
	_draw_telegraphs(color)
	var opacity := teleport_opacity()
	if opacity <= 0: return
	draw_circle(Vector2(0, 15), 55, Color(0, 0, 0, 0.3 * opacity))
	var bob := sin(cycle_time * 3.5) * 3.0
	var squash := sin(hit_flash / 0.10 * PI) * 0.10
	var distortion := sin(phase_time * 45.0) * 0.08 if phase == "teleport_fadeout" else 0.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0 + squash + distortion, 1.0 - squash))
	if sprite != null:
		var tint := Color(1.5, 1.3, 1.3, opacity) if hit_flash > 0 else Color(1, 1, 1, opacity)
		draw_texture_rect(sprite, Rect2(-72, -84 + bob, 144, 144), false, tint)
	else: draw_circle(Vector2(0, -12), 44, Color(color, opacity))
	draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2.ZERO, 57, 0, TAU, 32, Color(color.lightened(0.4), opacity), 4)

func _draw_telegraphs(color: Color) -> void:
	if dead: return
	if phase in ["slam_warning", "combo_warning", "slam_release"]:
		var duration := 0.8 if phase == "slam_warning" else 0.65
		var progress := clampf(phase_time / duration, 0, 1)
		var impact := phase == "slam_release"
		draw_circle(Vector2.ZERO, SlimerotEncounters.SLAM_RADIUS, Color(1, 0.22, 0.18, 0.40 if impact else 0.16))
		draw_arc(Vector2.ZERO, SlimerotEncounters.SLAM_RADIUS, 0, TAU, 64, Color("ffbd70"), 6)
		if not impact: draw_arc(Vector2.ZERO, SlimerotEncounters.SLAM_RADIUS * progress, 0, TAU, 48, Color("ff7775"), 3)
	if phase in ["charge_warning", "charge"]:
		_draw_lane(charge_start, charge_end, 124, phase == "charge", Color("ffb870"))
		# Contact sweeps a radius-62 capsule; warn its round end caps too.
		for endpoint in [charge_start, charge_end]:
			draw_circle(to_local(endpoint), 62, Color(1, 0.72, 0.44, 0.14))
			draw_arc(to_local(endpoint), 62, 0, TAU, 40, Color("ffb870"), 4, true)
	if phase in ["fan_warning", "burst_warning"]:
		var count := fan_count if phase == "fan_warning" else 3
		var spacing := fan_spacing if phase == "fan_warning" else 0.18
		for index in count:
			var ray := aim.rotated((index - (count - 1) * 0.5) * spacing)
			draw_line(ray * 60, ray * 500, Color(1, 0.75, 0.32, 0.8), 4)
			draw_circle(ray * 75, 7, Color("ffe8a3"))
	for beam in beam_segments: _draw_lane(beam.a, beam.b, beam.width, phase == "beam_active", Color("f9ce76") if zone_id == 4 else Color("e1a9ff"))
	if phase in ["teleport_fadeout", "teleport_marker", "teleport_fadein"]:
		var at := to_local(get_parent().to_global(teleport_destination))
		draw_circle(at, 68, Color(color, 0.20))
		draw_arc(at, 68, 0, TAU, 48, Color("f8e7b5"), 5)
		draw_arc(at, 45 + sin(cycle_time * 12) * 6, 0, TAU, 40, color.lightened(0.35), 3)
		for axis in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]: draw_line(at + axis * 77, at + axis * 94, Color("f8e7b5"), 5)
	for warning in warnings:
		var point := to_local(warning.at)
		draw_circle(point, SlimerotEncounters.AOE_RADIUS, Color(1, 0.2, 0.4, 0.2))
		draw_arc(point, SlimerotEncounters.AOE_RADIUS, 0, TAU, 48, Color("ffaccd"), 5)
		draw_arc(point, SlimerotEncounters.AOE_RADIUS * clampf(warning.remaining / SlimerotEncounters.AOE_WARNING, 0, 1), 0, TAU, 40, Color("ff86b7"), 3)

func _draw_lane(a: Vector2, b: Vector2, width: float, active: bool, color: Color) -> void:
	var side := (b - a).normalized().orthogonal() * width * 0.5
	var points := PackedVector2Array([to_local(a + side), to_local(b + side), to_local(b - side), to_local(a - side)])
	draw_colored_polygon(points, Color(color, 0.65 if active else 0.14))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("fff4d4") if active else color, 5, true)
	if active: draw_line(to_local(a), to_local(b), Color(1, 0.95, 0.86, 0.9), minf(width * 0.30, 14))
	else:
		var direction := (b - a).normalized()
		for distance in range(40, int(a.distance_to(b)), 100):
			var centre := to_local(a + direction * distance)
			draw_line(centre - side * 0.45, centre + side * 0.45, Color(color, 0.5), 3)
