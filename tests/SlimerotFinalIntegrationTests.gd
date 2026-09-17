extends Node

func same_json(left: Variant, right: Variant) -> bool:
	# JSON numbers load as floats; compare semantic values on the same representation.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

# Slimerot accelerated integration journey: fixtures fund progression and resolve
# combat instantly. This checks wiring and persistence, not human campaign pacing.
var suite: Node

func check(value: bool, label: String) -> void:
	suite.check(value, "final integration: " + label)

func freeze_combat(world: Node) -> void:
	CombatManager.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"):
		enemy.set_physics_process(false)
	if is_instance_valid(world.arena): world.arena.set_physics_process(false)

func interact_at(world: Node, at: Vector2) -> void:
	world.hud.close_menu()
	world.player.position = at
	world._process(0)
	world.interact()

func buy_available_coin_nodes() -> void:
	for row in SlimerotCoinTree.ROWS:
		var id: String = row[0]
		if not SkillTreeManager.purchase_blocker(id).is_empty(): continue
		var before := [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls]
		check(SkillTreeManager.purchase(id), "%s purchases when its real prerequisites are met" % id)
		check(GameState.coins == before[0] - int(row[3]) and GameState.rolls_balance == before[1] and GameState.lifetime_rolls == before[2], "%s charges Coins without changing either Roll counter" % id)

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	freeze_combat(world)
	check(SlimerotCampaign.SCENES.size() == 9 and SlimerotRoster.ROWS.size() == 24 and SlimerotBalance.VARIANTS.size() == 8, "one Hub, eight zones, 24 base slimes and all eight variant combinations")
	check(SlimerotRollTree.MAINLINE.size() == 18 and SlimerotRollTree.OPTIONAL.size() == 9 and SlimerotCoinTree.ROWS.size() == 27 and SlimerotEncounters.BOSSES.size() == 4, "Prompt 13 tree additions and four bosses stay within the content scope")
	RollManager.variant_rng.seed = 1234
	check(RollManager.request_roll(), "fresh first roll commits")
	var starter: String = InventoryManager.equipped_copy_ids[0]
	check(GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1 and InventoryManager.pair_for_copy(starter).slime_id == SlimerotBalance.FIRST_SLIME, "first currency transaction owns and equips the guaranteed starter")
	# Funds are explicit test fixtures; purchases, rewards and deductions below
	# go through production methods. No fixture sets a zone, boss or structure flag.
	GameState.award_coins(100000000)
	var roll_budget := 0
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL: roll_budget += int(row[3])
	GameState.rolls_balance += roll_budget
	GameState.lifetime_rolls += roll_budget
	for row in SlimerotEncounters.STRUCTURES:
		if row[1] != 0: continue
		var before := GameState.coins
		interact_at(world, row[4])
		check(GameState.structure_unlocked_flags.get(row[0], false) and GameState.coins == before - int(row[2]), "%s repairs through its Hub interaction" % row[0])
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL:
		var before := [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls]
		var luck := RollManager.effective_luck()
		check(SkillTreeManager.purchase(row[0]), "%s remains reachable through the complete Roll mainline" % row[0])
		check(GameState.coins == before[0] and GameState.rolls_balance == before[1] - int(row[3]) and GameState.lifetime_rolls == before[2], "%s changes only spendable Rolls" % row[0])
		if row[0] in ["R08", "R13", "R18"]:
			check(is_equal_approx(RollManager.effective_luck(), luck * 20.0), "%s retains its exact x20 jump" % row[0])
	buy_available_coin_nodes()
	check(not SkillTreeManager.purchase("C06") and not SkillTreeManager.purchase("C10") and not SkillTreeManager.purchase("C15"), "all three late slots remain boss-gated despite enough Coins and tree progress")
	interact_at(world, Vector2(500, 1190))
	check(GameState.current_zone == 1, "physical Hub exit starts the same campaign journey")
	for zone in range(1, 9):
		freeze_combat(world)
		check(GameState.current_zone == zone and GameState.highest_zone_unlocked == zone, "Z%d is reached in campaign order without injected unlock flags" % zone)
		for row in SlimerotEncounters.STRUCTURES:
			if row[1] != zone: continue
			var before := GameState.coins
			interact_at(world, row[4])
			check(GameState.structure_unlocked_flags.get(row[0], false) and GameState.coins == before - int(row[2]), "%s repairs through its physical zone interaction" % row[0])
		buy_available_coin_nodes()
		var map: SlimerotZone = world.zone_root
		var enemy: SlimerotEnemy = map.get_children().filter(func(node): return node is SlimerotEnemy and node.data.archetype == "chaser")[0]
		world.player.position = SlimerotBalance.ENTRANCES[zone]
		var required: int = SlimerotCampaign.zone(zone).kill_requirement
		var wallet := GameState.coins
		var reward := roundi(enemy.data.coin_reward * (1.0 + SkillTreeManager.derived_stats().coin_scavenger))
		for index in required:
			enemy.take_damage(enemy.hp)
			enemy._physics_process(SlimerotCampaign.RESPAWN_SECONDS + 0.1)
		check(GameState.zone_kill_counts.get(str(zone), 0) == required and GameState.coins == wallet + required * reward, "Z%d real enemy deaths satisfy its kill gate with separate Scavenger rewards" % zone)
		if SlimerotEncounters.BOSSES.has(zone):
			wallet = GameState.coins
			interact_at(world, Vector2(770, 230))
			check(WorldManager.boss_active and is_instance_valid(world.arena), "Z%d physical boss entrance opens after the required kills" % zone)
			if not is_instance_valid(world.arena): return
			freeze_combat(world)
			var boss: SlimerotBoss = world.arena.boss
			boss.take_damage(boss.hp)
			check(WorldManager.is_boss_zone_defeated(zone) and not WorldManager.boss_active and GameState.coins == wallet + int(SlimerotEncounters.BOSSES[zone].coins), "Z%d arena defeat commits its fixed first reward without Scavenger" % zone)
			check(not WorldManager.start_boss(zone) and not WorldManager.finish_boss_reward(zone), "Z%d cannot replay its first-kill payout" % zone)
			buy_available_coin_nodes()
		var expected_slots := 5 if zone >= 6 else 4 if zone >= 4 else 3 if zone >= 2 else 2
		check(SkillTreeManager.derived_stats().equipped_slots == expected_slots, "Z%d team capacity reflects only the bosses already defeated" % zone)
		var before_gate := GameState.coins
		interact_at(world, SlimerotCampaign.EXIT_GATE)
		if zone < 8:
			check(GameState.current_zone == zone + 1 and WorldManager.gate_open(zone) and GameState.coins == before_gate - SlimerotCampaign.zone(zone).gate_coin_cost, "Z%d physical exit pays the current tuned cost and unlocks Z%d" % [zone, zone + 1])
			check(SlimeDatabase.eligible(GameState.highest_zone_unlocked).size() == 24 and RollManager.zone_luck_multiplier() == zone + 1, "Z%d gate raises zone luck without gating the 24-base pool" % zone)
		else:
			check(GameState.completion_portal_unlocked and GameState.campaign_completed and GameState.current_zone == 8 and GameState.coins == before_gate, "final portal completes without currency loss or leaving the playable campaign")
		world.hud.close_menu()
	check(GameState.purchased_skill_node_ids.size() == 54 and SkillTreeManager.derived_stats().equipped_slots == 5 and is_equal_approx(SkillTreeManager.derived_stats().damage_multiplier, 3.0), "all 54 progression nodes integrate with five slots and additive Final Bond")
	check(GameState.lifetime_rolls == GameState.rolls_balance + SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), "complete campaign purchases preserve Lifetime Rolls accounting")
	# Revisit late structures in completed free-roam, retaining copy protections.
	check(WorldManager.fast_travel(6), "completion retains Fast Travel to the Variant Shrine")
	freeze_combat(world)
	for index in 6: InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	var protected_copy: String = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].copy_ids[-1]
	InventoryManager.toggle_copy_favorite(protected_copy)
	var offering := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, 1)
	var shrine_wallet := GameState.coins
	check(InventoryManager.sacrifice(offering, 1) and GameState.coins == shrine_wallet and InventoryManager.shrine_count(1) == 1, "post-completion Shrine consumes one variant for one permanent unique boost")
	check(InventoryManager.is_protected(starter) and InventoryManager.is_protected(protected_copy) and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity == 7, "post-completion Shrine preserves the equipped starter and favorite")
	for row in SlimerotRoster.ROWS: InventoryManager.add_copy(row[0], "golden")
	InventoryManager.auto_equip_strongest()
	var team := InventoryManager.equipped_copy_ids.duplicate()
	check(team.size() == 5 and InventoryManager.collection().size() == 24 and InventoryManager.discoveries.size() == 24, "complete collection remains exactly 24 cards with a physical five-copy strongest team")
	check(InventoryManager.sell_copy(protected_copy) == 0 and InventoryManager.sell_copy(team[0]) == 0, "completed free-roam retains favorite and equipped sale protection")
	check(WorldManager.fast_travel(2), "completion retains Fast Travel to the Potion Bench")
	freeze_combat(world)
	check(WorldManager.craft_potion("hyper_soda") and WorldManager.craft_potion("boss_brew") and WorldManager.drink_potion("hyper_soda") and WorldManager.drink_potion("boss_brew"), "all post-boss potion recipes remain usable after completion")
	GameState._process(17.0)
	GameState.settings.auto_roll_state = true
	check(InventoryManager.set_auto_sell(true) and InventoryManager.set_auto_sell_threshold(1000) and RollManager.set_luck_cap(20.0), "endgame Auto Sell filters and Luck Cap remain usable")
	RollManager.cooldown_remaining = 0.25
	var state := SaveManager.snapshot()
	SaveManager.enabled = true
	check(SaveManager.save_game(), "the entire completed campaign serializes as one valid authoritative save")
	SaveManager.enabled = false
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	check(SaveManager.load_game(), "a fresh runtime restores the completed campaign save")
	freeze_combat(world)
	check(GameState.current_zone == 2 and GameState.highest_zone_unlocked == 8 and GameState.completion_portal_unlocked and GameState.campaign_completed, "saved current zone and completion state survive the integrated reload")
	check(same_json(GameState.boss_defeated_flags, state.boss_defeated_flags) and same_json(GameState.unlocked_gate_flags, state.unlocked_gate_flags) and same_json(GameState.structure_unlocked_flags, state.structure_unlocked_flags) and same_json(GameState.zone_kill_counts, state.zone_kill_counts), "all bosses, gates, structures and kill counters survive together")
	check(same_json(InventoryManager.inventory, state.inventory) and same_json(InventoryManager.discoveries, state.discoveries) and InventoryManager.equipped_copy_ids == team, "variants, quantities, favorites, discoveries and exact equipped identities survive together")
	check(same_json(GameState.roll_skill_spend, state.roll_skill_spend) and GameState.coins == state.coins and GameState.coins_earned == state.coins_earned and GameState.coins_spent == state.coins_spent and GameState.lifetime_rolls == state.lifetime_rolls, "currency balances, source statistics and historical Roll spend survive together")
	check(is_equal_approx(RollManager.effective_luck(), SkillTreeManager.derived_stats().luck * 3.0 * 8.0) and GameState.potion_remaining_seconds == 283 and GameState.boss_brew_seconds == 283 and RollManager.rolling_luck() == 20.0, "three saved Breakthroughs derive once while both active potion clocks and Luck Cap resume exactly")
	check(GameState.settings.auto_roll_state and GameState.settings.auto_sell_settings.enabled and GameState.settings.auto_sell_settings.threshold == 1000, "Auto Roll and filter choices survive the completed campaign reload")
	GameState.settings.auto_roll_state = false
	for zone in range(0, 9):
		check(WorldManager.fast_travel(zone) and world.player.position == SlimerotBalance.ENTRANCES[zone], "completed free-roam still reaches entrance %d after reloading" % zone)
		freeze_combat(world)
		await get_tree().process_frame
		check(get_tree().get_nodes_in_group("slimerot_enemies").size() == (0 if zone == 0 else 11) and get_tree().get_nodes_in_group("slimerot_bosses").is_empty(), "free-roam transition %d releases old enemies and defeated arenas" % zone)
	var completion_wallet := GameState.coins
	check(not WorldManager.finish_boss_reward(8) and GameState.coins == completion_wallet, "reloaded final boss flag prevents a second six-million-Coin reward")
	RollManager.cooldown_remaining = 0.0
	var lifetime := GameState.lifetime_rolls
	check(RollManager.request_roll() and GameState.lifetime_rolls == lifetime + 1, "free-roam remains rollable after completing and reloading")
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	WorldManager.travel(0)
	CombatManager.set_physics_process(true)
	for suffix in SlimerotSaveFormat.SUFFIXES:
		DirAccess.remove_absolute(SaveManager.save_path + suffix)
