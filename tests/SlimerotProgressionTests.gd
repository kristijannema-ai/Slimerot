extends Node

var suite: Node
var world: Node

func check(value: bool, label: String) -> void:
	suite.check(value, "Progression13 · " + label)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	RollManager.reset()
	InventoryManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	GameState.rolls_balance = 50000
	GameState.lifetime_rolls = 50000
	GameState.coins = 10000000
	GameState.coins_earned = GameState.coins
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	WorldManager.travel(0)
	RollManager.rng.seed = 13001
	RollManager.variant_rng.seed = 13002

func buy_to(id: String) -> void:
	for row in SlimerotRollTree.MAINLINE:
		if row[0] not in GameState.purchased_skill_node_ids: assert(SkillTreeManager.purchase(row[0]))
		if row[0] == id: return

func set_lifetime(value: int) -> void:
	GameState.lifetime_rolls = value
	GameState.rolls_balance = value - SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids)

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var states := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	test_order_and_luck()
	test_super_schedule()
	await test_offline_schedule()
	test_validator()
	await test_ui()
	fresh()
	GameState.set_process(states[0])
	RollManager.set_process(states[1])
	SaveManager.set_process(states[2])
	CombatManager.set_physics_process(states[3])
	await get_tree().process_frame

func test_order_and_luck() -> void:
	fresh()
	GameState.rolls_balance = 65
	GameState.lifetime_rolls = 65
	check(SkillTreeManager.purchase("R01") and SkillTreeManager.purchase_blocker("R03").is_empty() and SkillTreeManager.purchase_blocker("R02") == "Requires R03", "R01 makes Auto Roll the next valid node")
	check(SkillTreeManager.nodes.R03.cost == 40 and SkillTreeManager.purchase("R03") and SkillTreeManager.derived_stats().auto_roll and GameState.rolls_balance == 0, "Auto Roll unlocks after exactly 65 total Rolls")
	var luck_node: SlimerotData.SkillNodeData = SkillTreeManager.nodes.R02
	check(luck_node.cost == 75 and luck_node.prerequisite_ids == ["R03"] and luck_node.effect_value == 1.10, "R02 keeps its ID with R03 prerequisite, 75 cost and x1.10")
	fresh()
	GameState.highest_zone_unlocked = 8
	GameState.active_potion_type = "hyper_soda"
	GameState.potion_remaining_seconds = 120
	for id in ["C20", "C21", "C22"]: check(SkillTreeManager.purchase(id), "Fortune chain purchases " + id)
	var baseline := SaveManager.snapshot()
	buy_to("R07")
	var before := RollManager.get_effective_luck()
	check(SkillTreeManager.purchase("R08") and is_equal_approx(RollManager.get_effective_luck(), before * 20), "B1 multiplies total by exactly 20 with zone, Fortune and potion active")
	var saved := SaveManager.snapshot()
	SaveManager.apply_snapshot(saved)
	SaveManager.apply_snapshot(saved)
	check(is_equal_approx(RollManager.get_effective_luck(), before * 20), "loading B1 twice cannot compound luck")
	buy_to("R18")
	var parts := RollManager.get_luck_breakdown({"super_roll_multiplier": 20.0})
	check(parts.breakthrough_product == 8000 and parts.zone_luck_multiplier == 8 and is_equal_approx(parts.coin_tree_luck_product, 1.15 * 1.20 * 1.25), "dev breakdown isolates exact x8000, x8 and all Fortune multipliers")
	check(is_equal_approx(parts.total, parts.minor_roll_tree_product * 8000 * 8 * 1.15 * 1.20 * 1.25 * 3 * 20) and RollManager.get_effective_luck({"super_roll_multiplier":20}) == parts.total, "six-component product and central total agree")
	check(is_equal_approx(RollManager.get_effective_luck({"apply_cap":true, "luck_cap":20, "super_roll_multiplier":10}), 200), "legacy Luck Cap precedes the current tier's Super multiplier")
	SaveManager.apply_snapshot(baseline)
	GameState.highest_zone_unlocked = 2
	GameState.purchased_skill_node_ids.clear()
	GameState.roll_skill_spend.clear()
	check(SkillTreeManager.purchase_blocker("C20") == "Unlock Z3", "Fortune I respects its Z3 gate")
	GameState.highest_zone_unlocked = 8
	for zone in [2,4,6]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	GameState.structure_unlocked_flags.sell_terminal = true
	buy_to("R18")
	for pass_index in 2:
		for row in SlimerotCoinTree.ROWS:
			if row[0] not in GameState.purchased_skill_node_ids and SkillTreeManager.purchase_blocker(row[0]).is_empty(): assert(SkillTreeManager.purchase(row[0]))
	var stats := SkillTreeManager.derived_stats()
	check(stats.equipped_slots == 5 and is_equal_approx(stats.damage_multiplier, 3.0) and is_equal_approx(stats.coin_scavenger, 2.0) and is_equal_approx(stats.move_speed, 243), "all Coin nodes give x3 damage, +200% normal Coins, 243 speed and at most five slots")
	var old_coins := GameState.coins
	WorldManager.record_kill(1, 5)
	check(GameState.coins == old_coins + 15, "new Scavenger applies to normal enemy rewards")
	old_coins = GameState.coins
	check(WorldManager.award_boss_reward(8, 100) and GameState.coins == old_coins + 100, "new Scavenger leaves the fixed boss reward unchanged")

