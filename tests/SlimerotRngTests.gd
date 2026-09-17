extends Node

var suite: Node
var world: Node

func check(value: bool, description: String) -> void:
	suite.check(value, "RNG12 · " + description)

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
	WorldManager.travel(0)
	RollManager.rng.seed = 12001
	RollManager.variant_rng.seed = 1234

func counts() -> Dictionary:
	var result := {}
	for key in InventoryManager.inventory: result[key] = InventoryManager.inventory[key].quantity
	return result

func run(game_world: Node, owner_suite: Node) -> void:
	world = game_world
	suite = owner_suite
	var original_path: String = SaveManager.save_path
	var enabled := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	SaveManager.save_path = "res://.godot/Slimerot-rng12-%d.json" % OS.get_process_id()
	fresh()
	test_variants_and_pool()
	test_commits_and_pity()
	await test_offline_parity()
	test_shrine()
	test_migration()
	test_queue()
	await test_live_presentation()
	fresh()
	for suffix in SlimerotSaveFormat.SUFFIXES + [".bak.tmp"]:
		DirAccess.remove_absolute(SaveManager.save_path + suffix)
	SaveManager.save_path = original_path
	GameState.set_process(enabled[0])
	RollManager.set_process(enabled[1])
	SaveManager.set_process(enabled[2])
	CombatManager.set_physics_process(enabled[3])
	await get_tree().process_frame

func test_variants_and_pool() -> void:
	check(SlimeDatabase.eligible(1).size() == 24 and SlimeDatabase.eligible(8).size() == 24, "all 24 bases are eligible from the start")
	for slime in SlimeDatabase.eligible():
		check(RollManager.select_base(1.0, 1.0 / slime.rarity_threshold, 1) == slime.id, "Z1 score can select " + slime.id)
	check(RollManager.effective_luck() == 1.0, "Z1 luck is x1; Hub is not counted")
	GameState.highest_zone_unlocked = 8
	check(RollManager.effective_luck() == 8.0, "Z8 luck is x8")
	GameState.highest_zone_unlocked = 1
	var chances := RollManager.variant_probabilities()
	check(chances == [0.01, 1.0 / 400.0, 1.0 / 1600.0], "independent base probabilities are 1/100, 1/400 and 1/1600")
	for flags in 8:
		var draws: Array = []
		for index in 3: draws.append(0.0 if flags & (1 << index) else 0.99)
		check(RollManager.select_variant_flags(draws, chances) == flags, "three independent draws support mask %d" % flags)
	check(SlimeDatabase.get_effective_rarity(SlimerotBalance.FIRST_SLIME, 1) == 200 and SlimeDatabase.get_effective_rarity(SlimerotBalance.FIRST_SLIME, 3) == 80000, "canonical rarity multiplies all active denominators")
	check(SlimeDatabase.get_base_combat_damage(SlimerotBalance.FIRST_SLIME, 1) == SlimerotRoster.damage(200), "Shiny 1/2 and Normal threshold-200 have identical raw damage")
	for flags in 8:
		var copy := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, flags)
		check(InventoryManager.pair_for_copy(copy).variant_flags == flags and InventoryManager.damage_for_copy(copy) == SlimeDatabase.get_base_combat_damage(SlimerotBalance.FIRST_SLIME, flags), "mask %d ownership and combat share the central helper" % flags)
	InventoryManager.auto_equip_strongest()
	check(InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[0]).variant_flags == 7, "Equip Best ranks the combined canonical damage")

