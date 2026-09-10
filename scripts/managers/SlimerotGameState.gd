extends Node

signal changed
signal critical_change(reason: String)

var coins := 0
var rolls_balance := 0
var lifetime_rolls := 0
var active_play_seconds := 0.0
var highest_zone_unlocked := 1
var zone_kill_counts: Dictionary = {}
var boss_defeated_flags: Dictionary = {}
var structure_unlocked_flags: Dictionary = {}
var purchased_skill_node_ids: Array[String] = []
var active_potion_type := ""
var potion_remaining_seconds := 0.0
var settings: Dictionary = SlimerotBalance.SETTINGS.duplicate(true)
var current_zone := 0
var player_hp := SlimerotBalance.PLAYER_HP
var suspended := false

func _process(delta: float) -> void:
	if suspended:
		return
	active_play_seconds += delta
	if potion_remaining_seconds > 0.0:
		potion_remaining_seconds = maxf(0.0, potion_remaining_seconds - delta)
		if potion_remaining_seconds == 0.0:
			active_potion_type = ""

func reset() -> void:
	coins = 0
	rolls_balance = 0
	lifetime_rolls = 0
	active_play_seconds = 0.0
	highest_zone_unlocked = 1
	zone_kill_counts.clear()
	boss_defeated_flags.clear()
	structure_unlocked_flags.clear()
	purchased_skill_node_ids.clear()
	active_potion_type = ""
	potion_remaining_seconds = 0.0
	settings = SlimerotBalance.SETTINGS.duplicate(true)
	current_zone = 0
	player_hp = SlimerotBalance.PLAYER_HP
	changed.emit()

func spend(currency: String, amount: int) -> bool:
	if amount < 0:
		return false
	match currency:
		"Coins":
			if coins < amount:
				return false
			coins -= amount
		"Rolls":
			if rolls_balance < amount:
				return false
			rolls_balance -= amount
		_:
			return false
	changed.emit()
	return true

func award_coins(amount: int) -> void:
	coins += maxi(0, amount)
	changed.emit()
