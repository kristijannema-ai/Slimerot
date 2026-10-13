extends RefCounted
## Production attacks and pools are exercised directly: no replacement combat model.

const STEP := 1.0 / 60.0
var casts := 0
var combo_casts := 0
var safe_samples := 0
var peak_hazards := 0
var peak_projectiles := 0

func run(session: BLSession, runner: Object) -> void:
	var original_id := session.selected.id
	var original_mode := session.mode
	var original_seed := session.seed
	var original_dps := session.dps_preset
	var original_god := session.god_mode
	var original_phase := session.configured_phase
	session.running = false
	session.controller.active = false
	session.player.god_mode = true
	runner.check(not session.stats.persistence_enabled, "Pattern tests cannot write local player attempt history")
	for profile in session.profiles:
		for current_phase in range(1, profile.phase_thresholds.size() + 2):
			_test_scheduler(profile, current_phase, runner)
			for attack_id in profile.attacks:
				if int(profile.attacks[attack_id].min_phase) > current_phase:
					continue
				for seed_value in [31017, 90210]:
					_test_cast(session, runner, profile, current_phase, attack_id, seed_value)
		for combo in profile.combos:
			_test_combo(session, runner, profile, combo)
	_test_resource_overrides(session, runner)
	_test_last_volley_travel(session, runner)
	_test_moving_horizon(session, runner)
	_test_capacities(session, runner)
	session.controller.cleanup()
	session.selected = session.profiles.filter(func(item): return item.id == original_id)[0]
	session.arena.profile = session.selected
	session.controller.setup(session.context, session.selected)
	session.controller.active = false
	session.mode = original_mode
	session.seed = original_seed
	session.dps_preset = original_dps
	session.god_mode = original_god
	session.configured_phase = original_phase
	session.player.reset()
	session.player.global_position = Vector2(360, 850)
	print("PATTERN COVERAGE: %d casts, %d authored combos, %d safe-cell samples; peaks %d hazards / %d projectiles" % [casts, combo_casts, safe_samples, peak_hazards, peak_projectiles])

func _prepare(session: BLSession, profile: BLProfile, current_phase: int, seed_value: int) -> void:
	session.controller.setup(session.context, profile)
	session.controller.force_phase(current_phase)
	session.controller.active = false
	session.context.rng.seed = seed_value
	session.player.reset()
	session.player.god_mode = true
	session.player.global_position = session.context.clamp_point(Vector2(360, 850), 24)
	session.player.velocity = Vector2(180, 0)
	session.context.effects.clear()

