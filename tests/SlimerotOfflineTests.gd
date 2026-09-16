extends Node

# Slimerot AFK tests use a private profile and injected wall-clock times. They never
# read or replace user:// progress and never wait for real background time.
var suite: Node
var world: Node

func check(condition: bool, label: String) -> void:
	suite.check(condition, "AFK · " + label)

func same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func clear_files() -> void:
	assert(SaveManager.save_path.begins_with("res://.godot/Slimerot-offline-test-"))
	for suffix in SlimerotSaveFormat.SUFFIXES + [".bak.tmp"]:
		var path: String = SaveManager.save_path + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	SaveManager.last_offline_summary.clear()
	SaveManager.last_error = ""
	SaveManager.generation = 0
	SaveManager.elapsed = 0.0
	WorldManager.travel(0)
	clear_files()

func unlock_auto(last_mainline: int = 3) -> void:
	# Fixture currency is balanced; all permanent nodes use real purchase rules.
	GameState.rolls_balance = 50000
	GameState.lifetime_rolls = 50000
	for index in range(1, last_mainline + 1):
		assert(SkillTreeManager.purchase("R%02d" % index))
	GameState.settings.auto_roll_state = true
	RollManager.cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown

func stack_counts() -> Dictionary:
	var counts := {}
	for key in InventoryManager.inventory:
		counts[key] = InventoryManager.inventory[key].quantity
	return counts

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var original_path: String = SaveManager.save_path
	var processing := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	SaveManager.save_path = "res://.godot/Slimerot-offline-test-%d.json" % OS.get_process_id()
	await test_roll_accounting_and_parity()
	await test_background_transactions()
	await test_sliced_batch_and_lifecycle()
	await test_fractional_and_disabled_time()
	await test_migration_and_compact_restore()
	await test_failed_commit_retry()
	await test_invalid_clock()
	fresh()
	SaveManager.save_path = original_path
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	SaveManager.set_process(processing[2])
	CombatManager.set_physics_process(processing[3])
	await get_tree().process_frame

func test_roll_accounting_and_parity() -> void:
	fresh()
	var first: Dictionary = await RollManager.process_offline_rolls(1)
	check(first.get("rolls") == 1 and GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1, "data-only first roll grants both counters exactly once")
	check(InventoryManager.equipped_copy_ids.size() == 1 and InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[0]).slime_id == SlimerotBalance.FIRST_SLIME, "data-only first roll preserves guaranteed starter and auto-equip")
	fresh()
	unlock_auto(13)
	for id in ["RO2", "RO3", "RO5", "RO6"]: assert(SkillTreeManager.purchase(id))
	GameState.highest_zone_unlocked = 8
	GameState.structure_unlocked_flags.sell_terminal = true
	assert(InventoryManager.set_auto_sell(true))
	assert(InventoryManager.set_auto_sell_threshold(1000))
	assert(RollManager.set_luck_cap(20.0))
	GameState.active_potion_type = "hyper_soda"
	GameState.potion_remaining_seconds = 123.25
	GameState.boss_brew_seconds = 42.5
	GameState.active_play_seconds = 71.125
	var protected := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equipped_copy_ids.assign([protected])
	InventoryManager.toggle_copy_favorite(protected)
	var fixture: Dictionary = SaveManager.snapshot()
	RollManager.rng.seed = 818181
	RollManager.variant_rng.seed = 313131
	var baseline := [GameState.rolls_balance, GameState.lifetime_rolls]
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	for index in 100: RollManager._process(cooldown)
	check(GameState.rolls_balance == baseline[0] + 100 and GameState.lifetime_rolls == baseline[1] + 100, "100 ordinary Auto Roll cycles grant exactly +100 Rolls and +100 Lifetime Rolls")
	var online_counts := stack_counts()
	var online_discoveries: Dictionary = InventoryManager.discoveries.duplicate(true)
	var online_rng := [RollManager.rng.state, RollManager.variant_rng.state]
	var online_coins := [GameState.coins, GameState.coins_earned]
	var online_rarest: int = GameState.rarest_threshold_reached
	SaveManager.apply_snapshot(fixture)
	RollManager.reset()
	RollManager.rng.seed = 818181
	RollManager.variant_rng.seed = 313131
	var result: Dictionary = await RollManager.process_offline_rolls(100)
	check(result.get("rolls") == 100 and result.get("rolls_earned") == 100 and GameState.rolls_balance == baseline[0] + 100 and GameState.lifetime_rolls == baseline[1] + 100, "100 simulated Auto Rolls use the same currency invariant")
	check(same_json(stack_counts(), online_counts) and same_json(InventoryManager.discoveries, online_discoveries), "seeded offline base/variant quantities and discoveries match online rolls with Super Roll, Variant Sense and Luck Cap")
	check([RollManager.rng.state, RollManager.variant_rng.state] == online_rng, "offline selection consumes the same two independent RNG streams as online")
	check([GameState.coins, GameState.coins_earned] == online_coins and GameState.rarest_threshold_reached == online_rarest, "offline auto-sale and rarest statistics agree with online transactions")
	check(GameState.active_play_seconds == 71.125 and GameState.potion_remaining_seconds == 123.25 and GameState.boss_brew_seconds == 42.5, "offline rolls leave active-play and both potion clocks unchanged")
	check(InventoryManager.is_protected(protected) and InventoryManager.equipped_copy_ids == [protected], "offline auto-sale preserves the existing equipped favorite")
	check(RollManager.reveal_queue.is_empty() and RollManager.active_reveal.is_empty(), "100 offline rolls queue no per-roll reveal animations")
	check(result.get("new_discoveries") is Array and result.get("best_drop", {}).has("slime_id"), "one AFK summary contains discoveries and a best drop")
	var unchanged := [GameState.rolls_balance, GameState.lifetime_rolls]
	await RollManager.process_offline_rolls(0)
	await RollManager.process_offline_rolls(-5)
	check([GameState.rolls_balance, GameState.lifetime_rolls] == unchanged, "zero and negative requested batches mint no currency")

