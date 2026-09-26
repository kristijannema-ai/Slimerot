extends Node

const SlimerotPacingModel = preload("res://tools/SlimerotPacingModel.gd")

# Slimerot controlled 60 Hz projectile fixtures plus a real moving/Auto Roll fight.
# Fixture kills measure attack cadence and flight, not human dodging or campaign time.
const STEP := 1.0 / 60.0
const TEAMS := [
	[1, "tung_tung_tung_sahur", 1, []],
	[2, "chimpanzini_bananini", 2, ["C01", "C02"]],
	[3, "tralalero_tralala", 3, ["C01", "C02", "C05", "C06"]],
	[4, "bombardiro_crocodilo", 3, ["C01", "C02", "C05", "C06", "C08", "C09"]],
	[5, "girafa_celestre", 4, ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13"]],
	[6, "la_vaca_saturno_saturnita", 4, ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13"]],
	[7, "talpa_di_ferro", 5, ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13", "C15", "C16", "C17"]],
	[8, "celestial_tralalero", 5, ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13", "C15", "C16", "C17", "C19"]],
]
var suite: Node
var world: Node
var measurements: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	suite.check(value, "Balance · " + label)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	world.hud.joystick.reset()
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)

func fixture(row: Array) -> void:
	fresh()
	var zone: int = row[0]
	GameState.highest_zone_unlocked = zone
	for earlier in range(1, zone): GameState.unlocked_gate_flags[str(earlier)] = true
	for earlier in [2, 4, 6]:
		if earlier < zone: GameState.boss_defeated_flags["zone_%d" % earlier] = true
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	GameState.coins = 10000000
	GameState.coins_earned = GameState.coins
	GameState.lifetime_rolls = 15000
	GameState.rolls_balance = 15000
	if "C19" in row[3]:
		for node in SlimerotRollTree.MAINLINE: SkillTreeManager.purchase(node[0])
	for id in row[3]: check(SkillTreeManager.purchase(id), "fixture purchases available " + id)
	for index in row[2]: InventoryManager.equip(InventoryManager.add_copy(row[1]))
	WorldManager.travel(zone)
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"):
		enemy.set_physics_process(false)
		enemy.dead = true
		enemy.hide()
	# Stationary target, all slime origins in range. No hostile attacks in TTK fixtures.
	world.player.global_position = Vector2(500, 1300)
	CombatManager.reset_combat()

func step_projectiles() -> void:
	CombatManager._physics_process(STEP)
	for shot in CombatManager.get_children():
		if shot is SlimerotProjectile:
			shot._physics_process(STEP)

func measure(target: Node2D, limit: float, firing_uptime: float = 1.0) -> float:
	var seconds := 0.0
	while not target.dead and seconds < limit:
		# A repeating ten-second firing window models time spent dodging/repositioning.
		if fmod(seconds, 10.0) < 10.0 * firing_uptime:
			step_projectiles()
		else:
			for shot in CombatManager.get_children():
				if shot is SlimerotProjectile: shot._physics_process(STEP)
		seconds += STEP
	CombatManager.clear_projectiles()
	return seconds

func run(game_world: Node, owner_suite: Node) -> void:
	world = game_world
	suite = owner_suite
	check(world.get_node_or_null("SlimerotPlaytestLogger") == null, "ordinary test launch has no developer logger")
	GameState.set_process(false)
	RollManager.set_process(false)
	CombatManager.set_physics_process(false)
	test_estimator_isolation()
	test_historical_prices()
	for row in TEAMS:
		fixture(row)
		var enemy := SlimerotEnemy.new()
		enemy.data = SlimerotCampaign.enemy(row[0], "chaser")
		enemy.position = world.player.global_position + Vector2(0, -120)
		world.add_child(enemy)
		enemy.set_physics_process(false)
		var before_coins: int = GameState.coins
		var dps := InventoryManager.team_dps()
		var seconds := measure(enemy, 30.0)
		measurements.append({"kind": "chaser", "zone": row[0], "team": row[1], "copies": row[2], "team_dps": dps, "hp": enemy.data.max_hp, "seconds": seconds})
		check(enemy.dead and seconds >= 2.5 and seconds <= 12.5, "Z%d appropriately geared Chaser dies through real projectiles in %.2fs" % [row[0], seconds])
		check(GameState.coins == before_coins + enemy.data.coin_reward and GameState.zone_kill_counts.get(str(row[0]), 0) == 1, "Z%d measured kill grants its exact reward once" % row[0])
		enemy.free()
		await get_tree().process_frame
	for zone in [2, 4, 6, 8]:
		var row: Array = TEAMS[zone - 1].duplicate(true)
		# Final boss readiness includes an ordinary top Z8 team, not a rare variant.
		if zone == 8: row[1] = "brainrot_singularity"
		fixture(row)
		var boss := SlimerotBoss.new()
		boss.zone_id = zone
		boss.position = world.player.global_position + Vector2(0, -120)
		world.add_child(boss)
		boss.set_physics_process(false)
		var boss_dps := 0.0
		for copy in InventoryManager.equipped_copy_ids: boss_dps += InventoryManager.damage_for_copy(copy, true)
		var seconds := measure(boss, 240.0, 0.70)
		measurements.append({"kind": "boss", "zone": zone, "team": row[1], "copies": row[2], "boss_dps": boss_dps, "hp": boss.data.hp, "seconds": seconds, "firing_uptime": 0.70})
		check(boss.dead and seconds >= 45.0 and seconds <= 180.0, "Z%d ready Normal team at 70%% firing uptime defeats boss projectile fixture in %.2fs" % [zone, seconds])
		boss.free()
		await get_tree().process_frame
	# Unlike the controlled fixtures, this scenario runs the actual scene physics,
	# input, enemy AI, Auto Roll and projectile updates concurrently at normal speed.
	fresh()
	await live_fight()

func test_estimator_isolation() -> void:
	fresh()
	var before := SaveManager.snapshot()
	var rng_state := [RollManager.rng.state, RollManager.variant_rng.state]
	var model := SlimerotPacingModel.new()
	var first := model.run({"seeds": 1, "horizon_minutes": 1.0})
	var repeated := model.run({"seeds": 1, "horizon_minutes": 1.0})
	check(JSON.stringify(first) == JSON.stringify(repeated), "same estimator seed/options/constants produce identical JSON")
	check(before == SaveManager.snapshot() and rng_state == [RollManager.rng.state, RollManager.variant_rng.state], "estimator cannot alter live save fields or either rolling RNG")
	var sampler := RandomNumberGenerator.new()
	var variants := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	var reference_variants := RandomNumberGenerator.new()
	sampler.seed = 9283
	reference.seed = sampler.seed
	variants.seed = 123982
	reference_variants.seed = variants.seed
	var samplers_match := true
	for index in 256:
		var zone := 1 + index % 8
		var luck: float = [1.0, 30.36, 910.8, 28462.5][index % 4]
		var modeled: Dictionary = model._sample(luck, zone, sampler, variants, true)
		var expected := RollManager.select_base(luck, (float(reference.randi()) + 1.0) / 4294967296.0, zone)
		var draws: Array = []
		for bit in 3: draws.append(float(reference_variants.randi()) / 4294967296.0)
		var expected_variant := SlimerotVariants.key(RollManager.select_variant_flags(draws, RollManager.variant_probabilities(true)))
		samplers_match = samplers_match and modeled.slime.id == expected and modeled.variant == expected_variant
	check(samplers_match, "estimator's seeded ordinary/variant sampler agrees with the actual rolling implementation")
	var owned: Dictionary = {}
	var ids: Array[String] = []
	var effects_match := true
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL + SlimerotCoinTree.ROWS:
		owned[row[0]] = true
		ids.append(row[0])
		var estimated: Dictionary = model._stats(owned)
		var actual := SkillTreeManager.derived_stats(ids)
		effects_match = effects_match and is_equal_approx(estimated.luck, actual.luck) and is_equal_approx(estimated.cooldown, actual.roll_cooldown) and estimated.slots == actual.equipped_slots and is_equal_approx(estimated.damage, actual.damage_multiplier) and is_equal_approx(estimated.boss_damage, 1.0 + actual.boss_damage_bonus)
		effects_match = effects_match and is_equal_approx(estimated.minor_roll_tree_product, actual.minor_roll_tree_product) and is_equal_approx(estimated.breakthrough_product, actual.breakthrough_product) and is_equal_approx(estimated.coin_tree_luck_product, actual.coin_tree_luck_product)
		effects_match = effects_match and estimated.super_roll_tier == actual.super_roll_tier and estimated.super_roll_interval == actual.super_roll_interval and estimated.super_roll_multiplier == actual.super_roll_multiplier
		effects_match = effects_match and is_equal_approx(estimated.coin_gain, 1.0 + actual.coin_scavenger) and is_equal_approx(estimated.move_speed, actual.move_speed)
	check(effects_match, "all modeled Roll/Coin effects agree with live derived stats, including Fortune, Super tiers and exact x20 checkpoints")
	for policy in first.policies:
		var counts: Dictionary = policy.summary.milestones.final_boss
		check(counts.observed == 0 and counts.median == null, "%s estimator reports unfinished runs without inventing completion" % policy.policy.id)
	var nodes: Array = first.policies[0].clock.nodes
	var previous_checkpoint_minutes := 0.0
	for id in ["R08", "R13", "R18"]:
		var found: Array = nodes.filter(func(row): return row.id == id)
		check(found.size() == 1 and found[0].minutes > previous_checkpoint_minutes, "%s uninterrupted mainline clock preserves ordered positive checkpoint timing" % id)
		if not found.is_empty(): previous_checkpoint_minutes = found[0].minutes

func test_historical_prices() -> void:
	fixture(TEAMS[7])
	var old := SaveManager.snapshot()
	var current_paid: int = old.roll_skill_spend.R08 + old.roll_skill_spend.R13
	old.roll_skill_spend.R08 = 800
	old.roll_skill_spend.R13 = 1000
	old.rolls_balance += current_paid - 1800
	var wallet: int = old.rolls_balance
	var rolls: int = old.lifetime_rolls
	var old_path: String = SaveManager.save_path
	var old_generation: int = SaveManager.generation
	SaveManager.save_path = "res://.godot/Slimerot-stage-9-legacy-%d.json" % OS.get_process_id()
	SaveManager.generation = 0
	SaveManager.enabled = true
	check(SaveManager.validate(old) and SaveManager.write_snapshot(old), "Prompt 8 historical Breakthrough prices remain valid after tuning")
	check(SaveManager.load_game() and GameState.rolls_balance == wallet and GameState.lifetime_rolls == rolls and GameState.roll_skill_spend.R08 == 800 and GameState.roll_skill_spend.R13 == 1000, "loading old prices preserves both wallets and the historical spend ledger")
	check(is_equal_approx(SkillTreeManager.derived_stats().luck, 28462.5) and WorldManager.gate_open(7), "old saves retain unlocked gates and derive each x20 exactly once")
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.rolls_balance == wallet, "old-price save survives a second generation with no retroactive charge or refund")
	SaveManager.enabled = false
	SaveManager.save_path = old_path
	SaveManager.generation = old_generation

func live_fight() -> void:
	fresh()
	GameState.set_process(true)
	RollManager.set_process(true)
	CombatManager.set_physics_process(true)
	GameState.lifetime_rolls = 140
	GameState.rolls_balance = 140
	for id in ["R01", "R03", "R02"]: check(SkillTreeManager.purchase(id), "live fixture purchases " + id)
	InventoryManager.equip(InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME))
	WorldManager.travel(1)
	await get_tree().physics_frame
	var target: SlimerotEnemy = world.zone_root.get_children().filter(func(n): return n is SlimerotEnemy and n.data.archetype == "chaser")[0]
	for other in get_tree().get_nodes_in_group("slimerot_enemies"):
		if other != target:
			other.dead = true
			other.hide()
			other.set_physics_process(false)
	world.player.position = target.position + Vector2(0, 120)
	GameState.settings.auto_roll_state = true
	var start_position: Vector2 = world.player.position
	var start_rolls: int = GameState.lifetime_rolls
	var start_active: float = GameState.active_play_seconds
	var start_coins: int = GameState.coins
	Input.action_press("move_right")
	for frame in 40: await get_tree().physics_frame
	Input.action_release("move_right")
	for frame in 560:
		if target.dead: break
		await get_tree().physics_frame
	check(world.player.position.distance_to(start_position) > 50.0 and GameState.lifetime_rolls >= start_rolls + 2, "actual movement and Auto Roll continue during a live fight")
	check(target.dead and GameState.coins >= start_coins + target.data.coin_reward and not GameState.player_dead, "live AI/projectile fight pays Coins without stopping Auto Roll")
	check(GameState.active_play_seconds > start_active + 2.0, "live combat advances only the ordinary active clock")
	GameState.settings.auto_roll_state = false
	var output := FileAccess.open("res://.godot/Slimerot-balance-physics.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"format": "Slimerot projectile fixtures", "step_seconds": STEP, "assumptions": "Stationary targets; Chaser 100% firing uptime, boss 70% firing windows; no incoming boss attacks; Normal variants; separate live moving/Auto Roll fight", "measurements": measurements}, "\t"))
		output.close()
	fresh()
