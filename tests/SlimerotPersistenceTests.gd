extends Node

# Slimerot persistence tests use their own files and the same transactions as gameplay.
var suite: Node
var world: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Save · " + description)

func same_json(first: Variant, second: Variant) -> bool:
	# Godot dictionaries distinguish integer from JSON float values; compare their
	# serialized data meaning while retaining exact IDs, array order and fractions.
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))

func clear_files() -> void:
	for suffix in ["", ".tmp", ".bak", ".recover", ".bak.tmp", ".reset"]:
		if FileAccess.file_exists(SaveManager.save_path + suffix):
			DirAccess.remove_absolute(SaveManager.save_path + suffix)

func write_bytes(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(contents)
	file.flush()
	file.close()

func disk_state(path: String = "") -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path if path.is_empty() else path))
	if not data is Dictionary: return {}
	if data.get("payload") is String:
		var payload: Variant = JSON.parse_string(data.payload)
		return payload if payload is Dictionary else {}
	return data

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	SaveManager.elapsed = 0.0
	clear_files()

func provision() -> void:
	GameState.award_coins(10000000)
	GameState.lifetime_rolls = 10000
	GameState.rolls_balance = 10000
	GameState.highest_zone_unlocked = 8
	for zone in range(1, 8):
		GameState.unlocked_gate_flags[str(zone)] = true
		GameState.zone_kill_counts[str(zone)] = SlimerotCampaign.zone(zone).kill_requirement
	for zone in [2, 4, 6]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	for row in SlimerotEncounters.STRUCTURES: GameState.structure_unlocked_flags[row[0]] = true

func buy_b1() -> void:
	for row in SlimerotRollTree.MAINLINE:
		assert(SkillTreeManager.purchase(row[0]))
		if row[0] == "R08": break

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var original_path := SaveManager.save_path
	SaveManager.save_path = original_path.trim_suffix(".json") + "-persistence.json"
	var process_states := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	test_roll_transactions()
	test_exact_roundtrip()
	test_recovery()
	test_schema_boundaries()
	test_active_time()
	test_consequential_writes()
	test_reset()
	fresh()
	SaveManager.save_path = original_path
	GameState.set_process(process_states[0])
	RollManager.set_process(process_states[1])
	SaveManager.set_process(process_states[2])
	CombatManager.set_physics_process(process_states[3])
	await get_tree().process_frame

func test_roll_transactions() -> void:
	fresh()
	SaveManager.enabled = true
	for index in 100:
		RollManager.cooldown_remaining = 0.0
		assert(RollManager.request_roll())
		if index == 0:
			var first := disk_state()
			check(first.get("lifetime_rolls") == 1 and first.get("rolls_balance") == 1 and first.get("first_roll_completed", false), "first guaranteed roll writes both currency increments and its completion state immediately")
			check(InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[0]).slime_id == SlimerotBalance.FIRST_SLIME, "first saved team owns and equips Tung Tung Tung Sahur")
	check(GameState.rolls_balance == 100 and GameState.lifetime_rolls == 100, "100 real completed rolls mint exactly 100 Rolls and 100 Lifetime Rolls")
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.rolls_balance == 100 and GameState.lifetime_rolls == 100, "100-roll accounting survives save/load")
	check(SkillTreeManager.purchase("R01") and SkillTreeManager.purchase("R02"), "25-Roll and 40-Roll purchases use the normal tree transaction")
	var saved := disk_state()
	check(saved.get("rolls_balance") == 35 and saved.get("lifetime_rolls") == 100 and saved.get("roll_skill_spend", {}).get("R02") == 40, "40-Roll skill spends exactly 40 and immediately saves unchanged Lifetime Rolls")
	check(SaveManager.load_game() and GameState.lifetime_rolls == GameState.rolls_balance + SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), "saved Roll ledger conserves all minted Rolls")
	var before := GameState.lifetime_rolls
	RollManager.cooldown_remaining = 0.0
	check(RollManager.request_roll() and not RollManager.last_result.first_roll and GameState.lifetime_rolls == before + 1, "load does not repeat the guaranteed first-roll transaction")

