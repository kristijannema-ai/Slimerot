class_name SlimerotBalance
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_SLOTS := 5
const PLAYER_HP := 100.0
const MOVE_SPEED := 180.0
const ROLL_COOLDOWN := 2.4
const ATTACK_INTERVAL := 1.0
const ATTACK_RANGE := 180.0
const AUTOSAVE_SECONDS := 10.0
const FIRST_SLIME := "tung_tung_tung_sahur"
const VARIANTS := ["normal", "shiny", "rainbow"]
# Slimerot stage-one tuning: damage and upgrade prices await the full balance tables.
const STARTER_DAMAGE := 10.0
const STARTER_SELL := 2
const EARLY_ROLL_NODES := [["quick_hands_1", 10, "cooldown_multiplier", 0.9], ["luck_1", 15, "luck_multiplier", 1.25], ["auto_roll", 25, "auto_roll", 1.0]]
const EARLY_STRUCTURES := [["skill_tree_shrine", 25, "skill_tree"], ["sell_terminal", 75, "sell_duplicates"]]
const BACKYARD_GATE_KILLS := 12
const BACKYARD_GATE_COINS := 150
const LAGLING_HP := 30.0
const LAGLING_DAMAGE := 8.0
const LAGLING_COINS := 5
const LAGLING_SPEED := 55.0
const LAGLING_ATTACK_INTERVAL := 1.0
const ENEMY_RESPAWN_SECONDS := 5.0
const INTERACT_RANGE := 110.0
const WORLD_SIZE := Vector2(1000, 1400)
const ENTRANCES := {0: Vector2(500, 1090), 1: Vector2(500, 1150)}
const SETTINGS := {
	"master_audio": 1.0, "music_audio": 0.7, "sfx_audio": 1.0,
	"screen_shake": true, "vibration": true, "auto_roll_state": false,
	"auto_sell_settings": {"enabled": false}, "luck_cap": 0.0,
}