func test_background_transactions() -> void:
	fresh()
	unlock_auto()
	GameState.award_coins(123)
	GameState.active_play_seconds = 88.5
	GameState.active_potion_type = "lucky_soda"
	GameState.potion_remaining_seconds = 91.25
	var before := [GameState.rolls_balance, GameState.lifetime_rolls]
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	SaveManager.enabled = true
	check(SaveManager.enter_background(10000.0), "background captures and safely saves a wall-clock checkpoint")
	var checkpoint := SaveManager.read_candidate(SaveManager.save_path)
	check(checkpoint.get("state", {}).get("last_background_timestamp") == 10000.0, "background timestamp is in the same committed save as progression")
	var resume_at := 10000.0 + cooldown * 100.0
	var result: Dictionary = await SaveManager.resume_from_background(resume_at)
	check(result.get("rolls") == 100 and GameState.rolls_balance == before[0] + 100 and GameState.lifetime_rolls == before[1] + 100, "100 elapsed cooldown cycles commit exactly 100 offline rewards")
	check(GameState.coins == 123 and GameState.zone_kill_counts.is_empty(), "AFK simulates no enemy kills or combat Coin farming")
	check(GameState.active_play_seconds == 88.5 and GameState.potion_remaining_seconds == 91.25, "background elapsed wall time does not consume active-play seconds")
	check(not SaveManager.offline_processing and not SaveManager.offline_commit_pending and SaveManager.last_error.is_empty(), "resume completes its durable transaction before returning")
	var inventory_after: Dictionary = InventoryManager.inventory.duplicate(true)
	var after := [GameState.rolls_balance, GameState.lifetime_rolls]
	await SaveManager.resume_from_background(resume_at)
	check([GameState.rolls_balance, GameState.lifetime_rolls] == after and same_json(InventoryManager.inventory, inventory_after), "duplicate resume notification cannot grant the same elapsed interval twice")
	check(SaveManager.load_game(), "committed offline result reopens as a valid save")
	await SaveManager.resume_from_background(resume_at)
	check([GameState.rolls_balance, GameState.lifetime_rolls] == after and same_json(InventoryManager.inventory, inventory_after), "reopen and repeated resume do not duplicate currency or inventory")
	check(RollManager.reveal_queue.is_empty() and RollManager.active_reveal.is_empty(), "resume remains one summary rather than a reveal backlog")
	await suite.capture("Slimerot-stage11-afk")

