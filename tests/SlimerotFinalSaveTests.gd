extends Node

# Final migration acceptance uses real JSON and the production candidate loader.
var world: Node
var suite: Node

# Literal historical fixture data, independent of today's provisional price table.
const PROMPT15_ROLL_PRICES := {"R01": 25, "R03": 40, "R02": 75, "R04": 125, "R05": 175,
	"R06": 275, "R07": 350, "R08": 900, "R09": 350, "R10": 400, "R11": 550, "R12": 550,
	"R13": 1300, "R14": 700, "R15": 700, "R16": 900, "R17": 900, "R18": 1300,
	"RO1": 150, "RO2": 450, "RO3": 300, "RO4": 500, "RO5": 650, "RO8": 900,
	"RO9": 1500, "RO6": 700, "RO7": 1400}

func check(condition: bool, label: String) -> void:
	suite.check(condition, "Final save · " + label)

func same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func clear_files() -> void:
	assert(SaveManager.save_path.begins_with("res://.godot/Slimerot-final-save-"))
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(SaveManager.save_path + suffix): DirAccess.remove_absolute(SaveManager.save_path + suffix)

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
	SaveManager.last_error = ""
	SaveManager.generation = 0
	WorldManager.travel(0)
	clear_files()

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	var previous_path: String = SaveManager.save_path
	var processes := [GameState.is_processing(), RollManager.is_processing(), SaveManager.is_processing(), CombatManager.is_physics_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	SaveManager.save_path = "res://.godot/Slimerot-final-save-%d.json" % OS.get_process_id()
	for version in range(1, SlimerotBalance.SCHEMA_VERSION + 1):
		migration_case(version)
	for version in [9, 10, 11]: historical_prices_case(version)
	ancient_missing_ledger_case()
	fresh()
	var early := SaveManager.snapshot()
	early.erase("dash_unlocked")
	var migrated: Dictionary = SaveManager.migrate(early)
	check(SaveManager.validate(migrated) and not migrated.dash_unlocked, "pre-Dash Z1 save keeps Dash locked until its tutorial")
	fresh()
	SaveManager.save_path = previous_path
	GameState.set_process(processes[0])
	RollManager.set_process(processes[1])
	SaveManager.set_process(processes[2])
	CombatManager.set_physics_process(processes[3])
	await get_tree().process_frame

func migration_case(version: int) -> void:
	fresh()
	GameState.coins = 123456
	GameState.coins_earned = 123456
	GameState.rolls_balance = 1000
	GameState.lifetime_rolls = 1065
	GameState.purchased_skill_node_ids.assign(["R01", "R02", "retired_final_fixture"])
	GameState.roll_skill_spend = {"R01": 25, "R02": 40}
	GameState.highest_zone_unlocked = 6
	GameState.current_zone = 6
	for zone in range(1, 6): GameState.unlocked_gate_flags[str(zone)] = true
	GameState.boss_defeated_flags = {"zone_2": true, "zone_4": true}
	GameState.zone_kill_counts = {"1": 50, "2": 60, "3": 70, "4": 80, "5": 90}
	GameState.structure_unlocked_flags = {"skill_tree_shrine": true, "sell_terminal": true}
	var first := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "shiny", false)
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "shiny", false)
	var second := InventoryManager.add_copy("brr_brr_patapim", "golden", false)
	InventoryManager.equipped_copy_ids.assign([second])
	InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":shiny"].favorite = true
	GameState.last_background_timestamp = 12345.5
	GameState.offline_roll_remainder = 0.125
	var data := SaveManager.snapshot()
	data.schema_version = version
	data.erase("dash_unlocked")
	if version < 11: data.erase("super_roll_next_trigger")
	if version < 10:
		for key in ["best_ever_effective_rarity", "rolls_since_last_power_improvement", "shrine_sacrifices"]: data.erase(key)
		for pair in data.inventory.values(): pair.erase("variant_flags")
	if version < 9:
		data.erase("last_background_timestamp")
		data.erase("offline_roll_remainder")
		for pair in data.inventory.values():
			pair.erase("copy_ranges")
			pair.erase("favorite_copy_ranges")
	var bytes := SlimerotSaveFormat.encode(data, version)
	check(SlimerotSaveFormat.write(SaveManager.save_path, bytes), "schema %d fixture written" % version)
	SaveManager.enabled = true
	check(SaveManager.load_game(), "schema %d loads through complete production migration chain" % version)
	check(GameState.coins == 123456 and GameState.rolls_balance == 1000 and GameState.lifetime_rolls == 1065, "schema %d preserves all three currencies" % version)
	check(GameState.purchased_skill_node_ids == ["R01", "R02", "retired_final_fixture"] and same_json(GameState.roll_skill_spend, {"R01": 25, "R02": 40}), "schema %d preserves old Luck I, historical spend and unknown purchased ID" % version)
	check(GameState.highest_zone_unlocked == 6 and GameState.current_zone == 6 and GameState.boss_defeated_flags == {"zone_2": true, "zone_4": true} and WorldManager.gate_open(5), "schema %d preserves bosses and contiguous zone progression" % version)
	check(InventoryManager.next_copy_id == 4 and InventoryManager.equipped_copy_ids == [second] and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":shiny"].quantity == 2 and InventoryManager.is_protected(first), "schema %d preserves inventory identities, team, quantities and favorites" % version)
	check(InventoryManager.pair_for_copy(second).variant_flags == SlimerotVariants.GOLDEN and InventoryManager.pair_for_copy(first).variant_flags == SlimerotVariants.SHINY, "schema %d single variants migrate to exact independent flags" % version)
	check(GameState.shrine_sacrifices == {"shiny": [], "glitched": [], "golden": []} and GameState.dash_unlocked, "schema %d defaults empty Shrine sets and grants reached-Z2 Dash" % version)
	check(GameState.last_background_timestamp == (0.0 if version < 9 else 12345.5) and GameState.offline_roll_remainder == (0.0 if version < 9 else 0.125), "schema %d defaults pre-AFK timestamps or preserves existing checkpoint" % version)
	check(not GameState.purchased_skill_node_ids.has("C20") and not GameState.purchased_skill_node_ids.has("RO8") and not GameState.purchased_skill_node_ids.has("RO9"), "schema %d does not purchase new skill nodes" % version)
	check(FileAccess.get_file_as_string(SaveManager.save_path) == bytes, "schema %d load preserves source bytes until a validated save" % version)
	var luck := RollManager.get_effective_luck()
	check(SaveManager.save_game() and SaveManager.load_game() and RollManager.get_effective_luck() == luck and GameState.rolls_balance == 1000, "schema %d current-schema save/reload never reapplies luck or charges a second purchase" % version)