func test_exact_roundtrip() -> void:
	fresh()
	provision()
	buy_b1()
	for id in ["C01", "C02", "C04", "C05", "C06", "CO1", "RO2", "RO3"]: assert(SkillTreeManager.purchase(id))
	var first := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	var second := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	var golden := InventoryManager.add_copy("brr_brr_patapim", "golden")
	InventoryManager.equipped_copy_ids.assign([second, golden, first])
	InventoryManager.toggle_copy_favorite(first)
	InventoryManager.toggle_favorite("brr_brr_patapim:golden")
	var sold := InventoryManager.add_copy("chimpanzini_bananini", "glitched")
	assert(InventoryManager.sell_copy(sold) > 0)
	GameState.potion_inventory = {"lucky_soda": 2, "hyper_soda": 3, "boss_brew": 1}
	assert(WorldManager.drink_potion("hyper_soda") and WorldManager.drink_potion("boss_brew"))
	GameState._process(58.25)
	GameState.settings.master_audio = 0.35
	GameState.settings.music_audio = 0.2
	GameState.settings.sfx_audio = 0.8
	GameState.settings.screen_shake = false
	GameState.settings.vibration = false
	GameState.settings.auto_roll_state = true
	assert(InventoryManager.set_auto_sell(true) and InventoryManager.set_auto_sell_threshold(1000))
	assert(RollManager.set_luck_cap(20.0))
	WorldManager.travel(6)
	RollManager.cooldown_remaining = 0.73
	var expected := SaveManager.snapshot()
	var luck := RollManager.effective_luck()
	var stats := SkillTreeManager.derived_stats()
	var dps := InventoryManager.team_dps()
	check(is_equal_approx(stats.luck, 30.36) and is_equal_approx(luck, 91.08), "B1 fixture uses the exact x20 checkpoint and one x3 potion")
	check(not expected.has("active_potion_multiplier") and not expected.has("luck") and not expected.has("max_hp") and not expected.has("move_speed") and not expected.has("damage_multiplier"), "current schema stores authoritative purchases and potion identity, excluding derived multipliers")
	SaveManager.enabled = true
	check(SaveManager.save_game(), "full progressed state writes successfully")
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	check(envelope is Dictionary and envelope.get("format") == "Slimerot" and envelope.get("payload") is String and envelope.get("checksum") is String and envelope.get("generation", 0) > 0, "save container has Slimerot identity, generation and checksum")
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	for pass_index in 3:
		check(SaveManager.load_game() and is_equal_approx(RollManager.effective_luck(), luck) and SkillTreeManager.derived_stats() == stats, "reload %d derives B1, cooldown, HP and movement without compounding" % (pass_index + 1))
	check(same_json(InventoryManager.inventory, expected.inventory) and InventoryManager.equipped_copy_ids == expected.equipped_copy_ids and InventoryManager.next_copy_id == int(expected.next_copy_id), "exact ordered team, quantities and physical-copy IDs restore")
	check(InventoryManager.is_protected(first) and InventoryManager.is_protected(golden) and InventoryManager.team_dps() == dps, "individual/group favorites and truthful team DPS restore")
	check(InventoryManager.discoveries == expected.discoveries and InventoryManager.discoveries.get("chimpanzini_bananini", []).has("glitched") and InventoryManager.best_variant_owned("chimpanzini_bananini").is_empty() and InventoryManager.collection().size() == 24, "sold-out discoveries persist in the 24-entry collection")
	check(same_json(GameState.potion_inventory, expected.potion_inventory) and GameState.potion_remaining_seconds == 241.75 and GameState.boss_brew_seconds == 241.75, "bottles and independent fractional active potion durations restore exactly")
	check(same_json(GameState.settings, expected.settings) and RollManager.rolling_luck() == 20.0 and is_equal_approx(RollManager.cooldown_remaining, 0.73), "audio, vibration, shake, Auto Roll, filters, Luck Cap and partial cooldown restore")
	check(GameState.current_zone == 6 and GameState.highest_zone_unlocked == 8 and same_json(GameState.zone_kill_counts, expected.zone_kill_counts) and GameState.unlocked_gate_flags == expected.unlocked_gate_flags and GameState.structure_unlocked_flags == expected.structure_unlocked_flags, "location, global pool, kills, gates and structures restore")
	check(GameState.active_play_seconds == expected.active_play_seconds and GameState.coins == expected.coins and GameState.coins_earned == expected.coins_earned and GameState.coins_spent == expected.coins_spent, "active playtime and complete Coin ledger restore")
	GameState.settings.auto_roll_state = false

