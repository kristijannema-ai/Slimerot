extends Node

# Slimerot uses this isolated profile to exercise real process death between
# background checkpoint, offline reward commit, and a second reopened process.
const PROFILE := "res://.godot/Slimerot-offline-restart.json"
const BACKGROUND_AT := 10000.0
const INITIAL_LIFETIME := 1000
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Slimerot OFFLINE RESTART FAIL: " + label)

func _ready() -> void:
	assert("--slimerot-offline-restart-probe" in OS.get_cmdline_user_args())
	assert(SaveManager.save_path == PROFILE)
	GameState.set_process(false)
	RollManager.set_process(false)
	SaveManager.set_process(false)
	CombatManager.set_physics_process(false)
	if "--slimerot-offline-restart-write" in OS.get_cmdline_user_args():
		write_fixture()
	else:
		await verify_fixture()

func write_fixture() -> void:
	SaveManager.enabled = false
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	GameState.rolls_balance = INITIAL_LIFETIME
	GameState.lifetime_rolls = INITIAL_LIFETIME
	for id in ["R01", "R02", "R03"]: assert(SkillTreeManager.purchase(id))
	GameState.settings.auto_roll_state = true
	GameState.award_coins(765)
	GameState.active_play_seconds = 25.5
	GameState.active_potion_type = "lucky_soda"
	GameState.potion_remaining_seconds = 120.25
	GameState.boss_brew_seconds = 90.5
	var first := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equipped_copy_ids.assign([first])
	InventoryManager.toggle_copy_favorite(first)
	RollManager.cooldown_remaining = SkillTreeManager.derived_stats().roll_cooldown
	SaveManager.enabled = true
	assert(SaveManager.enter_background(BACKGROUND_AT))
	print("Slimerot OFFLINE RESTART READY")
	# The process intentionally remains open for an external force termination.

func verify_fixture() -> void:
	var second_reopen := "--slimerot-offline-restart-verify" in OS.get_cmdline_user_args()
	var expected_lifetime := INITIAL_LIFETIME + 100 if second_reopen else INITIAL_LIFETIME
	check(SaveManager.enabled and SaveManager.last_error.is_empty(), "isolated saved profile loads")
	check(GameState.lifetime_rolls == expected_lifetime and GameState.rolls_balance == expected_lifetime - 140, "pre-resume wallet agrees with the committed generation")
	var resume_at: float = BACKGROUND_AT + SkillTreeManager.derived_stats().roll_cooldown * 100.0
	var summary: Dictionary = await SaveManager.resume_from_background(resume_at)
	check(GameState.lifetime_rolls == INITIAL_LIFETIME + 100 and GameState.rolls_balance == INITIAL_LIFETIME - 140 + 100, "force-close catch-up awards exactly 100 Rolls and Lifetime Rolls once")
	check(int(summary.get("rolls", 0)) == (0 if second_reopen else 100), "second reopened process has no already claimed AFK rewards")
	check(GameState.coins == 765 and GameState.coins_earned == 765 and GameState.coins_spent == 0, "no offline combat Coins")
	check(GameState.active_play_seconds == 25.5 and GameState.potion_remaining_seconds == 120.25 and GameState.boss_brew_seconds == 90.5, "active timers do not advance across process death")
	check(InventoryManager.equipped_copy_ids == ["slimerot_copy_1"] and InventoryManager.is_protected("slimerot_copy_1"), "team and favorite survive process death")
	var owned := 0
	for pair in InventoryManager.inventory.values(): owned += int(pair.quantity)
	check(owned == 101 and InventoryManager.collection().size() == 24, "one hundred AFK drops survive with the original protected copy")
	check(RollManager.reveal_queue.is_empty() and RollManager.active_reveal.is_empty(), "reopen does not enqueue a reveal for every offline roll")
	check(not SaveManager.offline_processing and not SaveManager.offline_commit_pending and SaveManager.last_error.is_empty(), "reward batch is committed durably before gameplay resumes")
	await SaveManager.resume_from_background(resume_at)
	check(GameState.lifetime_rolls == INITIAL_LIFETIME + 100, "duplicate resume in this process remains idempotent")
	print("Slimerot OFFLINE RESTART RESULT: %d checks; %d failures" % [checks, failures])
	SaveManager.enabled = false
	get_tree().quit(0 if failures == 0 else 1)
