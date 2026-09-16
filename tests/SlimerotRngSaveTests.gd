extends Node

# Prompt 12 migration exercises real JSON/envelope boundaries in a private profile.
var world: Node
var suite: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, "RNG save · " + description)

func same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func clear_files() -> void:
	assert(SaveManager.save_path.begins_with("res://.godot/Slimerot-rng-save-test-"))
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(SaveManager.save_path + suffix):
			DirAccess.remove_absolute(SaveManager.save_path + suffix)

func fresh() -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	SaveManager.last_offline_summary.clear()
	SaveManager.generation = 0
	SaveManager.last_error = ""
	SaveManager.elapsed = 0.0
	WorldManager.travel(0)
	clear_files()

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var original_path: String = SaveManager.save_path
	var processing := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	SaveManager.save_path = "res://.godot/Slimerot-rng-save-test-%d.json" % OS.get_process_id()
	test_schema_nine_compact_migration()
	test_all_masks_round_trip()
	test_pity_and_shrine_round_trip()
	test_malformed_save_preservation()
	fresh()
	SaveManager.save_path = original_path
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	SaveManager.set_process(processing[2])
	CombatManager.set_physics_process(processing[3])
	await get_tree().process_frame

func legacy_fixture() -> Dictionary:
	var id: String = SlimerotBalance.FIRST_SLIME
	InventoryManager.add_copies(id, "normal", 100000)
	InventoryManager.add_copies(id, "shiny", 3)
	InventoryManager.add_copies(id, "glitched", 2)
	InventoryManager.add_copies(id, "golden", 2)
	InventoryManager.equipped_copy_ids.assign(["slimerot_copy_100001"])
	InventoryManager.inventory[id + ":normal"].favorite_copy_ranges = [[500, 1500]]
	InventoryManager.inventory[id + ":shiny"].favorite_copy_ids = ["slimerot_copy_100002"]
	InventoryManager.inventory[id + ":golden"].favorite = true
	# A sold-out rare discovery is authoritative historical evidence for old saves.
	InventoryManager.discoveries.brainrot_singularity = ["golden"]
	GameState.lifetime_rolls = 100008
	GameState.rolls_balance = 100008
	GameState.last_background_timestamp = 1700000012.5
	GameState.offline_roll_remainder = 0.75
	RollManager.cooldown_remaining = 1.65
	var data := SaveManager.snapshot()
	data.schema_version = 9
	for key in ["best_ever_effective_rarity", "rolls_since_last_power_improvement", "shrine_sacrifices"]: data.erase(key)
	for pair in data.inventory.values(): pair.erase("variant_flags")
	return data

func test_schema_nine_compact_migration() -> void:
	fresh()
	var legacy := legacy_fixture()
	var original_bytes := SlimerotSaveFormat.encode(legacy, 7)
	check(SlimerotSaveFormat.write(SaveManager.save_path, original_bytes), "schema 9 fixture writes to isolated test profile")
	var untouched := JSON.stringify(legacy)
	var migrated: Variant = SaveManager.migrate(legacy)
	check(JSON.stringify(legacy) == untouched, "migration leaves the source dictionary unchanged")
	check(SaveManager.validate(migrated), "schema 9 compact profile validates after migration")
	SaveManager.enabled = true
	check(SaveManager.load_game(), "schema 9 checksummed save loads through the real candidate validator")
	check(FileAccess.get_file_as_string(SaveManager.save_path) == original_bytes, "loading a valid legacy save does not rewrite its original bytes")
	var id: String = SlimerotBalance.FIRST_SLIME
	for variant in ["normal", "shiny", "glitched", "golden"]:
		var key: String = id + ":" + variant
		var expected: Dictionary = legacy.inventory[key]
		var actual: Dictionary = InventoryManager.inventory[key]
		check(actual.variant_flags == SlimerotVariants.mask(variant) and actual.quantity == expected.quantity and same_json(actual.copy_ranges, expected.copy_ranges), "legacy %s keeps its compact quantity and identity range with canonical flags" % variant)
	check(InventoryManager.next_copy_id == 100008 and InventoryManager.equipped_copy_ids == ["slimerot_copy_100001"], "migration preserves next identity and the exact equipped copy")
	check(InventoryManager.is_protected("slimerot_copy_500") and InventoryManager.is_protected("slimerot_copy_1500") and not InventoryManager.is_protected("slimerot_copy_1501") and InventoryManager.is_protected("slimerot_copy_100002") and InventoryManager.is_protected("slimerot_copy_100007"), "compact, individual and whole-stack favorites survive migration")
	check(GameState.last_background_timestamp == 1700000012.5 and GameState.offline_roll_remainder == 0.75 and is_equal_approx(RollManager.cooldown_remaining, 1.65), "Prompt 11 offline checkpoint and partial cooldown survive schema 9 migration")
	check(same_json(InventoryManager.discoveries, legacy.discoveries) and GameState.best_ever_effective_rarity == SlimeDatabase.get_effective_rarity("brainrot_singularity", SlimerotVariants.GOLDEN), "sold-out legacy discovery establishes the historical best-ever power target")
	check(GameState.rolls_since_last_power_improvement == 0 and GameState.shrine_sacrifices == {"shiny": [], "glitched": [], "golden": []}, "legacy pity counter and Shrine categories initialize safely")
	check(SaveManager.save_game() and SlimerotSaveFormat.read(SaveManager.save_path).state.schema_version == 10, "only validated migration is durably committed as schema 10")
	check(FileAccess.get_file_as_string(SaveManager.save_path + ".bak") == original_bytes, "first schema 10 commit retains the complete schema 9 backup")