func test_recovery() -> void:
	fresh()
	SaveManager.enabled = true
	GameState.award_coins(11)
	assert(SaveManager.save_game())
	var older := FileAccess.get_file_as_string(SaveManager.save_path)
	GameState.award_coins(11)
	assert(SaveManager.save_game())
	var newer := FileAccess.get_file_as_string(SaveManager.save_path)
	write_bytes(SaveManager.save_path, "{truncated")
	check(SaveManager.load_game() and GameState.coins == 11, "truncated main recovers the previous complete generation")
	check(SaveManager.load_game() and GameState.coins == 11, "recovered backup is installed as a readable main save")
	write_bytes(SaveManager.save_path, older)
	write_bytes(SaveManager.save_path + ".tmp", newer)
	check(SaveManager.load_game() and GameState.coins == 22, "newer complete temp transaction wins over an older main after interruption")
	write_bytes(SaveManager.save_path, newer)
	write_bytes(SaveManager.save_path + ".tmp", older)
	check(SaveManager.load_game() and GameState.coins == 22, "stale temp cannot roll back a newer main generation")
	write_bytes(SaveManager.save_path + ".bak", older)
	var altered: Dictionary = JSON.parse_string(newer)
	var altered_payload: Dictionary = JSON.parse_string(altered.payload)
	altered_payload.coins += 500
	altered.payload = JSON.stringify(altered_payload)
	write_bytes(SaveManager.save_path, JSON.stringify(altered))
	write_bytes(SaveManager.save_path + ".tmp", "{")
	check(SaveManager.load_game() and GameState.coins == 11, "valid JSON with a mismatched checksum is rejected in favor of verified backup")
	clear_files()
	write_bytes(SaveManager.save_path + ".tmp", newer)
	check(SaveManager.load_game() and GameState.coins == 22, "completed temp recovers when interruption left no main or backup")
	clear_files()
	write_bytes(SaveManager.save_path + ".tmp", "{unfinished")
	check(not SaveManager.load_game() and not SaveManager.enabled and FileAccess.get_file_as_string(SaveManager.save_path + ".tmp") == "{unfinished", "unrecoverable temp-only save is preserved and blocks silent overwrite")
	check(not SaveManager.save_game(), "recovery failure does not overwrite evidence with a fresh state")
	fresh()
	var fresh_state := SaveManager.snapshot()
	var future := fresh_state.duplicate(true)
	future.schema_version = SlimerotBalance.SCHEMA_VERSION + 1
	write_bytes(SaveManager.save_path, JSON.stringify(future))
	write_bytes(SaveManager.save_path + ".reset", SlimerotSaveFormat.encode(fresh_state, 1))
	SaveManager.enabled = true
	check(SaveManager.load_game() and GameState.lifetime_rolls == 0 and SaveManager.enabled, "durable confirmed reset survives interruption before removing an older future-schema main")
	fresh()
	SaveManager.enabled = true
	GameState.award_coins(9)
	assert(SaveManager.save_game())
	var previous_path := SaveManager.save_path
	SaveManager.save_path = previous_path + "/Slimerot-missing/save.json"
	check(not SaveManager.save_game(), "unwritable save destination reports failure without claiming success")
	SaveManager.save_path = previous_path
	check(SaveManager.load_game() and GameState.coins == 9, "write failure preserves the previous committed progression")

