extends Node

var suite: Node

func check(value: bool, label: String) -> void:
	suite.check(value, "Final16 RNG · " + label)

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	SaveManager.enabled = false
	world.hud.close_menu()
	var processing := [GameState.is_processing(), RollManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	CombatManager.set_physics_process(false)
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	WorldManager.travel(0)
	var rows := SlimeDatabase.power_audit_rows()
	check(rows.size() == 192 and SlimeDatabase.slimes.size() == 24, "canonical debug table includes all 24 bases times eight masks")
	var monotonic := true
	var exact := true
	var prior_damage := 0
	var unique := {}
	var markdown := "# Slimerot final power audit\n\nGenerated from the live canonical helpers. All 24 bases are eligible from Z1; origin is metadata. Raw damage precedes team/boss modifiers.\n\n| Base | Origin | Mask | Variant | Effective rarity | Raw damage |\n|---|---:|---:|---|---:|---:|\n"
	for row in rows:
		unique[row.base_id + ":" + str(row.variant_mask)] = true
		monotonic = monotonic and row.raw_damage >= prior_damage
		prior_damage = row.raw_damage
		var denominator := 1
		for bit in 3:
			if row.variant_mask & (1 << bit): denominator *= [100, 400, 1600][bit]
		exact = exact and row.effective_rarity == row.base_threshold * denominator and row.raw_damage == roundi(6.0 * pow(float(row.effective_rarity), 0.32))
		markdown += "| %s | %d | %d | %s | %d | %d |\n" % [row.base_id, row.origin_zone, row.variant_mask, row.variant, row.effective_rarity, row.raw_damage]
	check(unique.size() == 192 and exact, "every rarity denominator/product and rounded raw damage matches the feedback formula")
	check(monotonic, "higher effective rarity never lowers raw damage across all 192 outcomes")
	check(SlimeDatabase.get_effective_rarity(SlimerotBalance.FIRST_SLIME, 1) == 200 and SlimeDatabase.get_base_combat_damage(SlimerotBalance.FIRST_SLIME, 1) == SlimerotRoster.damage(200), "Shiny 1/2 has the same rarity and raw-power class as Normal 1/200")
	var table := FileAccess.open("res://.godot/Slimerot-Prompt-16-Power-Table.md", FileAccess.WRITE)
	check(table != null, "debug power table export is writable in the isolated test directory")
	if table != null:
		table.store_string(markdown)
		table.close()
	for zone in range(1, 9):
		check(SlimeDatabase.eligible(zone).size() == 24 and RollManager.select_base(1.0, 1.0 / 4000000.0, zone) == "brainrot_singularity", "Z%d retains the complete base chase including the rarest base" % zone)
	for nodes in [["R08"], ["R08", "R13"], ["R08", "R13", "R18"]]:
		var expected := pow(20.0, nodes.size())
		var parts := RollManager.get_luck_breakdown({"node_ids":nodes, "highest_zone_unlocked":8, "active_potion_multiplier":3.0, "super_roll_multiplier":20.0})
		check(parts.breakthrough_product == expected and parts.total == expected * 8.0 * 3.0 * 20.0, "%d Breakthroughs contribute exactly x%d and zone/potion/current Super apply once" % [nodes.size(), expected])
	var parts := RollManager.get_luck_breakdown({"node_ids":["R02", "C20", "C21", "C22"], "highest_zone_unlocked":3})
	check(is_equal_approx(parts.total, 1.10 * 1.15 * 1.20 * 1.25 * 3.0), "minor and Fortune products flow through the central effective-luck function")
	var summary_queue := SlimerotRollRevealQueue.new()
	var presented_records := [0]
	var best_presented := [0]
	summary_queue.started.connect(func(item: Dictionary):
		if item.get("power_improvement", false):
			presented_records[0] += int(item.get("summarized_best_count", 1))
			best_presented[0] = maxi(best_presented[0], int(item.effective_rarity)))
	var before := [GameState.rolls_balance, GameState.lifetime_rolls, InventoryManager.inventory.size()]
	for index in 100:
		summary_queue.enqueue({"slime_id":SlimerotBalance.FIRST_SLIME,"variant":"shiny","variant_flags":1,"threshold":2,"effective_rarity":200 + index,"power_improvement":true,"first_discovery":false})
	check(summary_queue.pending.size() <= 32 and not summary_queue.record_summary.is_empty(), "100-record overload stays bounded and retains an explicit compressed-record summary")
	for index in 150: summary_queue.advance(10.0)
	check(presented_records[0] == 100 and best_presented[0] == 299 and summary_queue.pending.is_empty() and summary_queue.record_summary.is_empty(), "every displaced power record is represented and the highest record is actually presented")
	check(before == [GameState.rolls_balance, GameState.lifetime_rolls, InventoryManager.inventory.size()], "draining ordinary and summarized reveals grants no rewards")
	await test_record_summary_ui(world)
	var replay := RollManager.resolve_roll()
	check(RollManager.commit_roll(replay) and not RollManager.commit_roll(replay) and GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1, "one issued logical roll accepts one commit and credits exactly +1/+1")
	var coins := GameState.coins
	RollManager.cooldown_remaining = 0
	check(RollManager.request_roll() and GameState.coins == coins and GameState.rolls_balance == 2 and GameState.lifetime_rolls == 2, "ROLL press is free and uses the same sole commit path")
	var offline: Dictionary = await RollManager.process_offline_rolls(23)
	check(offline.rolls == 23 and GameState.rolls_balance == 25 and GameState.lifetime_rolls == 25, "23 offline logical commits credit exactly 23 Rolls and Lifetime Rolls")
	RollManager.reset()
	InventoryManager.reset()
	GameState.reset()
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	CombatManager.set_physics_process(processing[2])

func test_record_summary_ui(world: Node) -> void:
	var result := {"slime_id":"brainrot_singularity", "variant":"shiny_glitched_golden", "variant_flags":7,
		"threshold":4000000, "effective_rarity":SlimeDatabase.get_effective_rarity("brainrot_singularity", 7),
		"power_improvement":true, "first_discovery":false, "summarized_best_count":68}
	result.variant = SlimerotVariants.key(7)
	RollManager.presentation.start(result)
	for frame in 3: await get_tree().process_frame
	var reveal: SlimerotReveal = world.hud.reveal
	check(reveal.visible and reveal.heading.text == "68 POWER RECORDS" and reveal.label.text.begins_with("68 RECORDS:"), "overflow summary visibly names its record count and strongest slime")
	check(Rect2(Vector2.ZERO, reveal.size).encloses(reveal.card.get_rect()), "record summary fits the portrait viewport")
	await suite.capture("Slimerot-p16-record-summary")
	WorldManager.boss_active = true
	reveal.layout_card()
	for frame in 3: await get_tree().process_frame
	check(reveal.combat_compact and reveal.label.text.begins_with("68 RECORDS:") and reveal.card.position.y + reveal.card.size.y <= 200.0, "combat summary preserves its record count inside the passive currency-header strip")
	await suite.capture("Slimerot-p16-record-summary-combat")
	WorldManager.boss_active = false
	RollManager.presentation.clear()