func _test_cast(session: BLSession, runner: Object, profile: BLProfile, current_phase: int, attack_id: String, seed_value: int) -> void:
	_prepare(session, profile, current_phase, seed_value)
	var context := session.context
	var definition: Dictionary = profile.attacks[attack_id]
	var attack: BLAttack = definition.script.new()
	attack.setup(context, current_phase)
	attack.attack_id = attack_id
	attack.display_name = definition.get("name", attack_id.replace("_", " ").capitalize())
	attack.params = definition.get("params", {}).duplicate(true)
	attack.params.merge(profile.attack_overrides.get(attack_id, {}), true)
	var nodes_before := _node_count(session)
	attack.begin()
	var warnings_valid := true
	var attribution_valid := true
	var safe_geometry := true
	var pool_bounds_valid := true
	var time := 0.0
	var next_sample := 0.0
	while not attack.ended and time < 20.0:
		attack.tick(STEP)
		context.step(STEP)
		time += STEP
		for hazard in context.hazards.slots:
			if hazard.is_empty(): continue
			if int(hazard.damage) > 0:
				warnings_valid = warnings_valid and float(hazard.warning) >= 0.25
				attribution_valid = attribution_valid and not str(hazard.get("attack", "")).is_empty()
			if hazard.has("slow"):
				warnings_valid = warnings_valid and float(hazard.slow) >= 0.38
		for projectile in context.projectiles.slots:
			if not projectile.is_empty() and int(projectile.damage) > 0:
				attribution_valid = attribution_valid and not str(projectile.attack).is_empty()
		pool_bounds_valid = pool_bounds_valid and context.hazards.count_active() <= session.balance.hazard_capacity and context.projectiles.count_active() <= session.balance.projectile_capacity
		if time >= next_sample:
			safe_geometry = safe_geometry and _has_safe_cell(context)
			safe_samples += 1
			next_sample += 0.20
	peak_hazards = maxi(peak_hazards, context.hazards.peak)
	peak_projectiles = maxi(peak_projectiles, context.projectiles.peak)
	attack.cleanup()
	var label := "%s phase %d seed %d" % [attack_id, current_phase, seed_value]
	runner.check(attack.ended and time < 20.0, label + " finishes without a timer hang")
	runner.check(warnings_valid, label + " damage warns and slowing preserves control")
	runner.check(attribution_valid, label + " damaging sources retain death attribution")
	runner.check(safe_geometry, label + " retains a player-sized safe cell throughout")
	runner.check(pool_bounds_valid, label + " respects fixed combat pool capacities")
	runner.check(context.hazards.count_active() == 0 and context.projectiles.count_active() == 0 and context.moves.is_empty(), label + " cleans its hazards, projectiles, and boss motion")
	runner.check(is_zero_approx(context.darkness), label + " restores normal visibility on cleanup")
	runner.check(_node_count(session) == nodes_before, label + " does not create unmanaged scene nodes")
	casts += 1

func _test_scheduler(profile: BLProfile, current_phase: int, runner: Object) -> void:
	var scheduler := BLAttackScheduler.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41711 + current_phase
	var previous := ""
	var previous_was_major := false
	var counts: Dictionary = {}
	var valid := true
	var repetition_valid := true
	var companions_valid := true
	for index in 160:
		var chosen := scheduler.choose(profile, current_phase, rng)
		valid = valid and profile.attacks.has(chosen)
		if not profile.attacks.has(chosen): break
		var definition: Dictionary = profile.attacks[chosen]
		valid = valid and int(definition.min_phase) <= current_phase
		repetition_valid = repetition_valid and chosen != previous
		if previous_was_major and bool(definition.get("major", false)):
			repetition_valid = repetition_valid and chosen != previous
		var companion := scheduler.companion(profile, chosen, current_phase, rng)
		if not companion.is_empty():
			var authored := false
			for combo in profile.combos:
				if combo.primary == chosen and combo.secondary == companion.secondary and int(combo.get("min_phase", 2)) <= current_phase:
					authored = true
			companions_valid = companions_valid and authored and profile.attacks.has(companion.secondary)
			if profile.attacks.has(companion.secondary):
				companions_valid = companions_valid and int(profile.attacks[companion.secondary].min_phase) <= current_phase
		counts[chosen] = int(counts.get(chosen, 0)) + 1
		previous = chosen
		previous_was_major = bool(definition.get("major", false))
		scheduler.remember(profile, chosen)
	var periodic := true
	for attack_id in profile.attacks:
		var definition: Dictionary = profile.attacks[attack_id]
		var weights: Array = definition.get("phase_weights", [])
		var weight := float(weights[mini(current_phase - 1, weights.size() - 1)]) if not weights.is_empty() else float(definition.get("weight", 1.0))
		if int(definition.min_phase) <= current_phase and weight > 0.0:
			periodic = periodic and int(counts.get(attack_id, 0)) >= 2
	var label := "%s scheduler phase %d" % [profile.id, current_phase]
	runner.check(valid, label + " only selects unlocked attacks")
	runner.check(repetition_valid, label + " avoids consecutive same attacks/majors")
	runner.check(companions_valid, label + " only selects authored unlocked companions")
	runner.check(periodic, label + " permits every eligible move to recur")

