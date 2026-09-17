extends Node

var suite: Node
var world: Node

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Progression save · " + description)

func same_json(first: Variant, second: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))

func clear_files() -> void:
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(SaveManager.save_path + suffix): DirAccess.remove_absolute(SaveManager.save_path + suffix)

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
	clear_files()

func legacy_state(ids: Array, ledger: Dictionary, wallet: int = 500) -> Dictionary:
	GameState.purchased_skill_node_ids.assign(ids)
	GameState.roll_skill_spend = ledger.duplicate()
	GameState.rolls_balance = wallet
	GameState.lifetime_rolls = wallet
	for paid in ledger.values(): GameState.lifetime_rolls += int(paid)
	var data := SaveManager.snapshot()
	data.schema_version = 10
	data.erase("super_roll_next_trigger")
	return data

func load_legacy(data: Dictionary) -> bool:
	clear_files()
	if not SlimerotSaveFormat.write(SaveManager.save_path, JSON.stringify(data)): return false
	SaveManager.enabled = true
	return SaveManager.load_game()

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var original_path := SaveManager.save_path
	SaveManager.save_path = "res://.godot/Slimerot-progression13-%d.json" % OS.get_process_id()
	var processing := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	test_old_order()
	test_unknown_ids()
	test_super_schedule()
	test_prompt12_preserved()
	fresh()
	SaveManager.save_path = original_path
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	SaveManager.set_process(processing[2])
	CombatManager.set_physics_process(processing[3])
	await get_tree().process_frame

func test_old_order() -> void:
	fresh()
	var old := legacy_state(["R01", "R02"], {"R01": 25, "R02": 40})
	check(load_legacy(old), "schema 10 JSON with R01 + R02 and no R03 loads")
	check(GameState.purchased_skill_node_ids == ["R01", "R02"] and GameState.rolls_balance == 500 and GameState.lifetime_rolls == 565, "old Luck I ownership and wallet are preserved without a refund or free Auto Roll")
	check(is_equal_approx(SkillTreeManager.derived_stats().luck, 1.1) and not SkillTreeManager.derived_stats().auto_roll, "grandfathered Luck I still applies its original effect")
	check(SaveManager.save_game() and SaveManager.load_game(), "grandfathered Luck I remains valid after saving as schema 11")
	check(SkillTreeManager.purchase("R03") and GameState.rolls_balance == 460 and GameState.lifetime_rolls == 565, "old owners can buy R03 later for 40 Rolls")
	check(same_json(GameState.roll_skill_spend, {"R01": 25, "R02": 40, "R03": 40}) and SaveManager.load_game() and SkillTreeManager.derived_stats().auto_roll, "mixed historical and current costs survive the immediate purchase save")
	fresh()
	old = legacy_state(["R01", "R02", "R03"], {"R01": 25, "R02": 40, "R03": 75})
	check(load_legacy(old) and SaveManager.save_game() and SaveManager.load_game(), "old Auto Roll ledger of 75 remains valid despite the new price of 40")
	check(GameState.rolls_balance == 500 and GameState.lifetime_rolls == 640 and GameState.roll_skill_spend.R03 == 75, "both old purchases keep their exact historical spend")
	var invalid := SaveManager.snapshot()
	invalid.purchased_skill_node_ids = ["R01", "R02"]
	invalid.roll_skill_spend = {"R01": 25, "R02": 75}
	invalid.lifetime_rolls = invalid.rolls_balance + 100
	check(not SaveManager.validate(invalid), "new-price Luck I cannot bypass its Auto Roll prerequisite")
	invalid.roll_skill_spend.R02 = 40
	invalid.purchased_skill_node_ids = ["R02"]
	invalid.roll_skill_spend.erase("R01")
	invalid.lifetime_rolls = invalid.rolls_balance + 40
	check(not SaveManager.validate(invalid), "the historical exception still requires R01")

func test_unknown_ids() -> void:
	fresh()
	var old := legacy_state(["R01", "retired_roll_perk", "retired_coin_perk"], {"R01": 25, "retired_roll_perk": 17})
	check(load_legacy(old) and SaveManager.save_game() and SaveManager.load_game(), "unknown nonempty purchased IDs survive migration and reload")
	check(GameState.purchased_skill_node_ids.has("retired_roll_perk") and GameState.purchased_skill_node_ids.has("retired_coin_perk") and GameState.roll_skill_spend.retired_roll_perk == 17, "unknown IDs and their supplied ledger stay intact")
	check(GameState.rolls_balance == 500 and GameState.lifetime_rolls == 542 and SkillTreeManager.derived_stats().luck == 1.0, "unknown Roll spend participates in currency accounting while unknown effects stay inert")
	var invalid := SaveManager.snapshot()
	invalid.purchased_skill_node_ids.append("")
	check(not SaveManager.validate(invalid), "empty persistent IDs are rejected")
	invalid = SaveManager.snapshot()
	invalid.roll_skill_spend.retired_roll_perk = -1
	check(not SaveManager.validate(invalid), "unknown IDs do not excuse invalid ledger values")
	invalid = SaveManager.snapshot()
	invalid.purchased_skill_node_ids.append("C01")
	invalid.roll_skill_spend.C01 = 1
	check(not SaveManager.validate(invalid), "known Coin nodes cannot acquire Roll spend entries")
	fresh()
	old = legacy_state(["quick_hands_1", "luck_1", "retired_roll_perk"], {"retired_roll_perk": 17})
	old.schema_version = 2
	old.lifetime_rolls = 542 # Historical 10 + 15 + preserved unknown 17.
	check(load_legacy(old), "schema 2 migration no longer aborts when a historical unknown ID appears")
	check(GameState.purchased_skill_node_ids == ["R01", "R02", "retired_roll_perk"] and same_json(GameState.roll_skill_spend, {"R01": 10, "R02": 15, "retired_roll_perk": 17}), "legacy names map once while historical unknown spend is retained")
	check(GameState.rolls_balance == 500 and GameState.lifetime_rolls == 542 and SaveManager.save_game(), "legacy migration invents neither currency nor refunds")