func test_sliced_batch_and_lifecycle() -> void:
	fresh()
	unlock_auto(13)
	GameState.highest_zone_unlocked = 8
	var before: int = GameState.lifetime_rolls
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	SaveManager.enabled = true
	assert(SaveManager.enter_background(15000.0))
	var observations := {"frames": 0, "partial_rewards": false, "reveals": 0}
	var observe_frame := func():
		if RollManager.completing:
			observations.frames += 1
			if GameState.lifetime_rolls != before or not InventoryManager.inventory.is_empty(): observations.partial_rewards = true
	var observe_reveal := func(_id, _variant, _first): observations.reveals += 1
	get_tree().process_frame.connect(observe_frame)
	RollManager.revealed.connect(observe_reveal)
	var summary: Dictionary = await SaveManager.resume_from_background(15000.0 + cooldown * 20000.0)
	get_tree().process_frame.disconnect(observe_frame)
	RollManager.revealed.disconnect(observe_reveal)
	check(observations.frames > 0 and not observations.partial_rewards, "large catch-up yields frames while keeping partially sampled rewards uncommitted")
	check(summary.get("rolls") == 20000 and GameState.lifetime_rolls == before + 20000, "sliced 20,000-roll batch commits all completed cycles exactly once")
	check(observations.reveals == 0 and RollManager.reveal_queue.is_empty(), "long catch-up renders no individual roll reveals")
	var explicit_copies := 0
	var owned := 0
	for pair in InventoryManager.inventory.values():
		explicit_copies += pair.copy_ids.size()
		owned += int(pair.quantity)
	check(owned == 20000 and explicit_copies == 0 and InventoryManager.inventory.size() <= 96, "long catch-up stores bounded unique stacks rather than 20,000 copy objects")
	check(FileAccess.get_file_as_bytes(SaveManager.save_path).size() < 100000, "large catch-up remains a compact local save")
	world.hud.close_menu()
	fresh()
	unlock_auto()
	before = GameState.lifetime_rolls
	SaveManager.enabled = true
	SaveManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	var anchor: float = GameState.last_background_timestamp
	SaveManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(GameState.suspended and GameState.last_background_timestamp == anchor, "overlapping pause/focus-out notifications checkpoint only once")
	SaveManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	await get_tree().process_frame
	check(GameState.suspended and GameState.lifetime_rolls == before, "resume while focus is still lost leaves gameplay suspended")
	SaveManager._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not GameState.suspended and GameState.lifetime_rolls == before, "final foreground notification safely resumes without minting a short incomplete cycle")

func test_fractional_and_disabled_time() -> void:
	fresh()
	unlock_auto()
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	var before: int = GameState.lifetime_rolls
	RollManager.cooldown_remaining = cooldown * 0.75
	SaveManager.enabled = true
	assert(SaveManager.enter_background(20000.0))
	await SaveManager.resume_from_background(20000.0 + cooldown * 0.5)
	check(GameState.lifetime_rolls == before and is_equal_approx(RollManager.cooldown_remaining, cooldown * 0.25), "partial online cycle plus short absence retains fractional progress")
	assert(SaveManager.enter_background(20000.0 + cooldown * 0.5))
	await SaveManager.resume_from_background(20000.0 + cooldown)
	check(GameState.lifetime_rolls == before + 1 and is_equal_approx(RollManager.cooldown_remaining, cooldown * 0.75), "two partial absences finish one cycle without losing the remainder")
	before = GameState.lifetime_rolls
	GameState.settings.auto_roll_state = false
	assert(SaveManager.enter_background(30000.0))
	await SaveManager.resume_from_background(31000.0)
	check(GameState.lifetime_rolls == before, "Auto Roll OFF for an absence produces zero offline rolls")
	GameState.settings.auto_roll_state = true
	RollManager.cooldown_remaining = cooldown
	assert(SaveManager.enter_background(31000.0))
	await SaveManager.resume_from_background(31000.0 + cooldown)
	check(GameState.lifetime_rolls == before + 1, "enabling Auto Roll after returning does not claim the previous OFF interval")
	before = GameState.lifetime_rolls
	assert(SaveManager.enter_background(40000.0))
	await SaveManager.resume_from_background(39900.0)
	check(GameState.lifetime_rolls == before, "a backward clock change never produces negative or extra rolls")