func test_schema_boundaries() -> void:
	test_legacy_versions()
	fresh()
	provision()
	buy_b1()
	GameState.potion_inventory.hyper_soda = 1
	assert(WorldManager.drink_potion("hyper_soda"))
	GameState._process(12.5)
	var legacy := SaveManager.snapshot()
	legacy.schema_version = 6
	legacy.active_potion_multiplier = 600.0
	write_bytes(SaveManager.save_path, JSON.stringify(legacy))
	SaveManager.enabled = true
	check(SaveManager.load_game() and is_equal_approx(RollManager.effective_luck(), 91.08) and GameState.potion_remaining_seconds == 287.5, "schema 6 imports potion identity and ignores stale saved derived multipliers")
	check(SaveManager.save_game() and disk_state().get("schema_version") == SlimerotBalance.SCHEMA_VERSION, "legacy save rewrites to the current schema after successful migration")
	var current := SaveManager.snapshot()
	var invalid_cases: Array = [null, [], "Slimerot", 1, {"schema_version": 1}, {"schema_version": 5, "boss_defeated_flags": []}, {"schema_version": 2, "inventory": {}, "purchased_skill_node_ids": [null], "settings": {}}, {"schema_version": 3, "purchased_skill_node_ids": "C01"}]
	for item in invalid_cases:
		check(not SaveManager.validate(SaveManager.migrate(item)), "malformed legacy input %s fails validation without a parser/runtime exception" % str(item))
	for field in ["schema_version", "inventory", "settings", "purchased_skill_node_ids", "roll_skill_spend", "discoveries", "boss_defeated_flags", "potion_inventory", "active_potion_type", "equipped_copy_ids"]:
		var malformed := current.duplicate(true)
		malformed[field] = null
		check(not SaveManager.validate(malformed), "null %s is rejected safely" % field)
	for field in ["coins", "lifetime_rolls", "active_play_seconds", "active_potion_remaining_seconds", "boss_brew_seconds"]:
		var malformed := current.duplicate(true)
		malformed[field] = NAN
		check(not SaveManager.validate(malformed), "nonfinite %s is rejected" % field)
	var wrong_potion := current.duplicate(true)
	wrong_potion.active_potion_type = "Slimerot_unknown_potion"
	check(not SaveManager.validate(wrong_potion), "unknown active potion cannot enter the live state")
	var invalid_audio := current.duplicate(true)
	invalid_audio.settings.master_audio = 4.0
	check(not SaveManager.validate(invalid_audio), "out-of-range audio settings are rejected")
	var before_invalid := FileAccess.get_file_as_string(SaveManager.save_path)
	check(not SaveManager.write_snapshot(invalid_audio) and FileAccess.get_file_as_string(SaveManager.save_path) == before_invalid, "invalid snapshot cannot partially replace a valid save")
	var future := current.duplicate(true)
	future.schema_version = SlimerotBalance.SCHEMA_VERSION + 1
	var future_bytes := JSON.stringify(future)
	write_bytes(SaveManager.save_path, future_bytes)
	check(not SaveManager.load_game() and not SaveManager.enabled, "newer schema locks saving instead of downgrading to an older backup")
	check(not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.save_path) == future_bytes, "future-version save remains byte-for-byte untouched")

func test_legacy_versions() -> void:
	fresh()
	assert(RollManager.request_roll())
	var copy_id: String = InventoryManager.equipped_copy_ids[0]
	var pair_key: String = InventoryManager.pair_for_copy(copy_id).slime_id + ":" + InventoryManager.pair_for_copy(copy_id).variant
	InventoryManager.toggle_favorite(pair_key)
	var baseline := SaveManager.snapshot()
	for version in range(1, 7):
		clear_files()
		var legacy := baseline.duplicate(true)
		legacy.schema_version = version
		legacy.erase("first_roll_completed")
		legacy.active_potion_multiplier = 1.0
		if version < 6:
			for key in ["potion_inventory", "boss_brew_seconds", "completion_portal_unlocked", "campaign_completed"]: legacy.erase(key)
		if version < 5: legacy.erase("unlocked_gate_flags")
		if version < 3: legacy.erase("roll_skill_spend")
		if version == 1:
			for key in ["discoveries", "coins_earned", "coins_spent", "rarest_threshold_reached", "highest_luck", "best_team_dps"]: legacy.erase(key)
			legacy.inventory[pair_key].erase("favorite_copy_ids")
		write_bytes(SaveManager.save_path, JSON.stringify(legacy))
		SaveManager.enabled = true
		check(SaveManager.load_game() and GameState.lifetime_rolls == 1 and GameState.rolls_balance == 1 and InventoryManager.equipped_copy_ids == [copy_id] and InventoryManager.is_protected(copy_id), "real JSON schema %d migrates first-roll ownership, favorites, team and wallet" % version)
		check(SaveManager.save_game() and disk_state().get("schema_version") == SlimerotBalance.SCHEMA_VERSION, "schema %d migration commits a verified current save" % version)