func historical_prices_case(version: int) -> void:
	fresh()
	GameState.coins = 1234567
	GameState.coins_earned = 1234567 + 688000 # Historical Fortune I+II+III costs.
	GameState.coins_spent = 688000
	GameState.rolls_balance = 54321
	GameState.highest_zone_unlocked = 8
	for zone in range(1, 8): GameState.unlocked_gate_flags[str(zone)] = true
	GameState.roll_skill_spend = PROMPT15_ROLL_PRICES.duplicate()
	# Pre-Prompt-13 profiles only knew Super I and had the original R02/R03 prices.
	if version < 11:
		GameState.roll_skill_spend.erase("RO8")
		GameState.roll_skill_spend.erase("RO9")
		GameState.roll_skill_spend.R02 = 40
		GameState.roll_skill_spend.R03 = 75
	GameState.roll_skill_spend["retired_paid_node"] = 17
	GameState.purchased_skill_node_ids.assign(GameState.roll_skill_spend.keys())
	GameState.purchased_skill_node_ids.append("retired_coin_node")
	if version == 11: GameState.purchased_skill_node_ids.append_array(["C20", "C21", "C22"])
	GameState.lifetime_rolls = GameState.rolls_balance
	for paid in GameState.roll_skill_spend.values(): GameState.lifetime_rolls += int(paid)
	GameState.super_roll_next_trigger = GameState.lifetime_rolls + 17
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false)
	InventoryManager.equipped_copy_ids.assign(["slimerot_copy_1"])
	var data := SaveManager.snapshot()
	data.schema_version = version
	if version < 11: data.erase("super_roll_next_trigger")
	if version < 10:
		for key in ["best_ever_effective_rarity", "rolls_since_last_power_improvement", "shrine_sacrifices"]: data.erase(key)
		for pair in data.inventory.values(): pair.erase("variant_flags")
	check(SlimerotSaveFormat.write(SaveManager.save_path, SlimerotSaveFormat.encode(data, 90 + version)), "historical-price schema %d fixture writes actual old costs" % version)
	SaveManager.enabled = true
	var loaded := SaveManager.load_game()
	check(loaded, "historical-price schema %d loads despite cheaper current prices" % version)
	if not loaded: return
	check(GameState.coins == data.coins and GameState.rolls_balance == data.rolls_balance and GameState.lifetime_rolls == data.lifetime_rolls and GameState.coins_spent == 688000, "historical-price schema %d preserves wallets and lifetime spend without refunds" % version)
	check(same_json(GameState.roll_skill_spend, data.roll_skill_spend) and same_json(GameState.purchased_skill_node_ids, data.purchased_skill_node_ids), "historical-price schema %d retains every old price, purchase and unknown ID" % version)
	check(SkillTreeManager.derived_stats().breakthrough_product == 8000.0 and GameState.roll_skill_spend.R08 == 900 and GameState.roll_skill_spend.R13 == 1300 and GameState.roll_skill_spend.RO5 == 650, "historical-price schema %d preserves exact x8000 Breakthroughs and old checkpoint/Super costs" % version)
	var luck := RollManager.get_effective_luck()
	var trigger: int = GameState.super_roll_next_trigger
	check(SaveManager.save_game() and SaveManager.load_game() and RollManager.get_effective_luck() == luck and GameState.super_roll_next_trigger == trigger and same_json(GameState.roll_skill_spend, data.roll_skill_spend), "historical-price schema %d re-saves and reloads without repricing or rephasing" % version)
	check(not SkillTreeManager.purchase("R08") and GameState.rolls_balance == data.rolls_balance, "historical-price schema %d cannot purchase owned Breakthrough again" % version)
	var invalid := SaveManager.snapshot()
	invalid.roll_skill_spend.R08 = 901
	invalid.lifetime_rolls += 1
	check(not SaveManager.validate(invalid), "historical-price schema %d rejects spend exceeding every published R08 price" % version)
	invalid = SaveManager.snapshot()
	invalid.roll_skill_spend.retired_paid_node = -1
	check(not SaveManager.validate(invalid), "historical-price schema %d still rejects malformed unknown-node spend" % version)

func ancient_missing_ledger_case() -> void:
	fresh()
	GameState.rolls_balance = 456
	GameState.lifetime_rolls = 456
	for row in SlimerotRollTree.MAINLINE:
		GameState.purchased_skill_node_ids.append(row[0])
		var paid: int = PROMPT15_ROLL_PRICES[row[0]]
		if row[0] == "R02": paid = 40
		if row[0] == "R03": paid = 75
		GameState.lifetime_rolls += paid
	var data := SaveManager.snapshot()
	data.schema_version = 2
	data.roll_skill_spend = {}
	check(SlimerotSaveFormat.write(SaveManager.save_path, JSON.stringify(data)), "ancient no-ledger fixture writes historical canonical purchases")
	SaveManager.enabled = true
	var loaded := SaveManager.load_game()
	check(loaded, "ancient canonical IDs without a ledger reconstruct historical prices rather than discounted prices")
	if not loaded: return
	check(GameState.rolls_balance == 456 and GameState.lifetime_rolls == data.lifetime_rolls and GameState.roll_skill_spend.R08 == 900 and GameState.roll_skill_spend.R13 == 1300, "ancient missing-ledger migration preserves its currency identity")
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.rolls_balance == 456, "reconstructed historical ledger validates through repeated current-schema saves")
