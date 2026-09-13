class_name SlimerotBalance
extends RefCounted

const SCHEMA_VERSION := 4
const MAX_SLOTS := 5
const PLAYER_HP := 100.0
const MOVE_SPEED := 180.0
const ROLL_COOLDOWN := 2.4
const ATTACK_INTERVAL := 1.0
const ATTACK_RANGE := 180.0
const PROJECTILE_SPEED := 500.0
const REGEN_DELAY := 4.0
const REGEN_FRACTION := 0.05
const DEATH_FADE_SECONDS := 1.5
const SLIME_ORBIT_RADIUS := 52.0
const AUTOSAVE_SECONDS := 10.0
const FIRST_SLIME := "tung_tung_tung_sahur"
const VARIANTS := ["normal", "shiny", "glitched", "golden"]
const VARIANT_DATA := {
	"normal": {"chance": 0.9889, "damage": 1.0, "sell": 1.0, "color": Color("b6ed78")},
	"shiny": {"chance": 0.01, "damage": 1.5, "sell": 2.0, "color": Color("bcfaff")},
	"glitched": {"chance": 0.001, "damage": 2.5, "sell": 5.0, "color": Color("e894ff")},
	"golden": {"chance": 0.0001, "damage": 4.0, "sell": 10.0, "color": Color("ffdc77")},
}
const VARIANT_SENSE_MULTIPLIER := 1.25
const LUCK_CAPS := {"MAX": 0.0, "x20-era": 20.0, "x1": 1.0}
const MAX_ZONE := 8
const RESET_HOLD_SECONDS := 3.0
# Slimerot's early enemy tuning remains provisional; roster and Roll tree are canonical.
const STARTER_DAMAGE := 7.0
const STARTER_SELL := 5
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
	"auto_sell_settings": {"enabled": false, "threshold": 100}, "luck_cap": 0.0,
}