func test_migration_and_compact_restore() -> void:
	fresh()
	unlock_auto(8)
	var starter := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equipped_copy_ids.assign([starter])
	InventoryManager.toggle_copy_favorite(starter)
	GameState.award_coins(54321)
	GameState.highest_zone_unlocked = 2
	GameState.current_zone = 2
	GameState.unlocked_gate_flags["1"] = true
	GameState.zone_kill_counts["1"] = 12
	var legacy := SaveManager.snapshot()
	legacy.schema_version = 8
	legacy.erase("last_background_timestamp")
	legacy.erase("offline_roll_remainder")
	var old_bytes := SlimerotSaveFormat.encode(legacy, 1)
	assert(SlimerotSaveFormat.write(SaveManager.save_path, old_bytes))
	SaveManager.enabled = true
	check(SaveManager.load_game() and GameState.last_background_timestamp == 0.0 and GameState.offline_roll_remainder == 0.0, "schema 8 lacking AFK fields migrates with zero timestamp and remainder")
	check(GameState.coins == 54321 and GameState.rolls_balance == legacy.rolls_balance and GameState.lifetime_rolls == legacy.lifetime_rolls and InventoryManager.equipped_copy_ids == [starter] and InventoryManager.is_protected(starter), "schema 8 preserves currencies, exact team and favorite protection")
	check(GameState.current_zone == 2 and WorldManager.gate_open(1) and same_json(GameState.purchased_skill_node_ids, legacy.purchased_skill_node_ids) and is_equal_approx(SkillTreeManager.derived_stats().luck, 30.36), "schema 8 preserves world and purchases while deriving B1 exactly once")
	var before: int = GameState.lifetime_rolls
	await SaveManager.resume_from_background(50000.0)
	check(GameState.lifetime_rolls == before, "missing legacy timestamp cannot claim invented historical offline time")
	var bulk: Dictionary = InventoryManager.add_copies("brr_brr_patapim", "golden", 100000)
	var favorite: String = bulk.first_copy_id
	InventoryManager.toggle_copy_favorite(favorite)
	InventoryManager.equipped_copy_ids.assign([favorite])
	check(SaveManager.save_game() and SaveManager.load_game(), "100,000 compact copies save and load without materializing individual objects")
	check(InventoryManager.inventory["brr_brr_patapim:golden"].quantity == 100000 and InventoryManager.equipped_copy_ids == [favorite] and InventoryManager.is_protected(favorite) and InventoryManager.is_protected(starter), "compact range ownership, exact team and legacy/range favorites survive load")
	var current := SaveManager.snapshot()
	var invalid := current.duplicate(true)
	invalid.offline_roll_remainder = -1.0
	var committed := FileAccess.get_file_as_string(SaveManager.save_path)
	check(not SaveManager.write_snapshot(invalid) and FileAccess.get_file_as_string(SaveManager.save_path) == committed, "invalid AFK fields cannot overwrite committed progression")
	clear_files()
	var invalid_legacy := legacy.duplicate(true)
	invalid_legacy.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity += 1
	var invalid_legacy_bytes := SlimerotSaveFormat.encode(invalid_legacy, 6)
	assert(SlimerotSaveFormat.write(SaveManager.save_path, invalid_legacy_bytes))
	SaveManager.enabled = true
	check(not SaveManager.load_game() and not SaveManager.enabled and not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.save_path) == invalid_legacy_bytes, "a legacy migration with inconsistent ownership preserves the original file without overwrite")
	clear_files()
	var future := current.duplicate(true)
	future.schema_version = SlimerotBalance.SCHEMA_VERSION + 1
	var future_bytes := SlimerotSaveFormat.encode(future, 7)
	assert(SlimerotSaveFormat.write(SaveManager.save_path, future_bytes))
	SaveManager.enabled = true
	check(not SaveManager.load_game() and not SaveManager.enabled and not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.save_path) == future_bytes, "future schemas remain byte-for-byte protected from an older build")

func test_failed_commit_retry() -> void:
	fresh()
	unlock_auto()
	var cooldown: float = SkillTreeManager.derived_stats().roll_cooldown
	var before: int = GameState.lifetime_rolls
	SaveManager.enabled = true
	assert(SaveManager.enter_background(60000.0))
	var original_path: String = SaveManager.save_path
	var original_bytes := FileAccess.get_file_as_string(original_path)
	SaveManager.save_path = original_path + "/Slimerot-missing/save.json"
	await SaveManager.resume_from_background(60000.0 + cooldown * 100.0)
	check(SaveManager.offline_commit_pending and GameState.is_paused(), "failed AFK write keeps gameplay suspended until the reward transaction is durable")
	check(FileAccess.get_file_as_string(original_path) == original_bytes, "failed AFK commit leaves its original background checkpoint intact")
	SaveManager.save_path = original_path
	await SaveManager.resume_from_background(60000.0 + cooldown * 100.0)
	check(not SaveManager.offline_commit_pending and GameState.lifetime_rolls == before + 100, "retry commits the already simulated 100 rolls without simulating them twice")
	check(SaveManager.load_game() and GameState.lifetime_rolls == before + 100, "retried AFK transaction reopens with exactly one reward batch")

func test_invalid_clock() -> void:
	fresh()
	unlock_auto(18)
	SaveManager.enabled = true
	assert(SaveManager.enter_background(70000.0))
	var committed := FileAccess.get_file_as_string(SaveManager.save_path)
	var before: int = GameState.lifetime_rolls
	await SaveManager.resume_from_background(float(SlimerotSaveFormat.MAX_EXACT_INTEGER))
	check(not SaveManager.enabled and GameState.lifetime_rolls == before and GameState.last_background_timestamp == 70000.0 and FileAccess.get_file_as_string(SaveManager.save_path) == committed, "unrepresentable elapsed cycles cannot consume the checkpoint or overwrite progression")