func test_active_time() -> void:
	fresh()
	GameState.potion_inventory.lucky_soda = 1
	GameState.potion_inventory.boss_brew = 1
	assert(WorldManager.drink_potion("lucky_soda") and WorldManager.drink_potion("boss_brew"))
	SaveManager.enabled = true
	SaveManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	var paused := disk_state()
	SaveManager._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(GameState.is_paused(), "focus returning alone cannot resume an Android activity that is still paused")
	GameState._process(500)
	RollManager._process(500)
	SaveManager._process(500)
	check(GameState.is_paused() and GameState.active_play_seconds == paused.active_play_seconds and GameState.potion_remaining_seconds == 300 and GameState.boss_brew_seconds == 300, "Android pause immediately saves and freezes active play and both potion clocks")
	SaveManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	SaveManager._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not GameState.is_paused(), "resume returns to active gameplay without offline elapsed time")
	GameState.menu_paused = true
	GameState._process(100)
	SaveManager._process(100)
	check(GameState.potion_remaining_seconds == 300 and GameState.active_play_seconds == paused.active_play_seconds, "explicit pause menu freezes active timers")
	GameState.menu_paused = false
	GameState._process(0.25)
	check(GameState.potion_remaining_seconds == 299.75 and GameState.boss_brew_seconds == 299.75, "resumed clocks advance only by actual active delta")
	assert(SaveManager.save_game())
	var time_saved := GameState.active_play_seconds
	check(SaveManager.load_game() and GameState.active_play_seconds == time_saved and GameState.potion_remaining_seconds == 299.75, "reopening preserves remaining potion seconds without any wall-clock catch-up")
	GameState.award_coins(17)
	SaveManager.elapsed = 0.0
	SaveManager._process(9.99)
	check(disk_state().get("coins") == 0, "periodic save does not run before ten active seconds")
	SaveManager._process(0.02)
	check(disk_state().get("coins") == 17, "ten-second autosave commits ordinary progression")