func _test_combo(session: BLSession, runner: Object, profile: BLProfile, combo: Dictionary) -> void:
	var current_phase := int(combo.get("min_phase", 2))
	_prepare(session, profile, current_phase, 31017)
	var controller := session.controller
	controller.cleanup()
	controller.active = true
	controller.transition_remaining = 0.0
	controller.recovery_remaining = 0.0
	controller.start_attack(combo.primary, combo.get("primary_params", {}))
	controller.pending_combo = combo.duplicate(true)
	controller.combo_age = 0.0
	var nodes_before := _node_count(session)
	var time := 0.0
	var next_sample := 0.0
	var largest_concurrent := 1
	var authored_only := true
	var safe_geometry := true
	while time < 20.0:
		controller.step(STEP)
		session.context.step(STEP)
		time += STEP
		largest_concurrent = maxi(largest_concurrent, controller.attacks.size())
		for attack in controller.attacks:
			authored_only = authored_only and attack.attack_id in [str(combo.primary), str(combo.secondary)]
		if time >= next_sample:
			safe_geometry = safe_geometry and _has_safe_cell(session.context)
			safe_samples += 1
			next_sample += 0.20
		if controller.attacks.is_empty() and controller.pending_combo.is_empty(): break
	controller.cleanup()
	controller.active = false
	var label := "%s authored %s + %s" % [profile.id, combo.primary, combo.secondary]
	runner.check(time < 20.0, label + " ends without a scheduler hang")
	runner.check(largest_concurrent == 2 and authored_only, label + " has at most its two compatible attack modules")
	runner.check(safe_geometry, label + " preserves player-sized safe cells")
	runner.check(session.context.hazards.count_active() == 0 and session.context.projectiles.count_active() == 0 and session.context.moves.is_empty(), label + " cleans every source after completion")
	runner.check(_node_count(session) == nodes_before, label + " has no unmanaged scene-node growth")
	combo_casts += 1

func _test_capacities(session: BLSession, runner: Object) -> void:
	var context := session.context
	context.clear()
	var nodes_before := _node_count(session)
	var hazard_rejects := 0
	var shot_rejects := 0
	for index in session.balance.hazard_capacity * 2:
		if context.hazard({"kind":"circle", "origin":context.arena.position + Vector2(50,50), "radius":10.0,
			"warning":0.50, "active":0.20, "damage":1, "attack":"Capacity probe", "owner":"capacity"}) == -1:
			hazard_rejects += 1
	for index in session.balance.projectile_capacity * 2:
		if context.projectiles.add(context.arena.position + Vector2(50,50), Vector2.DOWN, 0.0, 1, "Capacity probe", "capacity", {}) == -1:
			shot_rejects += 1
	context.effects.burst(context.arena.get_center(), Color.WHITE, session.balance.fx_capacity * 4)
	runner.check(context.hazards.count_active() == session.balance.hazard_capacity and hazard_rejects == session.balance.hazard_capacity, "Hazard overload rejects excess without growing its fixed pool")
	runner.check(context.projectiles.count_active() == session.balance.projectile_capacity and shot_rejects == session.balance.projectile_capacity, "Projectile overload rejects excess without growing its fixed pool")
	runner.check(context.effects.count_active() == session.balance.fx_capacity, "FX overload remains capped")
	runner.check(_node_count(session) == nodes_before, "Combat pool overload does not create scene nodes")
	context.cleanup("capacity")
	context.effects.step(0.50)
	runner.check(context.hazards.count_active() == 0 and context.projectiles.count_active() == 0 and context.effects.count_active() == 0, "Overloaded pools fully drain and can be reused")

