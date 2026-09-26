extends Node

# Desktop process-death analog of the eight Android cases. The external runner
# terminates this process after READY, without _exit_tree or a graceful save.
const BACKGROUND_AT := 10000.0
var case_number := 0
var mode := ""
var checks := 0
var failures := 0
var profile := ""

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Slimerot FINAL RESTART FAIL case %d: %s" % [case_number, label])

func _ready() -> void:
	assert("--slimerot-test" in OS.get_cmdline_user_args())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): case_number = int(argument.trim_prefix("--case="))
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
	assert(case_number >= 1 and case_number <= 8 and mode in ["write", "resume", "verify"])
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	SaveManager.enabled = false
	profile = "res://.godot/Slimerot-final-restart-%d.json" % case_number
	SaveManager.save_path = profile
	if mode == "write": await write_case()
	else: await reopen_case()

func initial_state() -> void:
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(profile + suffix): DirAccess.remove_absolute(profile + suffix)
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	GameState.coins = 1000000
	GameState.coins_earned = 1000000
	GameState.rolls_balance = 20000
	GameState.lifetime_rolls = 20000
	GameState.highest_zone_unlocked = 6
	GameState.current_zone = 6
	for zone in range(1, 6): GameState.unlocked_gate_flags[str(zone)] = true
	GameState.boss_defeated_flags = {"zone_2": true, "zone_4": true}
	GameState.structure_unlocked_flags = {"skill_tree_shrine": true, "sell_terminal": true, "mutation_lab": true}
	GameState.zone_kill_counts = {"6": 100}
	var protected := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false)
	InventoryManager.equipped_copy_ids.assign([protected])
	InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].favorite = true
	GameState.active_play_seconds = 77.5
	GameState.active_potion_type = "lucky_soda"
	GameState.potion_remaining_seconds = 120.25
	SaveManager.application_paused = false
	SaveManager.focus_lost = false
	SaveManager.offline_processing = false
	SaveManager.offline_commit_pending = false
	SaveManager.last_error = ""
	SaveManager.generation = 0

func write_case() -> void:
	initial_state()
	if case_number in [1, 2]:
		assert(SkillTreeManager.purchase("R01") and SkillTreeManager.purchase("R03"))
		GameState.settings.auto_roll_state = true
		RollManager.cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown
	if case_number == 4: InventoryManager.add_copy("brr_brr_patapim", 7, false)
	if case_number == 6:
		for row in SlimerotRollTree.MAINLINE:
			if row[0] == "R08": break
			assert(SkillTreeManager.purchase(row[0]))
	if case_number == 8:
		GameState.highest_zone_unlocked = 2
		GameState.current_zone = 2
		GameState.unlocked_gate_flags = {"1": true}
		GameState.boss_defeated_flags.clear()
	SaveManager.enabled = true
	assert(SaveManager.save_game()) # Initial checkpoint only; actions below must save themselves.
	var previous_generation: int = SaveManager.generation
	match case_number:
		1, 2:
			# Set a deterministic clock in the isolated profile, not the system clock.
			GameState.last_background_timestamp = 0.0
			assert(SaveManager.enter_background(BACKGROUND_AT))
			if case_number == 1:
				var summary: Dictionary = await SaveManager.resume_from_background(resume_at())
				check(summary.rolls == 100, "background/resume awards 100 logical rolls")
				await SaveManager.resume_from_background(resume_at())
				check(GameState.lifetime_rolls == 20100, "duplicate resume gives no second reward")
		3:
			# Force an issued result's RNG outcome while retaining production commit ownership.
			var result := RollManager.resolve_roll()
			var flags := 7
			var id := "brainrot_singularity"
			result.data.merge({"slime_id": id, "variant": SlimerotVariants.key(flags), "variant_flags": flags,
				"threshold": SlimeDatabase.get_slime(id).rarity_threshold, "effective_rarity": SlimeDatabase.get_effective_rarity(id, flags),
				"base_damage": SlimeDatabase.get_base_combat_damage(id, flags), "power_improvement": true}, true)
			assert(RollManager.commit_roll(result))
			check(not RollManager.commit_roll(result), "issued rare roll cannot commit twice")
		4: assert(InventoryManager.sacrifice("slimerot_copy_2", SlimerotVariants.SHINY))
		5: assert(SkillTreeManager.purchase("R01"))
		6: assert(SkillTreeManager.purchase("R08"))
		7: assert(WorldManager.finish_boss_reward(6))
		8: assert(GameState.unlock_dash())
	check(SaveManager.generation > previous_generation and SaveManager.last_error.is_empty(), "transaction itself wrote a durable generation")
	write_expected()
	ready_for_kill()