func test_consequential_writes() -> void:
	fresh()
	GameState.award_coins(10000000)
	GameState.lifetime_rolls = 10000
	GameState.rolls_balance = 10000
	SaveManager.enabled = true
	check(WorldManager.repair("skill_tree_shrine") and disk_state().get("structure_unlocked_flags", {}).get("skill_tree_shrine", false), "structure purchase writes its permanent flag immediately")
	WorldManager.travel(1)
	GameState.zone_kill_counts["1"] = 12
	check(WorldManager.unlock_gate(1) and disk_state().get("unlocked_gate_flags", {}).get("1", false) and disk_state().get("highest_zone_unlocked") == 2, "gate purchase saves cost, gate and expanded global pool together")
	WorldManager.travel(2)
	check(WorldManager.finish_boss_reward(2) and disk_state().get("boss_defeated_flags", {}).get("zone_2", false) and disk_state().get("potion_inventory", {}).get("lucky_soda") == 1, "boss defeat immediately saves fixed reward, bottle and one-time flag")
	var after_boss := GameState.coins
	check(SaveManager.load_game() and not WorldManager.finish_boss_reward(2) and GameState.coins == after_boss, "reopening cannot pay a boss reward twice")
	SaveManager.enabled = false
	GameState.highest_zone_unlocked = 8
	for zone in range(1, 8): GameState.unlocked_gate_flags[str(zone)] = true
	GameState.structure_unlocked_flags.mutation_lab = true
	WorldManager.travel(6)
	var protected_copy := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equip(protected_copy)
	for index in 5: InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	SaveManager.enabled = true
	var coins := GameState.coins
	check(InventoryManager.mutate(SlimerotBalance.FIRST_SLIME), "mutation transaction accepts five valid unequipped Normal copies")
	var mutation := disk_state()
	check(mutation.get("coins") == coins - 100 and mutation.get("inventory", {}).get(SlimerotBalance.FIRST_SLIME + ":normal", {}).get("quantity") == 1 and mutation.get("inventory", {}).get(SlimerotBalance.FIRST_SLIME + ":shiny", {}).get("quantity") == 1, "mutation immediately saves fee, consumed copies and Shiny output atomically")
	check(SaveManager.load_game() and InventoryManager.is_protected(protected_copy) and InventoryManager.discoveries[SlimerotBalance.FIRST_SLIME].has("shiny"), "mutation reload preserves protected team copy and Shiny discovery")
	buy_b1()
	var chosen_seed := -1
	var probe := RandomNumberGenerator.new()
	for seed_value in 10000:
		probe.seed = seed_value
		var uniform := (float(probe.randi()) + 1.0) / 4294967296.0
		var id := RollManager.select_base(RollManager.rolling_luck(), uniform, 8)
		if SlimeDatabase.get_slime(id).rarity_threshold >= 10000:
			chosen_seed = seed_value
			break
	assert(chosen_seed >= 0)
	RollManager.rng.seed = chosen_seed
	RollManager.cooldown_remaining = 0.0
	check(RollManager.request_roll() and RollManager.last_result.threshold >= 10000 and disk_state().get("lifetime_rolls") == GameState.lifetime_rolls, "real threshold >= 1 in 10000 roll writes its complete result immediately")
	WorldManager.travel(8)
	check(WorldManager.finish_boss_reward(8) and disk_state().get("completion_portal_unlocked", false), "final boss immediately persists the permanent completion portal")
	check(WorldManager.complete_campaign() and disk_state().get("campaign_completed", false), "entering the final portal immediately persists completion")
	world.hud.close_menu()
	check(SaveManager.load_game() and GameState.campaign_completed and GameState.completion_portal_unlocked and WorldManager.travel(1) and RollManager.cooldown_remaining >= 0, "completion reload leaves unlocked endless free-roam usable")

func test_reset() -> void:
	check(SaveManager.reset_save(), "confirmed reset can replace the saved campaign")
	check(GameState.coins == 0 and GameState.rolls_balance == 0 and GameState.lifetime_rolls == 0 and GameState.current_zone == 0 and GameState.highest_zone_unlocked == 1, "reset restores exact canonical wallets and Bedroom location")
	check(InventoryManager.inventory.is_empty() and InventoryManager.discoveries.is_empty() and InventoryManager.equipped_copy_ids.is_empty() and GameState.purchased_skill_node_ids.is_empty(), "reset clears owned copies, collection, team and purchases")
	check(GameState.unlocked_gate_flags.is_empty() and GameState.boss_defeated_flags.is_empty() and GameState.structure_unlocked_flags.is_empty() and not GameState.completion_portal_unlocked and not GameState.campaign_completed, "reset clears all permanent campaign flags")
	check(GameState.potion_inventory.is_empty() and GameState.potion_remaining_seconds == 0 and GameState.boss_brew_seconds == 0 and GameState.settings == SlimerotBalance.SETTINGS and SkillTreeManager.derived_stats().equipped_slots == 1 and RollManager.effective_luck() == 1.0, "reset clears potions/settings and re-derives one slot and x1 luck")
	check(SaveManager.load_game() and GameState.lifetime_rolls == 0 and not disk_state().get("first_roll_completed", true) and disk_state(SaveManager.save_path + ".bak").get("lifetime_rolls") == 0, "reset replaces the old campaign with a fresh main and fresh backup")
	write_bytes(SaveManager.save_path, "{corrupted after reset")
	check(SaveManager.load_game() and GameState.lifetime_rolls == 0 and InventoryManager.inventory.is_empty() and not GameState.campaign_completed, "corrupt reset main recovers only fresh progress, never the deleted campaign")
	check(RollManager.request_roll() and RollManager.last_result.first_roll and GameState.rolls_balance == 1 and GameState.lifetime_rolls == 1 and InventoryManager.equipped_copy_ids.size() == 1, "reset restores exactly one fresh guaranteed roll and automatic equip")