func test_commits_and_pity() -> void:
	fresh()
	var first := RollManager.resolve_roll()
	check(first == RollManager.resolve_roll() and GameState.lifetime_rolls == 0 and InventoryManager.inventory.is_empty(), "resolution consumes no reward and returns one pending logical roll")
	check(RollManager.commit_roll(first) and GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1, "one committed result grants exactly both counters once")
	check(not RollManager.commit_roll(first) and GameState.lifetime_rolls == 1, "a committed result cannot be replayed")
	var stale := RollManager.resolve_roll()
	RollManager.reset()
	check(not RollManager.commit_roll(stale), "reset/load generations reject stale resolved results")
	var probabilities := RollManager.variant_probabilities()
	var only_top := SlimerotPity.distribution(SlimeDatabase.eligible(), 4000000.0, probabilities, 4000000)
	var expected := 1.0
	for chance in probabilities: expected *= 1.0 - ceil(chance * 4294967296.0) / 4294967296.0
	check(absf(only_top.p_better - (1.0 - expected)) < 0.0000000001, "P_better includes the complete independent joint variant distribution")
	for best in [2, 200, 80000, 4000000, SlimeDatabase.get_effective_rarity("brainrot_singularity", 7)]:
		for luck in [1.0, 2730.0]:
			var distribution := SlimerotPity.distribution(SlimeDatabase.eligible(), luck, probabilities, best)
			var valid := true
			for outcome in distribution.outcomes: valid = valid and SlimeDatabase.get_effective_rarity(outcome.slime_id, outcome.variant_flags) > best
			check(valid and distribution.p_better >= 0.0 and distribution.p_better <= 1.0, "pity conditional outcomes are valid and stronger at best %d luck %.0f" % [best, luck])
			if distribution.p_better == 0.0:
				check(distribution.guarantee_roll == 0 and distribution.outcomes.is_empty(), "maximum possible power disables pity")
			else:
				check(distribution.guarantee_roll == ceili(3.0 / distribution.p_better), "hard deadline is ceil(3 / P_better)")
	for best in [2, 200, 80000]:
		fresh()
		GameState.best_ever_effective_rarity = best
		var distribution := RollManager.pity_distribution(1.0, probabilities, best)
		var deadline: int = distribution.guarantee_roll
		GameState.lifetime_rolls = deadline
		GameState.rolls_balance = deadline
		GameState.rolls_since_last_power_improvement = deadline - 1
		var guaranteed := RollManager.resolve_roll()
		check(guaranteed.data.effective_rarity > best and RollManager.commit_roll(guaranteed) and GameState.rolls_since_last_power_improvement == 0, "at the deadline a valid stronger result commits and resets the counter")
	fresh()
	GameState.lifetime_rolls = 1
	GameState.rolls_balance = 1
	GameState.best_ever_effective_rarity = 200
	GameState.rolls_since_last_power_improvement = 50
	RollManager.rng.seed = 994
	RollManager.variant_rng.seed = 119
	var one := RollManager.resolve_roll().data.duplicate(true)
	RollManager.reset()
	RollManager.rng.seed = 994
	RollManager.variant_rng.seed = 119
	check(RollManager.resolve_roll().data == one, "seeded pity resolution is deterministic")
	RollManager.reset()
	check(SlimerotPity.assist_chance(100, 100.0) == 0.0 and is_equal_approx(SlimerotPity.assist_chance(200, 100.0), 0.125) and SlimerotPity.assist_chance(300, 100.0) == 0.25, "soft pity smoothly ramps from 1x to 3x expected with 25% maximum")

func test_offline_parity() -> void:
	fresh()
	GameState.lifetime_rolls = 10000
	GameState.rolls_balance = 10000
	for row in SlimerotRollTree.MAINLINE.slice(0, 13): assert(SkillTreeManager.purchase(row[0]))
	GameState.highest_zone_unlocked = 8
	var snapshot := SaveManager.snapshot()
	RollManager.rng.seed = 8912
	RollManager.variant_rng.seed = 6772
	for index in 200:
		RollManager.cooldown_remaining = 0.0
		assert(RollManager.request_roll())
	var online := [counts(), GameState.lifetime_rolls, GameState.rolls_balance, GameState.best_ever_effective_rarity, GameState.rolls_since_last_power_improvement, RollManager.rng.state, RollManager.variant_rng.state]
	SaveManager.apply_snapshot(snapshot)
	RollManager.rng.seed = 8912
	RollManager.variant_rng.seed = 6772
	var offline: Dictionary = await RollManager.process_offline_rolls(200)
	check([counts(), GameState.lifetime_rolls, GameState.rolls_balance, GameState.best_ever_effective_rarity, GameState.rolls_since_last_power_improvement, RollManager.rng.state, RollManager.variant_rng.state] == online, "200 online/offline rolls have identical rewards, combinations, pity and both RNG streams")
	check(offline.rolls == 200 and offline.rolls_earned == 200 and RollManager.reveal_queue.is_empty() and RollManager.active_reveal.is_empty(), "offline uses the shared commit backend and no per-roll cinematics")
	check(offline.best_drop.effective_rarity == GameState.best_ever_effective_rarity and offline.best_drop.has("variant_flags") and offline.has("new_variant_discoveries"), "AFK summary describes the strongest combined drop and new masks")

