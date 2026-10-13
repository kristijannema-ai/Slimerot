class_name BLBossController
extends Node2D

signal defeated
signal phase_changed(current: int)
signal attack_started(id: String)
var context: BLContext
var profile: BLProfile
var hp := 18000.0
var phase := 1
var highest_phase := 1
var active := false
var transition_remaining := 0.0
var recovery_remaining := 0.0
var current_attack := "Read the tells"
var current_id := ""
var attacks: Array[BLAttack] = []
var pending_combo: Dictionary = {}
var combo_age := 0.0
var scheduler := BLAttackScheduler.new()
var flash := 0.0
var clock := 0.0
var dead_age := 0.0
var texture: Texture2D
var arena_base := Rect2(40, 220, 640, 760)

func setup(ctx: BLContext, data: BLProfile) -> void:
	cleanup()
	context = ctx
	profile = data
	hp = profile.max_hp
	phase = 1
	highest_phase = 1
	active = true
	dead_age = 0.0
	transition_remaining = 0.65
	recovery_remaining = 0.0
	current_attack = "Ready : " + profile.display_name
	scheduler.reset()
	arena_base = Rect2(40, 220, 640, 760)
	context.arena = arena_base
	context.player.bounds = arena_base
	context.phase = 1
	texture = load("res://assets/" + data.id + ".svg")
	modulate = Color.WHITE
	scale = Vector2.ONE
	global_position = Vector2(360, 415)
	z_index = 4

func cleanup() -> void:
	for attack in attacks: attack.cleanup()
	attacks.clear()
	pending_combo.clear()
	current_id = ""
	if context != null: context.clear()

func take_damage(amount: float) -> void:
	if not active or transition_remaining > 0.0: return
	hp = maxf(0.0, hp - amount)
	flash = 0.09
	if hp <= 0.0:
		active = false
		cleanup()
		context.fx(global_position, profile.accent, 36)
		context.shake(1.2)
		defeated.emit()
		return
	var next_phase := profile.phase_for(hp / profile.max_hp)
	if next_phase > phase: change_phase(next_phase)

func change_phase(value: int) -> void:
	cleanup()
	phase = clampi(value, 1, profile.phase_thresholds.size() + 1)
	highest_phase = maxi(highest_phase, phase)
	context.phase = phase
	transition_remaining = 0.9
	current_attack = "PHASE %d : get ready" % phase
	var inset := float(profile.phase_arena_insets.get(phase, 0.0))
	context.arena = arena_base.grow(-inset)
	context.player.bounds = context.arena
	context.player.global_position = context.clamp_point(context.player.global_position, context.balanced.player_radius)
	global_position = context.clamp_point(global_position, 45)
	context.fx(global_position, profile.accent, 28)
	context.shake(0.8)
	phase_changed.emit(phase)

func force_phase(value: int) -> void:
	var target := clampi(value, 1, profile.phase_thresholds.size() + 1)
	hp = profile.max_hp if target == 1 else profile.max_hp * (profile.phase_thresholds[target - 2] - 0.002)
	change_phase(target)

func start_attack(id: String, overrides: Dictionary = {}) -> void:
	if not profile.attacks.has(id): return
	var data: Dictionary = profile.attacks[id]
	var attack: BLAttack = data.script.new()
	attack.setup(context, phase)
	attack.attack_id = id
	attack.display_name = data.get("name", id.replace("_", " ").capitalize())
	attack.params = data.get("params", {}).duplicate(true)
	attack.params.merge(profile.attack_overrides.get(id, {}), true)
	attack.params.merge(overrides, true)
	attack.begin()
	attacks.append(attack)
	current_id = id
	current_attack = " + ".join(attacks.map(func(item): return item.display_name))
	attack_started.emit(id)

func force_attack(id: String = "") -> void:
	cleanup()
	transition_remaining = 0.0
	recovery_remaining = 0.0
	var chosen := scheduler.choose(profile, phase, context.rng) if id.is_empty() else id
	start_attack(chosen)
	scheduler.remember(profile, chosen)

func step(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	if not active:
		dead_age += delta
		if hp <= 0.0: scale = Vector2.ONE * maxf(0.15, 1.0 - dead_age * 1.7)
		queue_redraw()
		return
	if transition_remaining > 0.0:
		transition_remaining = maxf(0.0, transition_remaining - delta)
		queue_redraw()
		return
	if not pending_combo.is_empty():
		combo_age += delta
		if combo_age >= float(pending_combo.get("delay", 1.0)):
			start_attack(pending_combo.secondary, pending_combo.get("secondary_params", {}))
			pending_combo.clear()
	for index in range(attacks.size() - 1, -1, -1):
		attacks[index].tick(delta)
		if attacks[index].ended:
			var phase_recovery := profile.phase_recovery[mini(phase - 1, profile.phase_recovery.size() - 1)]
			recovery_remaining = minf(phase_recovery, attacks[index].recovery)
			attacks[index].cleanup()
			attacks.remove_at(index)
	if attacks.is_empty() and pending_combo.is_empty():
		recovery_remaining = maxf(0.0, recovery_remaining - delta)
		if recovery_remaining <= 0.0:
			var id := scheduler.choose(profile, phase, context.rng)
			pending_combo = scheduler.companion(profile, id, phase, context.rng)
			combo_age = 0.0
			start_attack(id, pending_combo.get("primary_params", {}))
			scheduler.remember(profile, id)
	queue_redraw()

func _draw() -> void:
	if profile == null: return
	var pulse := 1.0 + sin(clock * 5.0) * 0.025
	draw_circle(Vector2(0, 24), 43, Color(0, 0, 0, 0.32))
	draw_arc(Vector2.ZERO, 53, 0, TAU, 40, Color(profile.accent, 0.5), 2, true)
	if texture != null: draw_texture_rect(texture, Rect2(Vector2(-55, -64) * pulse, Vector2(110, 110) * pulse), false, Color.WHITE if flash <= 0 else Color("fff3c3"))
	if transition_remaining > 0:
		draw_arc(Vector2.ZERO, 60 + (0.9 - transition_remaining) * 55, 0, TAU, 64, Color(profile.accent, transition_remaining * 0.7), 5, true)