func test_super_schedule() -> void:
	fresh()
	buy_to("R18")
	set_lifetime(20045)
	check(SkillTreeManager.purchase("RO5") and GameState.super_roll_next_trigger == 20100 and RollManager.rolls_until_super() == 55 and SkillTreeManager.derived_stats().super_roll_multiplier == 5, "RO5 preserves the next 100th Lifetime trigger with x5 on first unlock")
	var wallet := GameState.rolls_balance
	var boosts: Array[int] = []
	for index in 65:
		var result := RollManager.resolve_roll()
		assert(RollManager.commit_roll(result))
		if result.data.super_roll: boosts.append(result.data.lifetime_roll)
	check(boosts == [20100] and GameState.rolls_balance == wallet + 65 and GameState.super_roll_next_trigger == 20200, "RO5 fires x5 once and every completed roll grants exactly +1/+1")
	check(SkillTreeManager.purchase("RO8") and GameState.super_roll_next_trigger == 20185 and SkillTreeManager.derived_stats().super_roll_multiplier == 10, "RO8 shortens a longer pending wait to 75 rolls with x10")
	boosts.clear()
	var multipliers: Array[float] = []
	for index in 150:
		var result := RollManager.resolve_roll()
		assert(RollManager.commit_roll(result))
		if result.data.super_roll:
			boosts.append(result.data.lifetime_roll)
			multipliers.append(result.data.super_roll_multiplier)
	check(boosts == [20185,20260] and multipliers == [10.0,10.0] and GameState.super_roll_next_trigger == 20335, "RO8 keeps a persisted 75-roll phase unrelated to global modulus")
	for index in 60: assert(RollManager.commit_roll(RollManager.resolve_roll()))
	check(SkillTreeManager.purchase("RO9") and GameState.super_roll_next_trigger == 20335 and RollManager.rolls_until_super() == 15, "RO9 preserves an earlier pending trigger when bought mid-cycle")
	boosts.clear()
	multipliers.clear()
	for index in 115:
		var result := RollManager.resolve_roll()
		assert(RollManager.commit_roll(result))
		if result.data.super_roll:
			boosts.append(result.data.lifetime_roll)
			multipliers.append(result.data.super_roll_multiplier)
	check(boosts == [20335,20385,20435] and multipliers == [20.0,20.0,20.0], "RO9 repeats every 50 completed rolls at x20")
	var committed := RollManager.resolve_roll()
	assert(RollManager.commit_roll(committed))
	var after := [GameState.lifetime_rolls, GameState.rolls_balance, GameState.super_roll_next_trigger]
	check(not RollManager.commit_roll(committed) and after == [GameState.lifetime_rolls, GameState.rolls_balance, GameState.super_roll_next_trigger], "duplicate commit cannot advance Super or currency twice")
	check(SlimerotSuperRoll.after_trigger(SlimerotSaveFormat.MAX_EXACT_INTEGER - 10, 50) == 0, "exhausted exact integer range cannot overflow a future trigger")

func inventory_counts() -> Dictionary:
	var result := {}
	for key in InventoryManager.inventory: result[key] = InventoryManager.inventory[key].quantity
	return result

func test_offline_schedule() -> void:
	fresh()
	buy_to("R18")
	set_lifetime(20045)
	for id in ["RO5","RO8","RO9"]: assert(SkillTreeManager.purchase(id))
	for id in ["C20","C21","C22"]:
		GameState.highest_zone_unlocked = 8
		assert(SkillTreeManager.purchase(id))
	GameState.settings.auto_roll_state = true
	var baseline := SaveManager.snapshot()
	var rng_state := [RollManager.rng.state, RollManager.variant_rng.state]
	for index in 220:
		RollManager.cooldown_remaining = 0
		RollManager._process(0)
	var expected := [GameState.lifetime_rolls, GameState.rolls_balance, GameState.super_roll_next_trigger, GameState.best_ever_effective_rarity, GameState.rolls_since_last_power_improvement, inventory_counts(), RollManager.rng.state, RollManager.variant_rng.state]
	SaveManager.apply_snapshot(baseline)
	RollManager.rng.state = rng_state[0]
	RollManager.variant_rng.state = rng_state[1]
	var offline: Dictionary = await RollManager.process_offline_rolls(220)
	var actual := [GameState.lifetime_rolls, GameState.rolls_balance, GameState.super_roll_next_trigger, GameState.best_ever_effective_rarity, GameState.rolls_since_last_power_improvement, inventory_counts(), RollManager.rng.state, RollManager.variant_rng.state]
	check(actual == expected and offline.rolls == 220 and RollManager.reveal_queue.is_empty(), "Auto/offline parity includes Fortune, Super III phase, P12 outcomes/pity and both currencies")