func test_all_masks_round_trip() -> void:
	fresh()
	var id: String = SlimerotBalance.FIRST_SLIME
	for flags in 8:
		InventoryManager.add_copies(id, flags, flags + 1)
	GameState.lifetime_rolls = 36
	GameState.rolls_balance = 36
	InventoryManager.equipped_copy_ids.assign(["slimerot_copy_29"])
	InventoryManager.inventory[id + ":shiny+glitched+golden"].favorite_copy_ranges = [[30, 32]]
	var expected := SaveManager.snapshot()
	SaveManager.enabled = true
	check(SaveManager.save_game(), "all eight variant masks write through JSON and checksum validation")
	InventoryManager.reset()
	GameState.reset()
	check(SaveManager.load_game(), "all eight variant masks load through JSON number conversion")
	check(InventoryManager.inventory.size() == 8 and same_json(InventoryManager.discoveries, expected.discoveries), "all masks keep distinct stacks and discovery entries")
	for flags in 8:
		var token := SlimerotVariants.key(flags)
		var pair: Dictionary = InventoryManager.inventory[id + ":" + token]
		check(pair.variant_flags == flags and pair.variant == token and pair.quantity == flags + 1 and same_json(pair.copy_ranges, expected.inventory[id + ":" + token].copy_ranges), "mask %d round-trips without identity or quantity loss" % flags)
	check(InventoryManager.equipped_copy_ids == ["slimerot_copy_29"] and InventoryManager.is_protected("slimerot_copy_32") and not InventoryManager.is_protected("slimerot_copy_33"), "multi-variant equipment and selective favorites remain protected")
	var expected_luck := RollManager.effective_luck()
	check(SaveManager.load_game() and RollManager.effective_luck() == expected_luck, "repeated current-schema load does not compound derived luck")

func test_pity_and_shrine_round_trip() -> void:
	fresh()
	GameState.lifetime_rolls = 100
	GameState.rolls_balance = 100
	GameState.structure_unlocked_flags.sell_terminal = true
	var best_copy := InventoryManager.add_copy("brainrot_singularity", SlimerotVariants.SHINY | SlimerotVariants.GOLDEN)
	GameState.best_ever_effective_rarity = SlimeDatabase.get_effective_rarity("brainrot_singularity", SlimerotVariants.SHINY | SlimerotVariants.GOLDEN)
	GameState.rolls_since_last_power_improvement = 73
	GameState.shrine_sacrifices = {"shiny": ["tung_tung_tung_sahur", "brr_brr_patapim", "chimpanzini_bananini"], "glitched": ["tung_tung_tung_sahur"], "golden": ["brr_brr_patapim"]}
	var best := GameState.best_ever_effective_rarity
	var categories := GameState.shrine_sacrifices.duplicate(true)
	check(InventoryManager.sell_copy(best_copy) > 0 and InventoryManager.pair_for_copy(best_copy).is_empty(), "fixture sells the former strongest physical copy")
	check(GameState.best_ever_effective_rarity == best and GameState.rolls_since_last_power_improvement == 73, "selling the former best does not reset historical power or its pity counter")
	SaveManager.enabled = true
	check(SaveManager.save_game(), "sold-best target, pity counter and unique Shrine sets persist atomically")
	GameState.reset()
	InventoryManager.reset()
	check(SaveManager.load_game() and GameState.best_ever_effective_rarity == best and GameState.rolls_since_last_power_improvement == 73, "reload preserves historical target and exact pity progress after best-copy sale")
	check(same_json(GameState.shrine_sacrifices, categories) and is_equal_approx(InventoryManager.shrine_multiplier(SlimerotVariants.SHINY), pow(1.05, 3)), "three unique Shiny sacrifices retain the 1.05 cubed multiplier after load")
	check(InventoryManager.pair_for_copy(best_copy).is_empty() and InventoryManager.discoveries.brainrot_singularity.has("shiny+golden"), "sold copy stays absent while its multi-variant discovery remains")

