extends Node

signal changed
signal critical_change(reason: String)

var coins := 0
var rolls_balance := 0
var lifetime_rolls := 0
var active_play_seconds := 0.0
var highest_zone_unlocked := 1
var zone_kill_counts: Dictionary = {}
var unlocked_gate_flags: Dictionary = {}
var boss_defeated_flags: Dictionary = {}
var structure_unlocked_flags: Dictionary = {}
var purchased_skill_node_ids: Array[String] = []
var roll_skill_spend: Dictionary = {}
var active_potion_type := ""
var potion_remaining_seconds := 0.0
var settings: Dictionary = SlimerotBalance.SETTINGS.duplicate(true)
var current_zone := 0
var player_hp := SlimerotBalance.PLAYER_HP
var player_dead := false
var suspended := false
var menu_paused := false
var active_potion_multiplier := 1.0
var coins_earned := 0
var coins_spent := 0
var rarest_threshold_reached := 0
var highest_luck := 1.0
var best_team_dps := 0.0
var potion_inventory: Dictionary = {}
var boss_brew_seconds := 0.0
var completion_portal_unlocked := false
var campaign_completed := false

func is_paused() -> bool:
	return suspended or menu_paused

func _process(delta: float) -> void:
	if is_paused():
		return
	active_play_seconds += delta
	var had_brew := boss_brew_seconds > 0
	boss_brew_seconds = maxf(0,boss_brew_seconds-delta)
	if had_brew and boss_brew_seconds == 0: changed.emit()
	if potion_remaining_seconds > 0.0:
		potion_remaining_seconds = maxf(0.0, potion_remaining_seconds - delta)
		if potion_remaining_seconds == 0.0:
			active_potion_type = ""
			active_potion_multiplier = 1.0
			changed.emit()
	highest_luck = maxf(highest_luck, RollManager.effective_luck())

func reset() -> void:
	coins = 0
	coins_earned = 0
	coins_spent = 0
	rarest_threshold_reached = 0
	highest_luck = 1.0
	best_team_dps = 0.0
	potion_inventory.clear()
	boss_brew_seconds = 0.0
	completion_portal_unlocked = false
	campaign_completed = false
	active_potion_multiplier = 1.0
	rolls_balance = 0
	lifetime_rolls = 0
	active_play_seconds = 0.0
	highest_zone_unlocked = 1
	zone_kill_counts.clear()
	unlocked_gate_flags.clear()
	boss_defeated_flags.clear()
	structure_unlocked_flags.clear()
	purchased_skill_node_ids.clear()
	roll_skill_spend.clear()
	active_potion_type = ""
	potion_remaining_seconds = 0.0
	settings = SlimerotBalance.SETTINGS.duplicate(true)
	current_zone = 0
	player_hp = SlimerotBalance.PLAYER_HP
	CombatManager.reset_combat()
	changed.emit()

func spend(currency: String, amount: int, notify: bool = true) -> bool:
	if amount < 0:
		return false
	match currency:
		"Coins":
			if coins < amount:
				return false
			coins -= amount
			coins_spent += amount
		"Rolls":
			if rolls_balance < amount:
				return false
			rolls_balance -= amount
		_:
			return false
	if notify: changed.emit()
	return true

func award_coins(amount: int, notify: bool = true) -> void:
	coins += maxi(0, amount)
	coins_earned += maxi(0, amount)
	if notify: changed.emit()
