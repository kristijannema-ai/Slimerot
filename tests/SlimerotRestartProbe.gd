extends Node

# Slimerot desktop process-death probe. The writer is externally killed after READY.
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Slimerot RESTART FAIL: " + label)

func _ready() -> void:
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	if "--slimerot-restart-write" in OS.get_cmdline_user_args():
		write_fixture()
	else:
		verify_fixture()

func write_fixture() -> void:
	SaveManager.enabled = false
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	RollManager.variant_rng.seed = 1234
	assert(RollManager.request_roll())
	GameState.coins = 1000000
	GameState.coins_earned = 1000000
	GameState.lifetime_rolls = 10000
	GameState.rolls_balance = 10000
	GameState.highest_zone_unlocked = 8
	for zone in range(1, 8): GameState.unlocked_gate_flags[str(zone)] = true
	for zone in [2, 4, 6]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	for row in SlimerotEncounters.STRUCTURES: GameState.structure_unlocked_flags[row[0]] = true
	for index in range(1, 9): assert(SkillTreeManager.purchase("R%02d" % index))
	for id in ["C01", "C02", "C05", "C06"]: assert(SkillTreeManager.purchase(id))
	var shiny := InventoryManager.add_copy("brr_brr_patapim", "shiny")
	var duplicate := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equipped_copy_ids.assign([duplicate, shiny, "slimerot_copy_1"])
	InventoryManager.toggle_copy_favorite(duplicate)
	GameState.active_play_seconds = 42.5
	GameState.active_potion_type = "hyper_soda"
	GameState.potion_remaining_seconds = 123.25
	GameState.boss_brew_seconds = 90.5
	GameState.potion_inventory = {"lucky_soda": 2}
	WorldManager.travel(8)
	GameState.zone_kill_counts["8"] = 100
	assert(WorldManager.finish_boss_reward(8))
	assert(WorldManager.complete_campaign())
	RollManager.cooldown_remaining = 0.7
	SaveManager.enabled = true
	assert(SaveManager.save_game())
	print("Slimerot RESTART READY")

func verify_fixture() -> void:
	check(SaveManager.enabled and SaveManager.last_error.is_empty(), "autoload recovered save")
	check(GameState.coins == 6994850 and GameState.coins_earned == 7000000 and GameState.coins_spent == 5150, "Coin accounting")
	check(GameState.lifetime_rolls == 10000 and GameState.rolls_balance == 8035, "Roll accounting")
	check(is_equal_approx(SkillTreeManager.derived_stats().luck, 30.36) and is_equal_approx(RollManager.effective_luck(), 91.08), "B1 derives once")
	check(InventoryManager.equipped_copy_ids == ["slimerot_copy_3", "slimerot_copy_2", "slimerot_copy_1"] and InventoryManager.next_copy_id == 4, "exact team order and copy serial")
	check(InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity == 2 and InventoryManager.is_protected("slimerot_copy_3"), "quantities and favorite")
	check(InventoryManager.discoveries.get("brr_brr_patapim", []).has("shiny"), "variant collection")
	check(GameState.active_play_seconds == 42.5 and GameState.potion_remaining_seconds == 123.25 and GameState.boss_brew_seconds == 90.5, "no offline timer advance")
	check(GameState.potion_inventory.get("lucky_soda") == 2 and is_equal_approx(RollManager.cooldown_remaining, 0.7), "bottles and cooldown")
	check(GameState.current_zone == 8 and GameState.highest_zone_unlocked == 8 and GameState.zone_kill_counts.get("8") == 100 and WorldManager.gate_open(7), "zone, kills and gates")
	check(GameState.boss_defeated_flags.get("zone_8", false) and GameState.completion_portal_unlocked and GameState.campaign_completed, "final boss and free-roam completion")
	print("Slimerot RESTART RESULT: %d checks; %d failures" % [checks, failures])
	SaveManager.enabled = false
	get_tree().quit(0 if failures == 0 else 1)