func resume_at() -> float:
	return BACKGROUND_AT + SkillTreeManager.derived_stats().roll_cooldown * 100.0

func write_expected() -> void:
	var state := SaveManager.snapshot()
	state["probe_luck"] = RollManager.get_effective_luck()
	assert(SlimerotSaveFormat.write(profile + ".expected", JSON.stringify(state)))

func ready_for_kill() -> void:
	if failures > 0:
		finish()
		return
	print("Slimerot FINAL RESTART READY case=%d mode=%s checks=%d" % [case_number, mode, checks])
	# Keep running: the external runner uses TerminateProcess, not normal quit.

func reopen_case() -> void:
	SaveManager.enabled = true
	check(SaveManager.load_game() and SaveManager.last_error.is_empty(), "fresh process loads committed profile")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile + ".expected"))
	for key in ["coins", "coins_earned", "coins_spent", "rolls_balance", "lifetime_rolls", "boss_defeated_flags", "highest_zone_unlocked", "current_zone", "unlocked_gate_flags", "purchased_skill_node_ids", "roll_skill_spend", "inventory", "equipped_copy_ids", "discoveries", "next_copy_id", "shrine_sacrifices", "dash_unlocked", "best_ever_effective_rarity", "rolls_since_last_power_improvement", "super_roll_next_trigger", "last_background_timestamp", "offline_roll_remainder", "settings"]:
		check(JSON.parse_string(JSON.stringify(SaveManager.snapshot()[key])) == expected[key], "preserves " + key)
	check(is_equal_approx(RollManager.get_effective_luck(), expected.probe_luck), "derived luck is identical after reopen")
	check(InventoryManager.is_protected("slimerot_copy_1") and InventoryManager.equipped_copy_ids == ["slimerot_copy_1"], "protected team copy survives")
	if case_number in [1, 2]:
		var before: int = GameState.lifetime_rolls
		var summary: Dictionary = await SaveManager.resume_from_background(resume_at())
		var owed := 100 if case_number == 2 and mode == "resume" else 0
		check(summary.rolls == owed and GameState.lifetime_rolls == before + owed and GameState.lifetime_rolls == 20100, "offline interval commits exactly once")
		await SaveManager.resume_from_background(resume_at())
		check(GameState.lifetime_rolls == 20100 and InventoryManager.next_copy_id == 102, "duplicate resume cannot duplicate currencies or copies")
		check(GameState.active_play_seconds == 77.5 and GameState.potion_remaining_seconds == 120.25, "active timers remain frozen during AFK")
	if case_number == 3:
		check(InventoryManager.pair_for_copy("slimerot_copy_2").variant_flags == 7 and GameState.lifetime_rolls == 20001, "multi-variant roll has one persistent copy and one reward")
	if case_number == 4:
		check(InventoryManager.pair_for_copy("slimerot_copy_2").is_empty() and is_equal_approx(InventoryManager.shrine_multiplier(SlimerotVariants.SHINY), 1.05), "sacrificed copy stays consumed and multiplier persists")
		check(not InventoryManager.sacrifice("slimerot_copy_2", SlimerotVariants.SHINY), "sacrifice cannot replay")
	if case_number == 5: check(not SkillTreeManager.purchase("R01"), "skill purchase cannot replay")
	if case_number == 6: check(not SkillTreeManager.purchase("R08") and SkillTreeManager.derived_stats().breakthrough_product == 20.0, "Breakthrough is exactly x20 and cannot replay")
	if case_number == 7:
		check(WorldManager.progression_gate_role(6) == "exit" and not WorldManager.finish_boss_reward(6), "saved boss flag keeps CombinedBossGate in next-zone state and blocks repeated reward")
	if case_number == 8: check(GameState.dash_unlocked and not GameState.unlock_dash(), "Dash stays unlocked without duplicate unlock")
	if mode == "resume":
		write_expected()
		ready_for_kill()
	else: finish()

func finish() -> void:
	print("Slimerot FINAL RESTART RESULT: case=%d checks=%d failures=%d" % [case_number, checks, failures])
	SaveManager.enabled = false
	get_tree().quit(0 if failures == 0 else 1)