func _test_resource_overrides(session: BLSession, runner: Object) -> void:
	var espresso: BLProfile = session.profiles.filter(func(item): return item.id == "espresso")[0]
	var sand: BLProfile = session.profiles.filter(func(item): return item.id == "sand")[0]
	var original_espresso := espresso.attack_overrides.duplicate(true)
	var original_sand := sand.attack_overrides.duplicate(true)
	espresso.attack_overrides["espresso_slam"] = {"tell":1.10, "impact_damage":31, "impact_radius":135.0}
	_prepare(session, espresso, 1, 31017)
	session.controller.force_attack("espresso_slam")
	var slam: Dictionary = session.context.hazards.slots.filter(func(item): return not item.is_empty() and item.kind == "circle")[0]
	runner.check(is_equal_approx(slam.warning, 1.10) and int(slam.damage) == 31 and is_equal_approx(slam.radius, 135.0), "Espresso .tres override changes actual Slam warning, damage, and geometry")
	espresso.attack_overrides["espresso_shots"] = {"tell":0.65, "projectile_damage":7, "speed":175.0, "count":4, "puddle_damage":6}
	_prepare(session, espresso, 2, 31017)
	session.controller.force_attack("espresso_shots")
	var attack: BLAttack = session.controller.attacks[0]
	for index in 42:
		attack.tick(STEP)
		session.context.step(STEP)
	var shots: Array[Dictionary] = session.context.projectiles.slots.filter(func(item): return not item.is_empty())
	var tuned := shots.size() == 4
	for shot in shots:
		tuned = tuned and int(shot.damage) == 7 and is_equal_approx(shot.speed, 175.0) and int(shot.params.puddle_damage) == 6
	runner.check(tuned, "Espresso .tres override changes actual fan count, speed, damage, and impact parameters")
	for index in session.context.projectiles.slots.size():
		if not session.context.projectiles.slots[index].is_empty():
			session.context.projectiles.expire(index, true)
			break
	var puddles: Array[Dictionary] = session.context.hazards.slots.filter(func(item): return not item.is_empty() and str(item.get("attack", "")).ends_with(" puddle"))
	runner.check(puddles.size() == 1 and int(puddles[0].damage) == 6, "Espresso .tres impact damage override reaches the spawned puddle hazard")
	sand.attack_overrides["sand_wall"] = {"tell":1.20, "damage":17, "gap_width":180.0, "width":40.0, "speed":90.0}
	_prepare(session, sand, 2, 31017)
	session.controller.force_attack("sand_wall")
	var wall: Dictionary = session.context.hazards.slots.filter(func(item): return not item.is_empty() and item.kind == "wall")[0]
	var gap: Vector2 = wall.gaps[0]
	runner.check(is_equal_approx(wall.warning, 1.20) and int(wall.damage) == 17 and is_equal_approx(wall.width, 40.0) and is_equal_approx(absf(wall.velocity.y), 90.0) and is_equal_approx(gap.y - gap.x, 180.0), "Sand .tres override changes actual moving Wall geometry, speed, warning, and damage")
	sand.attack_overrides["quicksand_nodes"] = {"slow":0.75, "radius":80.0, "projectile_damage":8}
	_prepare(session, sand, 1, 31017)
	session.controller.force_attack("quicksand_nodes")
	var fields: Array[Dictionary] = session.context.hazards.slots.filter(func(item): return not item.is_empty() and item.kind == "field")
	var fields_tuned := fields.size() == 3
	for field in fields:
		fields_tuned = fields_tuned and is_equal_approx(field.slow, 0.75) and is_equal_approx(field.radius, 80.0) and "75%" in str(field.label)
	runner.check(fields_tuned, "Quicksand .tres override changes actual movement and readable field labels")
	espresso.attack_overrides = original_espresso
	sand.attack_overrides = original_sand
	session.controller.cleanup()

func _has_safe_cell(context: BLContext) -> bool:
	var margin := context.balanced.player_radius + 3.0
	var point := context.arena.position + Vector2.ONE * margin
	while point.y < context.arena.end.y - margin:
		point.x = context.arena.position.x + margin
		while point.x < context.arena.end.x - margin:
			var free := true
			for hazard in context.hazards.slots:
				if hazard.is_empty() or int(hazard.damage) <= 0 or float(hazard.age) < float(hazard.warning): continue
				if context.hazards.contains(hazard, point, context.balanced.player_radius):
					free = false
					break
			if free:
				for projectile in context.projectiles.slots:
					if projectile.is_empty() or int(projectile.damage) <= 0: continue
					if Vector2(projectile.position).distance_to(point) <= context.balanced.player_radius + float(projectile.params.get("radius", 8.0)):
						free = false
						break
			if free: return true
			point.x += 32.0
		point.y += 32.0
	return false

