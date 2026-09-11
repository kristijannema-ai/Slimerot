extends Node

var suite: Node
const COSTS := [25,40,75,125,175,275,350,800,350,400,550,550,1000,700,700,900,900,1300]
const SPEEDS := {"R01":2.2,"R04":1.9,"R06":1.55,"R09":1.25,"R11":1.0,"R14":0.8,"R16":0.65,"RO7":0.5}
const OPTIONAL := [["RO1","R04",150],["RO2","R08",450],["RO3","R08",300],["RO4","R13",500],["RO5","R13",650],["RO6","R13",700],["RO7","R18",1400]]

func check(value: bool, label: String) -> void:
	suite.check(value, label)

func fresh(funding: int = 50000) -> void:
	SaveManager.enabled = false
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	CombatManager.invulnerable_remaining = 0
	GameState.rolls_balance = funding
	GameState.lifetime_rolls = funding
	RollManager.rng.seed = 303
	RollManager.variant_rng.seed = 603

func buy_to(number: int) -> void:
	for index in range(1, number + 1):
		var id := "R%02d" % index
		if id not in GameState.purchased_skill_node_ids:
			assert(SkillTreeManager.purchase(id), "Slimerot test prerequisite setup failed: " + id)

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	fresh()
	world.hud.close_menu()
	WorldManager.travel(0)
	var roll_nodes := 0
	for node in SkillTreeManager.nodes.values():
		if node.tree_type == "Roll": roll_nodes += 1
	check(roll_nodes == 25, "exactly 18 canonical mainline and seven optional Roll nodes")
	check(not SkillTreeManager.nodes.has("auto_roll") and not SkillTreeManager.nodes.has("luck_1"), "provisional IDs removed from purchasable tree")
	check(COSTS.slice(0,8).reduce(func(a,b):return a+b,0) == 1865 and COSTS.slice(8,13).reduce(func(a,b):return a+b,0) == 2850 and COSTS.slice(13,18).reduce(func(a,b):return a+b,0) == 4500, "canonical spend blocks 1865 / 2850 / 4500")
	for index in range(1,19):
		var id := "R%02d" % index
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		var requires: Array = [] if index == 1 else ["R%02d" % (index-1)]
		check(data.cost == COSTS[index-1] and data.currency_type == "Rolls" and data.prerequisite_ids == requires, id + " exact cost/currency/prerequisites")
	for row in OPTIONAL:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[row[0]]
		check(data.cost == row[2] and data.prerequisite_ids == [row[1]] and data.optional, row[0] + " exact independent branch contract")
	check(not SkillTreeManager.purchase("R08") and not SkillTreeManager.purchase("RO6"), "funding alone cannot bypass mainline or optional prerequisites")
	GameState.rolls_balance = 24
	GameState.lifetime_rolls = 24
	check(not SkillTreeManager.purchase("R01") and GameState.rolls_balance == 24, "insufficient balance changes nothing")
	fresh()
	var life := GameState.lifetime_rolls
	var initial_rolls := GameState.rolls_balance
	var expected_spend := 0
	for index in range(1,19):
		var id := "R%02d" % index
		var old_luck := RollManager.effective_luck()
		check(SkillTreeManager.purchase(id), id + " mainline purchase without any optional nodes")
		expected_spend += COSTS[index-1]
		check(GameState.rolls_balance == initial_rolls - expected_spend and GameState.lifetime_rolls == life and GameState.coins == 0, id + " spends Rolls only and preserves Lifetime Rolls")
		if SPEEDS.has(id): check(is_equal_approx(SkillTreeManager.derived_stats().roll_cooldown, SPEEDS[id]), id + " exact absolute cooldown")
		if id in ["R08","R13","R18"]:
			check(is_equal_approx(RollManager.effective_luck() / old_luck, 20.0), id + " multiplies total luck by exactly x20")
			var expected: float = {"R08":30.36,"R13":910.8,"R18":28462.5}[id]
			check(is_equal_approx(RollManager.effective_luck(), expected), id + " canonical cumulative luck")
	check(not SkillTreeManager.purchase("R18") and GameState.lifetime_rolls == life, "repeat purchase cannot charge or stack an effect")
	check(SkillTreeManager.purchase("RO7") and SkillTreeManager.derived_stats().roll_cooldown == 0.5, "post-campaign Quick Hands VIII sets 0.50s")
	var ordered := SkillTreeManager.derived_stats()
	GameState.purchased_skill_node_ids.reverse()
	check(SkillTreeManager.derived_stats() == ordered, "derived luck and speed do not depend on saved node order")
	check(GameState.lifetime_rolls == GameState.rolls_balance + SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), "new-save Roll ledger preserves Lifetime = balance + all spending")
	for row in OPTIONAL:
		if row[0] != "RO7": check(SkillTreeManager.purchase(row[0]), row[0] + " optional purchase after its independent prerequisite")
	check(RollManager.reveal_duration(75,false) == 0.2 and RollManager.reveal_duration(100,false) == 0.65, "RO1 skips only thresholds below 100")
	check(SkillTreeManager.derived_stats().variant_sense and SlimerotBalance.VARIANT_DATA.shiny.chance * SlimerotBalance.VARIANT_SENSE_MULTIPLIER == 1.0/80.0 and SlimerotBalance.VARIANT_DATA.glitched.chance * SlimerotBalance.VARIANT_SENSE_MULTIPLIER == 1.0/800.0 and SlimerotBalance.VARIANT_DATA.golden.chance * SlimerotBalance.VARIANT_SENSE_MULTIPLIER == 1.0/8000.0, "RO6 exact denominators 80 / 800 / 8000")
	GameState.active_potion_multiplier = 2
	GameState.potion_remaining_seconds = 60
	check(is_equal_approx(RollManager.effective_luck(5),284625), "minor ×20^3 ×potion ×single-roll multiplier without destructive state")
	var dps := InventoryManager.team_dps()
	for cap in [0.0,20.0,1.0]:
		check(RollManager.set_luck_cap(cap), "Luck Cap accepts " + str(cap))
		var base: float = 56925.0 if cap == 0.0 else cap
		check(is_equal_approx(RollManager.rolling_luck(),base) and is_equal_approx(RollManager.rolling_luck(5),base*5) and InventoryManager.team_dps() == dps, "cap " + str(cap) + " affects base rolling luck only; Super remains exactly x5")
	check(not RollManager.set_luck_cap(2.0), "unsupported cap rejected")
	GameState.potion_remaining_seconds = 0
	RollManager.set_luck_cap(0)
	# Every numbered completion, regardless of manual or auto, uses the same cadence.
	var ledger_spend := SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids)
	for number in [19998,19999,20000,20001,20099,20100]:
		GameState.lifetime_rolls = number - 1
		GameState.rolls_balance = number - 1 - ledger_spend
		RollManager.cooldown_remaining = 0
		var coins_before := GameState.rolls_balance
		check(RollManager.request_roll(), "numbered roll " + str(number) + " commits")
		check(RollManager.last_result.super_roll == (number % 100 == 0) and is_equal_approx(RollManager.last_result.luck_used, 28462.5 * (5 if number % 100 == 0 else 1)) and GameState.rolls_balance == coins_before+1, "Super Roll cadence/one-time boost at " + str(number))
		check(not RollManager.request_roll() and GameState.lifetime_rolls == number, "rejected repeat leaves Super cadence unchanged")
	# A real purchase at R08 resets MAX, then reload must not reapply x20 or reset the user's cap.
	fresh()
	buy_to(7)
	GameState.settings.luck_cap = 1.0
	check(SkillTreeManager.purchase("R08") and GameState.settings.luck_cap == 0, "B1 unlock defaults Luck Cap to MAX")
	SkillTreeManager.purchase("RO2")
	check(InventoryManager.auto_sell_thresholds() == [100] and InventoryManager.set_auto_sell(true), "RO2 alone enables default threshold 100")
	check(not InventoryManager.set_auto_sell_threshold(1000), "custom filter rejected before unlock")
	var first_normal := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	check(InventoryManager.auto_sell_roll(first_normal) == 0, "auto-sell retains first Normal copy")
	InventoryManager.equip(first_normal)
	var normal := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	check(InventoryManager.auto_sell_roll(normal) == 5 and InventoryManager.pair_for_copy(first_normal).quantity == 1, "auto-sell sells only the new duplicate and keeps equipped original")
	var favorite := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.toggle_copy_favorite(favorite)
	check(InventoryManager.auto_sell_roll(favorite) == 0, "per-copy favorite blocks auto-sell")
	InventoryManager.toggle_favorite(SlimerotBalance.FIRST_SLIME+":normal")
	normal = InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	check(InventoryManager.auto_sell_roll(normal) == 0, "group favorite protects future rolled copies")
	for variant in ["shiny","glitched","golden"]:
		InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME,variant)
		var copy_id := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME,variant)
		check(InventoryManager.auto_sell_roll(copy_id) == 0, "auto-sell never sells " + variant)
	InventoryManager.add_copy("lirili_larila")
	var boundary := InventoryManager.add_copy("lirili_larila")
	check(InventoryManager.auto_sell_roll(boundary) == 32, "threshold 100 includes equality")
	InventoryManager.add_copy("cappuccino_assassino")
	var excluded := InventoryManager.add_copy("cappuccino_assassino")
	check(InventoryManager.auto_sell_roll(excluded) == 0, "threshold 120 excluded by default 100")
	check(SkillTreeManager.purchase("RO3") and InventoryManager.auto_sell_thresholds() == [20,100,1000] and InventoryManager.set_auto_sell_threshold(1000), "RO3 unlocks precisely 20/100/1000")
	check(InventoryManager.auto_sell_roll(excluded) == 34, "Filter I selected threshold used by backend")
	buy_to(13)
	check(SkillTreeManager.purchase("RO4") and not InventoryManager.set_auto_sell_threshold(4000000), "RO4 cannot choose an undiscovered custom threshold")
	InventoryManager.add_copy("brainrot_singularity","golden")
	check(InventoryManager.set_auto_sell_threshold(4000000), "RO4 accepts a base discovered in any variant")
	check(InventoryManager.discoveries.has("lirili_larila"), "auto-sale preserves collection discovery")
	InventoryManager.set_auto_sell(false)
	check(InventoryManager.auto_sell_roll(excluded) == 0, "disabled auto-sell changes no inventory")
	InventoryManager.set_auto_sell(true)
	RollManager.set_luck_cap(20)
	SkillTreeManager.purchase("RO5")
	ledger_spend = SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids)
	GameState.lifetime_rolls = 9999
	GameState.rolls_balance = 9999-ledger_spend
	RollManager.cooldown_remaining = 0
	var snapshot := SaveManager.snapshot()
	check(SaveManager.validate(snapshot), "schema 3 validates canonical purchases and historical spending ledger")
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.settings.luck_cap == 20 and RollManager.next_roll_multiplier() == 5, "load before roll 10000 retains selected cap and Super eligibility")
	check(RollManager.request_roll() and RollManager.last_result.luck_used == 100 and RollManager.last_result.super_roll, "post-load roll 10000 gets exactly cap20 ×5")
	check(SaveManager.load_game() and GameState.lifetime_rolls == 10000 and RollManager.next_roll_multiplier() == 1, "Super completion saves cadence without duplicating boost on load")
	for pass_index in 3: SaveManager.load_game()
	check(is_equal_approx(RollManager.effective_luck(),910.8), "repeated save loads never stack Breakthrough multipliers")
	SaveManager.enabled = false
	var legacy := snapshot.duplicate(true)
	legacy.schema_version = 2
	legacy.purchased_skill_node_ids = ["auto_roll","quick_hands_1","luck_1"]
	legacy.erase("roll_skill_spend")
	legacy.lifetime_rolls = 100
	legacy.rolls_balance = 50
	legacy.equipped_copy_ids = [first_normal]
	legacy.settings.luck_cap = 0.0
	var migrated: Dictionary = SaveManager.migrate(legacy)
	check(SaveManager.validate(migrated) and migrated.rolls_balance == 50 and migrated.lifetime_rolls == 100 and migrated.roll_skill_spend == {"R01":10,"R02":15,"R03":25}, "stage-two migration preserves currency and actual legacy spend")
	check(SkillTreeManager.derived_stats(migrated.purchased_skill_node_ids).auto_roll, "migration preserves existing Auto Roll with canonical ancestors")
	legacy.purchased_skill_node_ids = ["auto_roll"]
	legacy.rolls_balance = 75
	migrated = SaveManager.migrate(legacy)
	check(SaveManager.validate(migrated) and migrated.roll_skill_spend == {"R01":0,"R02":0,"R03":25}, "legacy standalone Auto Roll ancestors granted without minting/refunding Rolls")
	var invalid := snapshot.duplicate(true)
	invalid.purchased_skill_node_ids.erase("R07")
	invalid.roll_skill_spend.erase("R07")
	invalid.rolls_balance += 350
	check(not SaveManager.validate(invalid), "save validation rejects broken canonical prerequisite chains")
	fresh()
	buy_to(13)
	SkillTreeManager.purchase("RO2")
	SkillTreeManager.purchase("RO5")
	InventoryManager.set_auto_sell(true)
	RollManager.set_luck_cap(1)
	for slime in SlimeDatabase.eligible(1): InventoryManager.add_copy(slime.id)
	GameState.lifetime_rolls = 9999
	GameState.rolls_balance = 9999 - SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids)
	var balance_before := GameState.rolls_balance
	GameState.settings.auto_roll_state = true
	RollManager._process(0)
	check(RollManager.last_result.super_roll and GameState.lifetime_rolls == 10000 and GameState.rolls_balance == balance_before+1, "automatic completion applies Super cadence and grants currencies once")
	check(RollManager.last_result.auto_sold_coins > 0 and GameState.coins == RollManager.last_result.auto_sold_coins and InventoryManager.pair_for_copy(RollManager.last_result.copy_id).is_empty(), "real roll transaction auto-sells only its new duplicate and credits Coins")
	# Actual Auto Roll during movement and contact combat at fastest canonical speed.
	fresh()
	buy_to(18)
	SkillTreeManager.purchase("RO7")
	InventoryManager.equip(InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME))
	WorldManager.travel(1)
	await get_tree().physics_frame
	world.player.position = Vector2(500,940)
	GameState.settings.auto_roll_state = true
	RollManager.cooldown_remaining = 0
	var life_before := GameState.lifetime_rolls
	var position_before: Vector2 = world.player.position
	Input.action_press("move_right")
	for frame in 70: await get_tree().physics_frame
	Input.action_release("move_right")
	check(GameState.lifetime_rolls >= life_before+2 and world.player.position.x > position_before.x+100, "Auto Roll runs while physically walking near live enemies")
	check(GameState.player_hp < 100 or GameState.coins > 0, "live combat remains active while Auto Roll runs")
	GameState.settings.auto_roll_state = false
	WorldManager.travel(0)
	GameState.changed.emit()
	world.hud.breakthrough_seconds = 0
	world.hud.breakthrough_banner.hide()
	world.hud.menus.skill_tab = "Roll"
	world.hud.menus.optional_branch = false
	world.hud.open_menu("Skills")
	await capture("Slimerot-stage-3-mainline")
	world.hud.menus.optional_branch = true
	world.hud.open_menu("Skills")
	await capture("Slimerot-stage-3-optional")
	for row in OPTIONAL:
		if row[0] not in GameState.purchased_skill_node_ids: SkillTreeManager.purchase(row[0])
	InventoryManager.set_auto_sell(true)
	world.hud.open_menu("Roll Settings")
	await capture("Slimerot-stage-3-roll-settings")
	world.hud.close_menu()
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path+suffix)

func capture(label: String) -> void:
	if "--slimerot-capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/"+label+".png")