func test_shrine() -> void:
	fresh()
	GameState.lifetime_rolls = 100
	GameState.rolls_balance = 100
	GameState.highest_zone_unlocked = 6
	GameState.current_zone = 6
	GameState.structure_unlocked_flags.mutation_lab = true
	var coins := GameState.coins
	for index in 3:
		var id: String = SlimerotRoster.ROWS[index][0]
		var copy := InventoryManager.add_copy(id, 3)
		var duplicate := InventoryManager.add_copy(id, 3)
		check(InventoryManager.sacrifice(copy, 1) and not InventoryManager.sacrifice(duplicate, 1), "one unique base may contribute only once to the chosen category")
		check(InventoryManager.pair_for_copy(duplicate).quantity == 1, "duplicate rejection consumes no copy")
	check(is_equal_approx(InventoryManager.shrine_multiplier(1), pow(1.05, 3)) and InventoryManager.shrine_count(2) == 0 and GameState.coins == coins, "three unique Shiny offerings give 1.05^3 and no other category or Coin charge")
	var both := InventoryManager.add_copy("ballerina_cappuccina", 7)
	InventoryManager.equipped_copy_ids.assign([both])
	check(not InventoryManager.sacrifice(both, 4), "equipped combined copies are protected")
	InventoryManager.equipped_copy_ids.clear()
	InventoryManager.toggle_copy_favorite(both)
	check(not InventoryManager.sacrifice(both, 4), "favorite combined copies are protected")
	InventoryManager.toggle_copy_favorite(both)
	check(InventoryManager.sacrifice(both, 4) and InventoryManager.pair_for_copy(both).is_empty() and InventoryManager.shrine_count(4) == 1 and InventoryManager.shrine_count(2) == 0, "one multivariant copy contributes to exactly one selected category")
	var normal := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	check(not InventoryManager.sacrifice(normal, 1) and not InventoryManager.mutate(SlimerotBalance.FIRST_SLIME), "Normal sacrifice and the old five-Normal mutator are disabled")
	check(SlimeDatabase.get_effective_rarity(SlimerotBalance.FIRST_SLIME, 1) == 200, "Shrine odds do not reduce canonical rarity or damage")

func test_migration() -> void:
	fresh()
	GameState.lifetime_rolls = 20000
	GameState.rolls_balance = 20000
	var protected := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "golden")
	InventoryManager.equipped_copy_ids.assign([protected])
	InventoryManager.toggle_copy_favorite(protected)
	InventoryManager.add_copies("brr_brr_patapim", "shiny", 10000)
	var legacy := SaveManager.snapshot()
	legacy.schema_version = 9
	for field in ["best_ever_effective_rarity", "rolls_since_last_power_improvement", "shrine_sacrifices"]: legacy.erase(field)
	for pair in legacy.inventory.values(): pair.erase("variant_flags")
	var migrated: Dictionary = SaveManager.migrate(JSON.parse_string(JSON.stringify(legacy)))
	check(SaveManager.validate(migrated) and migrated.inventory["brr_brr_patapim:shiny"].quantity == 10000, "schema9 migration preserves compact quantities")
	SaveManager.apply_snapshot(migrated)
	check(InventoryManager.is_protected(protected) and InventoryManager.equipped_copy_ids == [protected] and InventoryManager.pair_for_copy(protected).variant_flags == 4, "legacy migration preserves exact favorites, equipped IDs and single flags")
	for flags in 8: InventoryManager.add_copy("brainrot_singularity", flags)
	GameState.highest_zone_unlocked = 8
	GameState.rolls_since_last_power_improvement = 37
	GameState.shrine_sacrifices.shiny = [SlimerotBalance.FIRST_SLIME]
	var maximum := GameState.best_ever_effective_rarity
	GameState.structure_unlocked_flags.sell_terminal = true
	var sold := InventoryManager.copies_page(InventoryManager.inventory["brainrot_singularity:shiny+glitched+golden"], 0, 1)[0]
	check(InventoryManager.sell_copy(sold) > 0 and GameState.best_ever_effective_rarity == maximum, "selling the all-time best does not reset the pity target")
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.best_ever_effective_rarity == maximum and GameState.rolls_since_last_power_improvement == 37 and InventoryManager.shrine_count(1) == 1, "schema10 persists combined discoveries, pity and Shrine sets")
	check(RollManager.effective_luck() == 8.0 and SaveManager.load_game() and RollManager.effective_luck() == 8.0, "zone luck derives once across repeated loads")
	var bad := legacy.duplicate(true)
	bad.inventory["brr_brr_patapim:shiny"].variant_flags = 8
	check(not SaveManager.validate(SaveManager.migrate(bad)), "a malformed legacy mask fails migration validation")
	var invalid := SaveManager.snapshot()
	invalid.shrine_sacrifices.shiny.append(SlimerotBalance.FIRST_SLIME)
	var bytes := FileAccess.get_file_as_string(SaveManager.save_path)
	check(not SaveManager.write_snapshot(invalid) and FileAccess.get_file_as_string(SaveManager.save_path) == bytes, "invalid duplicate sacrifices cannot overwrite a valid save")
	SaveManager.enabled = false

