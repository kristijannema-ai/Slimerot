extends Node

var suite: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, description)

func fresh() -> void:
	SaveManager.enabled = false
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.menu_paused = false
	GameState.suspended = false
	RollManager.rng.seed = 914
	RollManager.variant_rng.seed = 1234

func node_data(id: String, effect: String, value: float) -> void:
	var data := SlimerotData.SkillNodeData.new()
	data.id = id
	data.effect_type = effect
	data.effect_value = value
	data.currency_type = "Rolls"
	SkillTreeManager.nodes[id] = data
	GameState.purchased_skill_node_ids.append(id)
	GameState.roll_skill_spend[id] = 0

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	fresh()
	WorldManager.travel(0)
	check(SlimeDatabase.slimes.size() == 24 and InventoryManager.collection().size() == 24, "exactly 24 base collection entries before any discovery")
	var expected := [[7,5],[13,12],[24,28],[16,15],[28,34],[51,81],[26,32],[49,76],[85,167],[41,59],[73,135],[130,303],[62,107],[114,252],[203,565],[97,201],[178,471],[320,1074],[143,345],[272,854],[483,1912],[222,643],[424,1593],[778,3741]]
	var rows_match := true
	for index in SlimerotRoster.ROWS.size():
		var slime := SlimeDatabase.get_slime(SlimerotRoster.ROWS[index][0])
		rows_match = rows_match and slime.base_damage == expected[index][0] and slime.base_sell == expected[index][1]
	check(rows_match, "all 24 formula-derived damage and sell values match canonical table")
	var monotonic := true
	var previous_damage := 0.0
	for slime in SlimeDatabase.eligible(8):
		monotonic = monotonic and slime.base_damage > previous_damage
		previous_damage = slime.base_damage
	check(monotonic, "rarer base thresholds always have strictly higher base damage")
	for zone_id in range(1, 9):
		var pool := SlimeDatabase.eligible(zone_id)
		check(pool.size() == zone_id * 3 and pool.all(func(slime): return slime.zone_unlock <= zone_id), "zone %d eligibility contains exactly all unlocked entries" % zone_id)
	check(RollManager.select_base(1, 1, 1) == SlimerotBalance.FIRST_SLIME, "below-threshold fallback Tung Tung")
	check(RollManager.select_base(12, 1, 1) == "brr_brr_patapim", "threshold equality selects reached base")
	check(RollManager.select_base(20, 1, 2) == "ballerina_cappuccina", "interleaved zone thresholds sorted globally")
	check(RollManager.select_base(1, 0.001, 1) == "chimpanzini_bananini" and RollManager.select_base(1, 0.001, 2) == "tralalero_tralala", "highest eligible winner changes only when zone unlocks")
	check(RollManager.select_base(1, 1.0 / 4000000.0, 8) == "brainrot_singularity", "exact jackpot threshold winner")
	var endpoint_valid := true
	for index in 10000:
		var uniform := (float(RollManager.rng.randi()) + 1.0) / 4294967296.0
		endpoint_valid = endpoint_valid and uniform > 0 and uniform <= 1
	check(endpoint_valid, "score sampler remains in (0,1]")
	GameState.highest_zone_unlocked = 8
	GameState.current_zone = 0
	check(RollManager.request_roll() and RollManager.last_result.slime_id == SlimerotBalance.FIRST_SLIME and InventoryManager.equipped_copy_ids.size() == 1, "first-ever guarantee survives a large unlocked pool")
	check(GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1, "first roll awards exactly one of each currency")
	for index in 99:
		RollManager.cooldown_remaining = 0.0
		RollManager.request_roll()
	check(GameState.rolls_balance == 100 and GameState.lifetime_rolls == 100, "100 completed manual rolls = 100 Rolls + 100 Lifetime Rolls")
	var owned := 0
	for pair in InventoryManager.inventory.values(): owned += pair.quantity
	check(owned == 100 and InventoryManager.discoveries.size() > 1, "100 results stored as quantities and permanent discoveries")
	check(not world.hud.wallet.text.contains("Lifetime"), "main HUD excludes Lifetime Rolls")
	check(SlimeDatabase.threshold_label("brainrot_singularity") == "Rarity threshold: 1 in 4,000,000", "UI labels thresholds rather than isolated probabilities")
	var counts := {"normal": 0, "shiny": 0, "glitched": 0, "golden": 0}
	var sense_counts := counts.duplicate()
	for index in 40000:
		var point := (index + 0.5) / 40000.0
		counts[RollManager.select_variant(point)] += 1
		sense_counts[RollManager.select_variant(point, true)] += 1
	check(counts == {"normal":39556,"shiny":400,"glitched":40,"golden":4}, "disjoint variant intervals have exact listed marginal chances")
	check(sense_counts == {"normal":39445,"shiny":500,"glitched":50,"golden":5}, "Variant Sense improves each rare-variant chance by exactly 25%")
	check(RollManager.select_variant(0.0) == "golden" and RollManager.select_variant(0.0001) == "glitched" and RollManager.select_variant(0.0011) == "shiny" and RollManager.select_variant(0.0111) == "normal", "variant interval boundaries and endpoints")
	var sequence: Array[String] = []
	RollManager.variant_rng.seed = 57
	for index in 200: sequence.append(RollManager.select_variant(float(RollManager.variant_rng.randi()) / 4294967296.0))
	node_data("slimerot_test_luck", "luck_multiplier", 1000000)
	RollManager.variant_rng.seed = 57
	var independent := true
	for index in 200:
		independent = independent and sequence[index] == RollManager.select_variant(float(RollManager.variant_rng.randi()) / 4294967296.0)
	check(independent, "ordinary Luck never enters variant selection or changes its seeded sequence")
	GameState.purchased_skill_node_ids.clear()
	GameState.roll_skill_spend.clear()
	node_data("slimerot_test_minor", "luck_multiplier", 1.25)
	node_data("slimerot_test_b1", "checkpoint_luck", 20)
	node_data("slimerot_test_b2", "checkpoint_luck", 20)
	GameState.active_potion_multiplier = 2
	GameState.potion_remaining_seconds = 60
	check(RollManager.effective_luck() == 1000, "effective luck = minor product ×20^breakthroughs ×active potion")
	check(RollManager.set_luck_cap(20) and RollManager.rolling_luck() == 20 and RollManager.effective_luck() == 1000, "x20-era cap only affects roll luck")
	check(RollManager.set_luck_cap(1) and RollManager.rolling_luck() == 1 and SkillTreeManager.derived_stats().damage_multiplier == 1, "x1 cap makes commons reachable without changing combat")
	check(RollManager.set_luck_cap(0) and RollManager.rolling_luck() == 1000, "MAX removes luck cap")
	GameState.potion_remaining_seconds = 0
	check(RollManager.effective_luck() == 500, "expired potion has no luck effect")
	GameState.purchased_skill_node_ids.clear()
	GameState.roll_skill_spend.clear()
	check(not RollManager.set_luck_cap(1), "Luck Cap locked before Breakthrough I")
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	for extra in 40:
		RollManager.cooldown_remaining = 0.0
		RollManager.request_roll()
	check((SkillTreeManager.purchase("R01") and SkillTreeManager.purchase("R02") and SkillTreeManager.purchase("R03")), "Roll-tree purchase consumes currency without minting Rolls")
	check(GameState.lifetime_rolls == GameState.rolls_balance + SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), "Lifetime Rolls equals balance plus Roll-tree spending")
	GameState.settings.auto_roll_state = true
	var before_auto := GameState.lifetime_rolls
	var before_balance := GameState.rolls_balance
	for index in 100:
		RollManager.cooldown_remaining = 0.0
		RollManager._process(0.0)
	check(GameState.lifetime_rolls == before_auto + 100 and GameState.rolls_balance == before_balance + 100, "100 automatic rolls grant exactly 100 of both currencies")
	GameState.settings.auto_roll_state = false
	GameState.coins = 1000000
	check(not SkillTreeManager.purchase("team_slot_3"), "slot prerequisites prevent skipping Slot 2")
	check(SkillTreeManager.purchase("team_slot_2") and SkillTreeManager.derived_stats().equipped_slots == 2, "Slot 2 unlocks for 350 Coins")
	check(not SkillTreeManager.purchase("team_slot_3"), "Slot 3 requires Z2 boss")
	for zone_id in [2,4,6]: GameState.boss_defeated_flags["zone_%d" % zone_id] = true
	for id in ["team_slot_3", "team_slot_4", "team_slot_5"]: SkillTreeManager.purchase(id)
	check(SkillTreeManager.derived_stats().equipped_slots == 5, "team progression enforces five-slot maximum")
	InventoryManager.reset()
	var normal := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	var shiny := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "shiny")
	var glitched := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "glitched")
	var golden := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "golden")
	check(InventoryManager.damage_for_copy(normal) == 7 and InventoryManager.damage_for_copy(shiny) == 10.5 and InventoryManager.damage_for_copy(glitched) == 17.5 and InventoryManager.damage_for_copy(golden) == 28, "all four variant damage multipliers")
	check(InventoryManager.collection().size() == 24 and InventoryManager.discoveries.size() == 1 and InventoryManager.best_variant_owned(SlimerotBalance.FIRST_SLIME) == "golden", "variants share one base collection entry with best owned variant")
	check(InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME+":normal") == 5 and InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME+":shiny") == 10 and InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME+":glitched") == 25 and InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME+":golden") == 50, "all four variant sell multipliers")
	var powerful := InventoryManager.add_copy("brainrot_singularity", "golden")
	InventoryManager.auto_equip_strongest()
	check(InventoryManager.equipped_copy_ids[0] == powerful and InventoryManager.equipped_copy_ids.size() == 5, "Auto Equip ranks actual variant DPS and fills all slots")
	check(InventoryManager.equipped_copy_ids.has(normal) and InventoryManager.equipped_copy_ids.has(golden), "multiple copies of the same base may occupy distinct slots")
	GameState.structure_unlocked_flags.sell_terminal = true
	InventoryManager.unequip(golden)
	InventoryManager.toggle_copy_favorite(golden)
	check(InventoryManager.sell_copy(golden) == 0 and InventoryManager.sell_copy(powerful) == 0, "individual favorite and equipped sale protection")
	InventoryManager.toggle_copy_favorite(golden)
	check(InventoryManager.sell_copy(golden) == 50 and InventoryManager.best_variant_owned(SlimerotBalance.FIRST_SLIME) == "glitched", "selling best variant updates current best owned")
	check("golden" in InventoryManager.discoveries[SlimerotBalance.FIRST_SLIME], "sold variant discovery remains permanent")
	var sold_base := InventoryManager.add_copy("brr_brr_patapim")
	InventoryManager.sell_copy(sold_base)
	check(InventoryManager.discoveries.has("brr_brr_patapim") and InventoryManager.best_variant_owned("brr_brr_patapim").is_empty(), "base discovery persists even after all owned copies are sold")
	node_data("slimerot_test_dealer", "duplicate_dealer", 0.5)
	node_data("slimerot_test_scavenger", "coin_scavenger", 0.5)
	var duplicate := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "shiny")
	check(InventoryManager.sell_copy(duplicate) == 15, "Duplicate Dealer applies only to sale formula")
	var old_coins := GameState.coins
	WorldManager.record_kill(1, 10)
	check(GameState.coins == old_coins + 15, "Coin Scavenger applies to normal enemy rewards")
	old_coins = GameState.coins
	check(WorldManager.award_boss_reward(8, 100) and not WorldManager.award_boss_reward(8, 100) and GameState.coins == old_coins + 100, "boss reward is fixed and paid only once")
	check(RollManager.reveal_duration(2, false) == 0.35 and RollManager.reveal_duration(100, false) == 0.65 and RollManager.reveal_duration(10000, false) == 1.1 and RollManager.reveal_duration(100000, false) == 1.7 and RollManager.reveal_duration(1000000, true) == 2.8 and RollManager.reveal_duration(1000000, false) == 1, "all canonical reveal duration boundaries")
	node_data("slimerot_test_skip", "skip_common", 1)
	check(RollManager.reveal_duration(75, false) == 0.2, "Skip Common timing")
	RollManager.reset()
	var jackpot := {"slime_id":"brainrot_singularity", "variant":"golden", "threshold":4000000, "first_discovery":true, "first_roll":false}
	RollManager.queue_reveal(jackpot)
	var old_lifetime := GameState.lifetime_rolls
	check(not RollManager.skip_reveal(), "first-discovery jackpot cannot be skipped")
	RollManager.queue_reveal({"slime_id":SlimerotBalance.FIRST_SLIME, "variant":"normal", "threshold":2, "first_discovery":false, "first_roll":false})
	check(RollManager.active_reveal.slime_id == "brainrot_singularity" and RollManager.reveal_queue.size() == 1, "later rolls cannot replace an unskippable discovery")
	RollManager._process(2.8)
	check(RollManager.active_reveal.slime_id == SlimerotBalance.FIRST_SLIME and RollManager.skip_reveal() and GameState.lifetime_rolls == old_lifetime, "skip/queued reveals never re-award currency")
	jackpot.first_discovery = false
	RollManager.queue_reveal(jackpot)
	check(RollManager.skip_reveal(), "repeat jackpot can be skipped")
	# Remove test-only skill definitions before persistence; preserve real purchase invariant.
	for id in GameState.purchased_skill_node_ids.duplicate():
		if id.begins_with("slimerot_test_"): GameState.purchased_skill_node_ids.erase(id); GameState.roll_skill_spend.erase(id)
	for id in SkillTreeManager.nodes.keys():
		if id.begins_with("slimerot_test_"): SkillTreeManager.nodes.erase(id)
	var snapshot := SaveManager.snapshot()
	check(SaveManager.validate(snapshot), "schema 2 validates full roster, discovery and favorite state")
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game(), "schema 2 round-trip including highest zone 8")
	var legacy := snapshot.duplicate(true)
	legacy.schema_version = 1
	legacy.erase("discoveries")
	for pair in legacy.inventory.values(): pair.erase("favorite_copy_ids")
	var migrated: Dictionary = SaveManager.migrate(legacy)
	check(SaveManager.validate(migrated) and migrated.inventory.size() == snapshot.inventory.size(), "schema 1 migration retains quantities/copy IDs and derives discoveries")
	var invalid := snapshot.duplicate(true)
	invalid.rolls_balance += 1
	check(not SaveManager.validate(invalid), "save validation enforces sole-source Rolls invariant")
	invalid = snapshot.duplicate(true)
	invalid.coins += 0.5
	check(not SaveManager.validate(invalid), "save validation rejects fractional currency")
	SaveManager.enabled = false
	world.hud.open_menu("Collection")
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("slimerot_collection_entry").size() == 24, "actual Collection UI renders exactly 24 base cards")
	await capture("Slimerot-stage-2-collection")
	world.hud.open_menu("Team")
	await capture("Slimerot-stage-2-team")
	world.hud.open_menu("Inventory")
	await capture("Slimerot-stage-2-inventory")
	world.hud.close_menu()
	RollManager.queue_reveal(jackpot)
	await capture("Slimerot-stage-2-jackpot")
	RollManager.reset()
	world.hud.open_menu("Settings")
	var before_pause := GameState.active_play_seconds
	GameState._process(10)
	check(GameState.active_play_seconds == before_pause and not RollManager.request_roll(), "Pause stops active time and new rolls")
	var before_reset := GameState.lifetime_rolls
	world.hud.menus.reset_button.button_down.emit()
	world.hud.menus.tick(2.9)
	check(GameState.lifetime_rolls == before_reset, "reset does not fire before three-second hold")
	world.hud.menus.reset_button.button_up.emit()
	world.hud.menus.tick(1)
	check(GameState.lifetime_rolls == before_reset, "releasing reset cancels confirmation")
	world.hud.menus.reset_button.button_down.emit()
	world.hud.menus.tick(3)
	check(GameState.lifetime_rolls == 0 and GameState.rolls_balance == 0 and GameState.coins == 0 and InventoryManager.inventory.is_empty() and InventoryManager.discoveries.is_empty() and GameState.settings.luck_cap == 0.0, "confirmed reset restores complete canonical new save")
	SaveManager.enabled = false
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path + suffix)

func capture(label: String) -> void:
	if "--slimerot-capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + label + ".png")
