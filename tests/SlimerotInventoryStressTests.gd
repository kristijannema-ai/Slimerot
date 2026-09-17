extends Node

# Slimerot P0 regression: millions of copies remain 192 data stacks and five winners.
func run(world: Node, suite: Node) -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	WorldManager.travel(0)
	GameState.menu_paused = true
	var counts := {"team": 0, "inventory": 0, "state": 0, "critical": 0}
	var team_observer := func(): counts.team += 1
	var inventory_observer := func(): counts.inventory += 1
	var state_observer := func(): counts.state += 1
	var critical_observer := func(_reason): counts.critical += 1
	InventoryManager.team_changed.connect(team_observer)
	InventoryManager.inventory_changed.connect(inventory_observer)
	GameState.changed.connect(state_observer)
	GameState.critical_change.connect(critical_observer)
	var total := 0
	for row in SlimerotRoster.ROWS:
		for variant in SlimerotBalance.VARIANTS:
			var result := InventoryManager.add_copies(row[0], variant, 100003)
			total += int(result.quantity)
	GameState.lifetime_rolls = total
	GameState.rolls_balance = total
	suite.check(InventoryManager.inventory.size() == 192 and total == 19200576, "192 compact variant stacks own over 19.2 million physical copies")
	var compact := true
	for pair in InventoryManager.inventory.values(): compact = compact and pair.copy_ids.is_empty() and pair.copy_ranges.size() == 1 and pair.quantity == 100003
	suite.check(compact and counts.state == 0 and counts.inventory == 0, "Bulk allocation creates no per-copy arrays or per-copy notifications")
	var winner: Dictionary = InventoryManager.inventory["brainrot_singularity:shiny+glitched+golden"]
	var strongest_damage := float(SlimeDatabase.get_base_combat_damage("brainrot_singularity", 7))
	var slot_nodes := [[], ["C01", "C02"], ["C01", "C02", "C05", "C06"], ["C01", "C02", "C05", "C06", "C08", "C10"], ["C01", "C02", "C05", "C06", "C08", "C10", "C13", "C15"]]
	for slots in range(1, 6):
		GameState.purchased_skill_node_ids.assign(slot_nodes[slots - 1])
		var before := counts.duplicate()
		var changed := InventoryManager.auto_equip_strongest()
		var expected: Array[String] = []
		for index in slots: expected.append(InventoryManager.copy_name(int(winner.copy_ranges[0][0]) + index))
		suite.check(changed and InventoryManager.equipped_copy_ids == expected, "Equip Best chooses the mathematically strongest %d owned physical copies" % slots)
		suite.check(counts.team == before.team + 1 and counts.state == before.state + 1 and counts.inventory == before.inventory and counts.critical == before.critical + 1, "Equip Best commits slot count %d once, with one HUD signal and one save event" % slots)
		var expected_per_hit := roundf(SlimeDatabase.get_base_combat_damage("brainrot_singularity", 7) * SkillTreeManager.derived_stats().damage_multiplier)
		suite.check(InventoryManager.team_dps() == slots * expected_per_hit and expected_per_hit >= strongest_damage, "Team DPS reflects the selected %d copies" % slots)
	await get_tree().process_frame
	await get_tree().process_frame
	var node_count := get_tree().get_node_count()
	var before_repeat := counts.duplicate()
	var started := Time.get_ticks_usec()
	var unchanged := true
	for index in 100: unchanged = not InventoryManager.auto_equip_strongest() and unchanged
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	await get_tree().process_frame
	suite.check(unchanged and counts == before_repeat and get_tree().get_node_count() == node_count, "100 repeated Equip Best requests create no notifications, saves, UI rebuilds or scene nodes")
	suite.check(elapsed_ms < 2000, "100 Equip Best operations over 19.2 million copies complete without a multi-second freeze")
	print("Slimerot INVENTORY STRESS: unique_stacks=192 copies=%d equip_best_100_ms=%.3f" % [total, elapsed_ms])
	suite.check(InventoryManager.validate_saved_inventory(InventoryManager.inventory, InventoryManager.equipped_copy_ids, InventoryManager.next_copy_id).is_empty(), "Compact inventory validates without expanding serial ranges")
	var page := InventoryManager.copies_page(winner, 99996, 12)
	suite.check(page.size() == 7 and page[0] == InventoryManager.copy_name(int(winner.copy_ranges[0][0]) + 99996), "Copy pagination jumps directly to the end of a huge stack")
	var invalid := InventoryManager.inventory.duplicate(true)
	invalid["brainrot_singularity:golden"].copy_ranges.append([1, 2])
	invalid["brainrot_singularity:golden"].quantity += 2
	suite.check(not InventoryManager.validate_saved_inventory(invalid, [], InventoryManager.next_copy_id).is_empty(), "Save validation rejects a compact copy range shared by two stacks")
	InventoryManager.team_changed.disconnect(team_observer)
	InventoryManager.inventory_changed.disconnect(inventory_observer)
	GameState.changed.disconnect(state_observer)
	GameState.critical_change.disconnect(critical_observer)

	InventoryManager.reset()
	for index in 100003:
		InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false)
	var legacy_pair: Dictionary = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	suite.check(legacy_pair.copy_ids.is_empty() and legacy_pair.copy_ranges.size() == 1 and legacy_pair.quantity == 100003, "Long foreground sessions also compact physical identities before saves can grow per-copy arrays")
	# Construct an actual old-format array to exercise the compatibility path.
	legacy_pair.copy_ranges = []
	for index in 100003: legacy_pair.copy_ids.append(InventoryManager.copy_name(index + 1))
	InventoryManager.auto_equip_strongest()
	started = Time.get_ticks_usec()
	for index in 100: InventoryManager.auto_equip_strongest()
	var legacy_elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	suite.check(legacy_pair.copy_ids.size() == 100003 and InventoryManager.equipped_copy_ids == ["slimerot_copy_1", "slimerot_copy_2", "slimerot_copy_3", "slimerot_copy_4", "slimerot_copy_5"] and legacy_elapsed_ms < 2000, "Legacy 100,003-copy arrays also support 100 bounded Equip Best transactions without expansion or full-array scans")
	suite.check(InventoryManager.copy_lookup_cache.size() <= InventoryManager.LOOKUP_CACHE_LIMIT, "Repeated copy lookup keeps its runtime cache bounded independently of inventory quantity")
	print("Slimerot INVENTORY STRESS: legacy_copies=100003 equip_best_100_ms=%.3f" % legacy_elapsed_ms)
	legacy_pair.favorite_copy_ids.assign(["slimerot_copy_99999"])
	InventoryManager.compact_inventory()
	suite.check(legacy_pair.copy_ids.is_empty() and legacy_pair.copy_ranges == [[1, 100003]] and InventoryManager.is_protected("slimerot_copy_99999") and InventoryManager.equipped_copy_ids.size() == 5, "Legacy compaction preserves exact equipped and favorite identities without retaining a huge copy array")
	# Fragmentation must not turn selection back into a quantity-sized scan.
	legacy_pair.copy_ranges = []
	for index in 100003: legacy_pair.copy_ranges.append([index * 2 + 1, index * 2 + 1])
	InventoryManager.next_copy_id = 200007
	InventoryManager.invalidate_lookup_cache()
	started = Time.get_ticks_usec()
	for index in 100: InventoryManager.auto_equip_strongest()
	var fragmented_ms := float(Time.get_ticks_usec() - started) / 1000.0
	suite.check(fragmented_ms < 2000 and InventoryManager.equipped_copy_ids == ["slimerot_copy_1", "slimerot_copy_3", "slimerot_copy_5", "slimerot_copy_7", "slimerot_copy_9"], "Equip Best remains bounded even across 100,003 fragmented ownership ranges")
	print("Slimerot INVENTORY STRESS: fragmented_ranges=100003 equip_best_100_ms=%.3f" % fragmented_ms)
	InventoryManager.reset()
	var best_two := InventoryManager.add_copies("brainrot_singularity", "golden", 2)
	var next_three := InventoryManager.add_copies("nuclear_bombardiro", "golden", 3)
	InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100003)
	InventoryManager.toggle_copy_favorite(best_two.first_copy_id)
	InventoryManager.auto_equip_strongest()
	suite.check(InventoryManager.equipped_copy_ids == ["slimerot_copy_1", "slimerot_copy_2", "slimerot_copy_3", "slimerot_copy_4", "slimerot_copy_5"] and InventoryManager.is_protected(best_two.first_copy_id) and next_three.kept == 3, "Equip Best fills across unique stacks, never exceeds either owned quantity, and preserves favorite protection")

	InventoryManager.reset()
	var bulk := InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100005)
	var pair: Dictionary = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	InventoryManager.auto_equip_strongest()
	InventoryManager.toggle_copy_favorite("slimerot_copy_6")
	suite.check(InventoryManager.mutation_candidate_count(SlimerotBalance.FIRST_SLIME) == 99999 and InventoryManager.mutation_candidates(SlimerotBalance.FIRST_SLIME) == ["slimerot_copy_7", "slimerot_copy_8", "slimerot_copy_9", "slimerot_copy_10", "slimerot_copy_11"], "Mutation counts a huge stack but materializes only five unprotected candidates")
	GameState.structure_unlocked_flags.mutation_lab = true
	GameState.structure_unlocked_flags.sell_terminal = true
	GameState.current_zone = 6
	GameState.menu_paused = false
	GameState.coins = 1000
	GameState.coins_earned = 1000
	var shrine_copy := InventoryManager.add_copy("brr_brr_patapim", 3)
	suite.check(InventoryManager.sacrifice(shrine_copy, 2) and pair.quantity == 100005 and GameState.coins == 1000 and InventoryManager.is_protected("slimerot_copy_6") and InventoryManager.pair_for_copy(shrine_copy).is_empty(), "Shrine consumes one exact unprotected compact-compatible identity without touching Normal stacks or charging Coins")
	GameState.menu_paused = true
	var value := InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME + ":normal")
	suite.check(InventoryManager.sell_duplicates() == 99999 * value and pair.quantity == 6 and InventoryManager.equipped_copy_ids.size() == 5 and InventoryManager.is_protected("slimerot_copy_6"), "Bulk duplicate sale retains equipped and favorite identities without expanding quantities")
	suite.check(InventoryManager.sell_duplicates() == 0, "Repeated compact duplicate sale cannot pay twice")
	InventoryManager.reset()
	bulk = InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100000)
	pair = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	InventoryManager.toggle_favorite(SlimerotBalance.FIRST_SLIME + ":normal")
	InventoryManager.toggle_copy_favorite("slimerot_copy_50000")
	suite.check(not InventoryManager.is_protected("slimerot_copy_50000") and InventoryManager.is_protected("slimerot_copy_49999") and InventoryManager.is_protected("slimerot_copy_50001") and pair.favorite_copy_ids.is_empty() and pair.favorite_copy_ranges.size() == 2, "Unfavoriting one copy of a huge group preserves every other favorite with two compact ranges")
	suite.check(InventoryManager.sell_copy("slimerot_copy_50000") > 0 and pair.quantity == 99999 and InventoryManager.validate_saved_inventory(InventoryManager.inventory, [], InventoryManager.next_copy_id).is_empty(), "Individual sale splits compact ownership while preserving save-valid favorite ranges")
	InventoryManager.reset()
	GameState.purchased_skill_node_ids.assign(["RO2"])
	GameState.settings.auto_sell_settings.enabled = true
	var before_coins := GameState.coins
	bulk = InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100000, false, true)
	pair = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	suite.check(bulk.sold == 99999 and bulk.kept == 1 and pair.quantity == 1 and GameState.coins == before_coins + bulk.coins and InventoryManager.discoveries.has(SlimerotBalance.FIRST_SLIME), "Batched auto-sale keeps the first Normal, records discovery and pays each duplicate once")
	InventoryManager.toggle_favorite(SlimerotBalance.FIRST_SLIME + ":normal")
	bulk = InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100000, false, true)
	suite.check(bulk.sold == 0 and pair.quantity == 100001 and InventoryManager.is_protected(bulk.last_copy_id), "Bulk Auto Roll respects group favorites and never auto-sells protected copies")
	InventoryManager.reset()
	InventoryManager.next_copy_id = SlimerotSaveFormat.MAX_EXACT_INTEGER - 1
	var last_exact_copy := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false)
	suite.check(not last_exact_copy.is_empty() and InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false).is_empty() and InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 2).is_empty() and InventoryManager.next_copy_id == SlimerotSaveFormat.MAX_EXACT_INTEGER and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity == 1, "Copy allocation rejects numerical overflow before mutating ownership or the next serial")
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	WorldManager.travel(0)
	await get_tree().process_frame