func test_malformed_save_preservation() -> void:
	fresh()
	var legacy := legacy_fixture()
	var key: String = SlimerotBalance.FIRST_SLIME + ":shiny"
	var invalid_legacy := legacy.duplicate(true)
	invalid_legacy.inventory[key].variant_flags = SlimerotVariants.GOLDEN
	var old_bytes := SlimerotSaveFormat.encode(invalid_legacy, 19)
	check(SlimerotSaveFormat.write(SaveManager.save_path, old_bytes), "invalid legacy fixture writes only to the isolated profile")
	SaveManager.enabled = true
	check(not SaveManager.load_game() and not SaveManager.enabled, "conflicting legacy mask fails migration and disables saving")
	check(not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.save_path) == old_bytes, "failed legacy migration preserves original bytes without overwrite")
	fresh()
	legacy_fixture()
	var valid := SaveManager.snapshot()
	check(SaveManager.validate(JSON.parse_string(JSON.stringify(valid))), "historical discovery floor survives StringName keys becoming JSON strings")
	SaveManager.enabled = true
	check(SaveManager.write_snapshot(valid), "valid schema 10 checkpoint is available before malformed-write probes")
	var valid_bytes := FileAccess.get_file_as_string(SaveManager.save_path)
	var cases: Array[Dictionary] = []
	for mask_value in [-1, 8, 1.5, "shiny", null]:
		var bad := valid.duplicate(true)
		bad.inventory[key].variant_flags = mask_value
		cases.append({"label": "invalid mask %s" % str(mask_value), "state": bad})
	var mismatched := valid.duplicate(true)
	mismatched.inventory[key].variant_flags = 4
	cases.append({"label": "valid mask with mismatched stack token", "state": mismatched})
	var duplicate_copy := valid.duplicate(true)
	duplicate_copy.inventory[key].copy_ranges = [[1, 3]]
	cases.append({"label": "duplicate physical identity across stacks", "state": duplicate_copy})
	var duplicate_category := valid.duplicate(true)
	duplicate_category.shrine_sacrifices.shiny = [SlimerotBalance.FIRST_SLIME, SlimerotBalance.FIRST_SLIME]
	cases.append({"label": "duplicate Shrine base ID", "state": duplicate_category})
	var unknown_category := valid.duplicate(true)
	unknown_category.shrine_sacrifices.glitched = ["not_a_slimerot_base"]
	cases.append({"label": "unknown Shrine base ID", "state": unknown_category})
	var invalid_category := valid.duplicate(true)
	invalid_category.shrine_sacrifices.golden = "brainrot_singularity"
	cases.append({"label": "non-array Shrine category", "state": invalid_category})
	var old_best := valid.duplicate(true)
	old_best.best_ever_effective_rarity = 2
	cases.append({"label": "best-ever below persisted discovery", "state": old_best})
	var invalid_pity := valid.duplicate(true)
	invalid_pity.rolls_since_last_power_improvement = valid.lifetime_rolls + 1
	cases.append({"label": "pity counter beyond Lifetime Rolls", "state": invalid_pity})
	for entry in cases:
		check(not SaveManager.write_snapshot(entry.state) and FileAccess.get_file_as_string(SaveManager.save_path) == valid_bytes, "%s is rejected without replacing the valid checkpoint" % entry.label)