func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children(): total += _node_count(child)
	return total

func _test_last_volley_travel(session: BLSession, runner: Object) -> void:
	var admin: BLProfile = session.profiles.filter(func(item): return item.id == "admin")[0]
	var janitor: BLProfile = session.profiles.filter(func(item): return item.id == "janitor")[0]
	var cases: Array[Dictionary] = [
		{"profile":admin, "id":"gravity_well", "phases":[1,4], "sequence":2},
		{"profile":admin, "id":"freeze_fields", "phases":[2,4], "sequence":1},
		{"profile":admin, "id":"collapse", "phases":[3,4], "sequence":1},
		{"profile":admin, "id":"orbital_projectiles", "phases":[1,4], "sequence":-1},
		{"profile":admin, "id":"event_horizon", "phases":[3,4], "sequence":2},
		{"profile":janitor, "id":"cleaning_cart", "phases":[1,3], "sequence":0}
	]
	for entry in cases:
		for current_phase in entry.phases:
			_prepare(session, entry.profile, current_phase, 31017)
			var context := session.context
			var definition: Dictionary = entry.profile.attacks[entry.id]
			var attack: BLAttack = definition.script.new()
			attack.setup(context,current_phase)
			attack.attack_id = entry.id
			attack.display_name = definition.get("name",entry.id)
			attack.params = definition.get("params",{}).duplicate(true)
			attack.params.merge(entry.profile.attack_overrides.get(entry.id,{}),true)
			session.player.velocity = Vector2.ZERO
			session.player.global_position = Vector2(360,850) if entry.id=="cleaning_cart" else context.arena.end-Vector2.ONE*context.balanced.player_radius
			attack.begin()
			var last_sequence := int(entry.sequence)
			if entry.id=="orbital_projectiles":last_sequence=7 if current_phase>=3 else 5
			var tracked: Dictionary = {}
			var reached := false
			var time := 0.0
			while not attack.ended and time<20.0:
				time+=STEP
				# Start the Cart at the bottom, then test its final upward bottles against
				# a distant upper-edge player. This follows the final volley, not an earlier hit.
				if entry.id=="cleaning_cart" and time>2.90:
					session.player.global_position=Vector2(context.arena.end.x-35.0,context.arena.position.y+context.balanced.player_radius)
				attack.tick(STEP)
				if tracked.is_empty():
					for shot in context.projectiles.slots:
						if shot.is_empty() or int(shot.params.get("sequence",-99))!=last_sequence:continue
						var expected: Vector2=(session.player.global_position-Vector2(shot.position)).normalized()
						if float(shot.params.get("orbit_time",0.0))>0.0 or Vector2(shot.direction).dot(expected)>0.999:
							tracked=shot
							break
				context.step(STEP)
				if not tracked.is_empty() and float(tracked.age)>=float(tracked.params.get("orbit_time",0.0)):
					var closest := Geometry2D.get_closest_point_to_segment(session.player.global_position,tracked.previous,tracked.position)
					reached=reached or closest.distance_to(session.player.global_position)<=context.balanced.player_radius+float(tracked.params.get("radius",8.0))+0.01
			var label: String="%s phase%d final volley"%[entry.id,current_phase]
			runner.check(not tracked.is_empty() and reached,label+" reaches the distant player through actual pooled projectile flight before cleanup")
			runner.check(attack.ended and time<20.0,label+" keeps a finite bounded travel tail")
			attack.cleanup()
			runner.check(context.hazards.count_active()==0 and context.projectiles.count_active()==0,label+" owner cleanup still drains every projectile and hazard")
			_test_near_recovery(session,runner,entry.profile,current_phase,entry.id)