func test_super_schedule() -> void:
	fresh()
	var ids: Array = []
	var ledger := {}
	for row in SlimerotRollTree.MAINLINE:
		ids.append(row[0])
		ledger[row[0]] = row[3]
		if row[0] == "R13": break
	ids.append("RO5")
	ledger.RO5 = 650
	ledger.R02 = 40
	ledger.R03 = 75
	var old := legacy_state(ids, ledger)
	old.lifetime_rolls = 12237
	old.rolls_balance = 12237 - SkillTreeManager.rolls_spent(ids, ledger)
	check(load_legacy(old) and GameState.super_roll_next_trigger == 12300, "schema 10 Super Roll preserves its upcoming 100th Lifetime boundary")
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.super_roll_next_trigger == 12300, "the migrated Super Roll schedule persists without rephasing")
	SaveManager.enabled = false
	check(SkillTreeManager.purchase("RO8"), "migrated Super Roll can upgrade through the existing purchase transaction")
	GameState.super_roll_next_trigger = GameState.lifetime_rolls + 21
	SaveManager.enabled = true
	var next := GameState.super_roll_next_trigger
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.super_roll_next_trigger == next, "an arbitrary upgraded cycle boundary round-trips exactly")
	var invalid := SaveManager.snapshot()
	invalid.super_roll_next_trigger = GameState.lifetime_rolls
	check(not SaveManager.validate(invalid), "already-consumed Super Roll targets are rejected")
	invalid.super_roll_next_trigger = GameState.lifetime_rolls + 76
	check(not SaveManager.validate(invalid), "a tier II schedule cannot exceed its 75-roll interval")
	invalid.super_roll_next_trigger = 0
	check(not SaveManager.validate(invalid), "enabled Super Roll cannot erase its representable next target")
	GameState.super_roll_next_trigger = 0
	var derived := SaveManager.snapshot()
	check(derived.super_roll_next_trigger == RollManager.super_schedule_initial(GameState.lifetime_rolls, 75) and GameState.super_roll_next_trigger == 0, "capturing an uninitialized fixture derives the next target without mutating live state")
	GameState.lifetime_rolls = SlimerotSaveFormat.MAX_EXACT_INTEGER - 20
	GameState.rolls_balance = GameState.lifetime_rolls - SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids, GameState.roll_skill_spend)
	var exhausted := SaveManager.snapshot()
	check(exhausted.super_roll_next_trigger == 0 and SaveManager.validate(exhausted), "an exhausted exact-integer boundary keeps a zero schedule without inventing a late trigger")

func test_prompt12_preserved() -> void:
	fresh()
	GameState.lifetime_rolls = 100
	GameState.rolls_balance = 100
	var copy_id := InventoryManager.add_copy("brr_brr_patapim", 7)
	InventoryManager.toggle_copy_favorite(copy_id)
	InventoryManager.equip(copy_id)
	GameState.rolls_since_last_power_improvement = 37
	GameState.shrine_sacrifices = {"shiny": ["brr_brr_patapim"], "glitched": [], "golden": []}
	GameState.last_background_timestamp = 12345.5
	GameState.offline_roll_remainder = 0.125
	var old := SaveManager.snapshot()
	old.schema_version = 10
	old.erase("super_roll_next_trigger")
	var prior_best := GameState.best_ever_effective_rarity
	check(load_legacy(old), "Prompt 12 save with a combined variant migrates directly")
	check(InventoryManager.pair_for_copy(copy_id).variant_flags == 7 and InventoryManager.copy_is_favorite(InventoryManager.pair_for_copy(copy_id), copy_id) and copy_id in InventoryManager.equipped_copy_ids, "combined flags, copy identity, favorites and equipment remain intact")
	check(GameState.best_ever_effective_rarity == prior_best and GameState.rolls_since_last_power_improvement == 37 and GameState.shrine_sacrifices.shiny == ["brr_brr_patapim"], "Prompt 12 rarity history, pity count and Shrine contributions are unchanged")
	check(GameState.last_background_timestamp == 12345.5 and GameState.offline_roll_remainder == 0.125 and GameState.super_roll_next_trigger == 0, "offline checkpoint remains intact and an unowned Super Roll has no trigger")