func test_queue() -> void:
	fresh()
	var queue := SlimerotRollRevealQueue.new()
	var small := {"slime_id": SlimerotBalance.FIRST_SLIME, "variant": "normal", "variant_flags": 0, "threshold": 2, "effective_rarity": 2, "luck_used": 2730.0, "damage": 7.0, "weakest_equipped_damage": 100.0, "first_discovery": false}
	check(SlimerotPresentation.adaptive_tier(small) == 0, "Luck2730 low-power ordinary outcomes remain small toasts")
	var relevant := small.duplicate(true)
	relevant.damage = 85.0
	check(SlimerotPresentation.adaptive_tier(relevant) >= 2, "85%-of-weakest slightly worse results remain meaningful")
	relevant.damage = 101.0
	check(SlimerotPresentation.adaptive_tier(relevant) >= 2, "a team improvement always gets a meaningful reveal")
	queue.enqueue(relevant)
	queue.enqueue(relevant)
	var currencies := [GameState.rolls_balance, GameState.lifetime_rolls]
	queue.advance(queue.remaining)
	check(queue.active.is_empty() and queue.pending.size() == 1 and queue.major_gap_remaining == 5.0, "second rare sequence waits after first sequence ends")
	queue.advance(4.99)
	check(queue.active.is_empty(), "major gap cannot finish before five seconds")
	queue.advance(0.02)
	check(not queue.active.is_empty() and [GameState.rolls_balance, GameState.lifetime_rolls] == currencies, "delayed reveal starts without duplicating currency")
	queue.skip()
	check(queue.major_gap_remaining == 5.0, "skipping a major sequence still enforces its breathing room")
	for index in 100: queue.enqueue(small)
	check(queue.pending.size() <= SlimerotPresentation.MAX_PENDING_REVEALS, "high-frequency reveal feedback remains bounded")

func test_live_presentation() -> void:
	fresh()
	GameState.lifetime_rolls = 140
	GameState.rolls_balance = 140
	for id in ["R01", "R03", "R02"]: assert(SkillTreeManager.purchase(id))
	InventoryManager.equip(InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME))
	var result := {"slime_id": "brainrot_singularity", "variant": SlimerotVariants.key(7), "variant_flags": 7,
		"threshold": 4000000, "effective_rarity": SlimeDatabase.get_effective_rarity("brainrot_singularity", 7), "luck_used": 1.0,
		"first_roll": false, "first_discovery": true, "power_improvement": true}
	RollManager.queue_reveal(result)
	GameState.settings.auto_roll_state = true
	GameState.set_process(true)
	RollManager.set_process(true)
	var before: int = GameState.lifetime_rolls
	var wallet: int = GameState.rolls_balance
	var position_before: Vector2 = world.player.position
	Input.action_press("move_right")
	for frame in 45: await get_tree().physics_frame
	Input.action_release("move_right")
	for frame in 120: await get_tree().physics_frame
	check(GameState.lifetime_rolls >= before + 2 and GameState.rolls_balance - wallet == GameState.lifetime_rolls - before,
		"live Auto Roll commits exactly once per roll during a five-second major reveal")
	check(not RollManager.active_reveal.is_empty() and RollManager.active_reveal.slime_id == "brainrot_singularity" and world.player.position.distance_to(position_before) > 60.0,
		"major reveal leaves scene physics and movement running")
	GameState.settings.auto_roll_state = false
	GameState.set_process(false)
	RollManager.set_process(false)
	await suite.capture("Slimerot-p12-combined-reveal")
	RollManager.reset()
	GameState.highest_zone_unlocked = 6
	GameState.structure_unlocked_flags.mutation_lab = true
	WorldManager.travel(6)
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, 7)
	world.hud.open_menu("Variant Shrine")
	await get_tree().process_frame
	await get_tree().process_frame
	await suite.capture("Slimerot-p12-variant-shrine")
	world.hud.close_menu()