func test_validator() -> void:
	fresh()
	var validation: Dictionary = SkillTreeManager.validate_tree()
	check(validation.valid and validation.errors.is_empty(), "canonical skill tree has no cycles, missing prerequisites or duplicate persistent IDs")
	var nodes: Array = SkillTreeManager.nodes.values()
	var duplicate := nodes.duplicate()
	duplicate.append(nodes[0])
	check(not SkillTreeManager.validate_tree(duplicate).valid, "validator detects duplicate IDs before dictionary overwrite")
	var definitions := [{"id":"R01", "persistent_id":"shared", "currency_type":"Rolls", "cost":25, "effect_type":"cooldown_set", "effect_value":2.2, "prerequisite_ids":[]},
		{"id":"RO_NEW", "persistent_id":"shared", "currency_type":"Rolls", "cost":10, "effect_type":"luck_multiplier", "effect_value":1.1, "prerequisite_ids":[]}]
	check(not SkillTreeManager.validate_tree(definitions).valid, "validator detects distinct nodes sharing a persistent ID")
	definitions[1].persistent_id = "unique"
	check(SkillTreeManager.validate_tree(definitions).valid and not SkillTreeManager.validate_tree(definitions).warnings.is_empty(), "a disconnected non-root node produces an orphan warning")
	var cycle: Array = []
	for data in nodes: cycle.append(data.duplicate(true))
	for data in cycle:
		if data.id == "R01": data.prerequisite_ids.assign(["R02"])
	check(not SkillTreeManager.validate_tree(cycle).valid, "validator detects a prerequisite cycle")
	for bad in ["currency", "slot", "breakthrough", "missing"]:
		var altered: Array = []
		for data in nodes: altered.append(data.duplicate(true))
		for data in altered:
			if bad == "currency" and data.id == "R01": data.currency_type = "XP"
			if bad == "slot" and data.id == "C15": data.effect_value = 6
			if bad == "breakthrough" and data.id == "R08": data.effect_value = 21
			if bad == "missing" and data.id == "RO9": data.prerequisite_ids.append("missing")
		check(not SkillTreeManager.validate_tree(altered).valid, "validator rejects invalid " + bad)

func capture_skill(id: String, label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	world.hud.menus.skill_canvas.focus_node(id)
	await get_tree().process_frame
	await suite.capture(label)

func test_ui() -> void:
	fresh()
	GameState.rolls_balance = 65
	GameState.lifetime_rolls = 65
	assert(SkillTreeManager.purchase("R01"))
	world.hud.menus.skill_tab = "Roll"
	world.hud.open_menu("Skills")
	var unordered: Array[String] = ["R02","R03","R01","R04"]
	var ordered: Array[String] = world.hud.menus.progression_order(unordered)
	check(ordered == ["R01","R03","R02","R04"], "skill cards follow progression order independently of persistent IDs")
	await capture_skill("R03", "Slimerot-p13-early-auto")
	fresh()
	buy_to("R18")
	assert(SkillTreeManager.purchase("RO5"))
	world.hud.breakthrough_seconds = 0
	world.hud.breakthrough_banner.hide()
	world.hud.open_menu("Skills")
	await capture_skill("RO8", "Slimerot-p13-super-branch")
	unordered.assign(["RO9","RO8","RO5"])
	ordered = world.hud.menus.progression_order(unordered)
	check(ordered == ["RO5","RO8","RO9"], "Super branch displays parents before upgrades")
	assert(SkillTreeManager.purchase("RO8"))
	assert(SkillTreeManager.purchase("RO9"))
	world.hud.open_menu("Roll Settings")
	await get_tree().process_frame
	world.hud.menus.refresh_live()
	check(world.hud.menus.super_status.text.contains("III") and world.hud.menus.super_status.text.contains("20") and world.hud.menus.super_status.text.contains("50"), "Roll Settings shows the current Super tier, multiplier and interval")
	world.hud.menu_scroll.ensure_control_visible(world.hud.menus.super_status)
	await suite.capture("Slimerot-p13-super-settings")
	world.hud.close_menu()
