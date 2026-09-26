class_name SlimerotRollTree
extends RefCounted

# Prompt 16 provisional tempo prices; IDs, effects and exact x20 checkpoints are unchanged.
# ID, name, prerequisite, Rolls cost, effect, value, description.
const MAINLINE := [
	["R01", "Quick Hands I", "", 25, "cooldown_set", 2.20, "Cooldown 2.40 → 2.20 seconds"],
	["R03", "Auto Roll", "R01", 40, "auto_roll", 1.0, "Unlock Auto Roll while exploring and fighting"],
	["R02", "Luck I", "R03", 75, "luck_multiplier", 1.10, "Minor luck ×1.10"],
	["R04", "Quick Hands II", "R02", 30, "cooldown_set", 1.90, "Cooldown 2.20 → 1.90 seconds"],
	["R05", "Luck II", "R04", 45, "luck_multiplier", 1.15, "Minor luck ×1.15"],
	["R06", "Quick Hands III", "R05", 70, "cooldown_set", 1.55, "Cooldown 1.90 → 1.55 seconds"],
	["R07", "Luck III", "R06", 90, "luck_multiplier", 1.20, "Minor luck ×1.20"],
	["R08", "BREAKTHROUGH I: RNG Overdrive", "R07", 225, "checkpoint_luck", 20.0, "TOTAL luck ×20 · unlock Luck Cap"],
	["R09", "Quick Hands IV", "R08", 90, "cooldown_set", 1.25, "Cooldown 1.55 → 1.25 seconds"],
	["R10", "Luck IV", "R09", 100, "luck_multiplier", 1.20, "Minor luck ×1.20"],
	["R11", "Quick Hands V", "R10", 140, "cooldown_set", 1.00, "Cooldown 1.25 → 1.00 seconds"],
	["R12", "Luck V", "R11", 140, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R13", "BREAKTHROUGH II: Viral Cascade", "R12", 325, "checkpoint_luck", 20.0, "TOTAL luck ×20 again"],
	["R14", "Quick Hands VI", "R13", 175, "cooldown_set", 0.80, "Cooldown 1.00 → 0.80 seconds"],
	["R15", "Luck VI", "R14", 175, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R16", "Quick Hands VII", "R15", 225, "cooldown_set", 0.65, "Cooldown 0.80 → 0.65 seconds"],
	["R17", "Luck VII", "R16", 225, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R18", "BREAKTHROUGH III: Singularity RNG", "R17", 325, "checkpoint_luck", 20.0, "TOTAL luck ×20 again"],
]
const OPTIONAL := [
	["RO1", "Skip Common Reveal", "R04", 40, "skip_common", 1.0, "Threshold below 100: 0.20-second toast"],
	["RO2", "Auto-Sell Duplicates", "R08", 115, "auto_sell", 1.0, "Auto-sell duplicate Normal rolls · default threshold ≤100"],
	["RO3", "Filter I", "R08", 75, "filter_1", 1.0, "Auto-sell thresholds 20 / 100 / 1,000"],
	["RO4", "Filter II", "R13", 125, "filter_2", 1.0, "Use any discovered base slime's threshold"],
	["RO5", "Super Roll I", "R08", 165, "super_roll", 1.0, "Every 100 rolls: one Super Roll with ×5 luck"],
	["RO8", "Super Roll II", ["RO5", "R13"], 225, "super_roll", 2.0, "Every 75 rolls: one Super Roll with ×10 luck"],
	["RO9", "Super Roll III", ["RO8", "R18"], 375, "super_roll", 3.0, "Every 50 rolls: one Super Roll with ×20 luck"],
	["RO6", "Variant Sense", "R13", 175, "variant_sense", 1.0, "Variant chances ×1.25 · Shiny 1/80"],
	["RO7", "Quick Hands VIII", "R18", 350, "cooldown_set", 0.50, "Post-campaign cooldown 0.65 → 0.50 seconds"],
]
# Highest published prices before Prompt 16. Keep these when tuning current costs.
# Ancient canonical-ID saves without a ledger use the pre-Prompt-13 R02/R03 prices.
const HISTORICAL_PRICES := {
 "R01":25, "R02":75, "R03":75, "R04":125, "R05":175, "R06":275,
 "R07":350, "R08":900, "R09":350, "R10":400, "R11":550, "R12":550,
 "R13":1300, "R14":700, "R15":700, "R16":900, "R17":900, "R18":1300,
 "RO1":150, "RO2":450, "RO3":300, "RO4":500, "RO5":650, "RO6":700,
 "RO7":1400, "RO8":900, "RO9":1500,
}
const LEGACY_NODES := {
	"quick_hands_1": {"id": "R01", "paid": 10},
	"luck_1": {"id": "R02", "paid": 15},
	"auto_roll": {"id": "R03", "paid": 25},
}
const SUPER_ROLL_INTERVAL := 100
const SUPER_ROLL_MULTIPLIER := 5.0
const SUPER_ROLL_INTERVALS := [0, 100, 75, 50]
const SUPER_ROLL_MULTIPLIERS := [1.0, 5.0, 10.0, 20.0]
const DEFAULT_SELL_THRESHOLD := 100
const FILTER_I_THRESHOLDS := [20, 100, 1000]

static func row(id: String) -> Array:
	for entry in MAINLINE + OPTIONAL:
		if entry[0] == id: return entry
	return []