func _test_moving_horizon(session: BLSession, runner: Object) -> void:
	var admin: BLProfile=session.profiles.filter(func(item):return item.id=="admin")[0]
	for current_phase in [3,4]:
		_prepare(session,admin,current_phase,31017)
		var context:=session.context
		var definition: Dictionary=admin.attacks.event_horizon
		var attack: BLAttack=definition.script.new()
		attack.setup(context,current_phase)
		attack.attack_id="event_horizon"
		attack.display_name=definition.name
		attack.params=definition.params.duplicate(true)
		attack.params.merge(admin.attack_overrides.get("event_horizon",{}),true)
		attack.begin()
		var field:Dictionary=context.hazards.slots.filter(func(item):return not item.is_empty() and item.kind=="annulus")[0]
		var usable_half:=float(field.width)*0.5-context.balanced.player_radius
		var initial_outer:=float(field.safe_radius)+usable_half
		var final_inner:=float(field.safe_radius)+float(field.growth)*float(field.active)-usable_half
		runner.check(final_inner>initial_outer,"Event Horizon phase%d has no stationary-safe radial intersection over its active lifetime"%current_phase)
		var playable:=context.arena.grow(-context.balanced.player_radius)
		var maximum_distance:=0.0
		for corner in [playable.position,Vector2(playable.end.x,playable.position.y),playable.end,Vector2(playable.position.x,playable.end.y)]:
			maximum_distance=maxf(maximum_distance,Vector2(field.origin).distance_to(corner))
		var needed_inward:=maxf(0.0,maximum_distance-initial_outer)
		var walk_budget:=context.balanced.move_speed*float(field.warning)
		runner.check(needed_inward<=walk_budget,"Event Horizon phase%d activation band is reachable by walking from the farthest valid corner"%current_phase)
		runner.check(needed_inward<=walk_budget+context.balanced.dash_distance,"Event Horizon phase%d also preserves the warned Dash response budget"%current_phase)
		runner.check(final_inner+context.balanced.player_radius<minf(context.arena.size.x,context.arena.size.y)*0.5,"Event Horizon phase%d final safe ring retains paths around the arena center"%current_phase)
		attack.cleanup()

func _test_near_recovery(session: BLSession, runner: Object, profile: BLProfile, current_phase: int, attack_id: String) -> void:
	_prepare(session,profile,current_phase,31017)
	var context:=session.context
	var definition:Dictionary=profile.attacks[attack_id]
	var attack:BLAttack=definition.script.new()
	attack.setup(context,current_phase)
	attack.attack_id=attack_id
	attack.display_name=definition.get("name",attack_id)
	attack.params=definition.get("params",{}).duplicate(true)
	attack.params.merge(profile.attack_overrides.get(attack_id,{}),true)
	session.player.velocity=Vector2.ZERO
	session.player.global_position=Vector2(360,850) if attack_id=="cleaning_cart" else context.boss.global_position+Vector2(0,20)
	attack.begin()
	if attack_id=="cleaning_cart":session.player.global_position=Vector2(context.arena.end.x-35.0,830.0)
	# A companion's harmless marker must not force this cleared owner to wait.
	context.hazard({"kind":"circle","origin":context.arena.get_center(),"radius":20.0,"warning":0.5,"active":18.0,"damage":0,"attack":"Companion marker","owner":"other-owner"})
	var time:=0.0
	while not attack.ended and time<20.0:
		attack.tick(STEP)
		context.step(STEP)
		time+=STEP
	var label:="%s phase%d near-flight recovery"%[attack_id,current_phase]
	runner.check(attack.ended and time<attack.duration-0.25,label+" recovers after real nearby shots hit/leave without a silent maximum-distance tail")
	runner.check(context.hazards.slots.any(func(item):return not item.is_empty() and str(item.get("owner",""))=="other-owner"),label+" is not delayed by another owner's marker")
	attack.cleanup()
	context.cleanup("other-owner")
	runner.check(context.hazards.count_active()==0 and context.projectiles.count_active()==0,label+" still leaves bounded pools empty after cleanup")
