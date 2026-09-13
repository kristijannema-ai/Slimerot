class_name SlimerotRollTree
extends RefCounted

# Slimerot's canonical mainline and independent convenience branches.
# ID, name, prerequisite, Rolls cost, effect, value, description.
const MAINLINE := [
	["R01", "Quick Hands I", "", 25, "cooldown_set", 2.20, "Cooldown 2.40 → 2.20 seconds"],
	["R02", "Luck I", "R01", 40, "luck_multiplier", 1.10, "Minor luck ×1.10"],
	["R03", "Auto Roll", "R02", 75, "auto_roll", 1.0, "Unlock Auto Roll while exploring and fighting"],
	["R04", "Quick Hands II", "R03", 125, "cooldown_set", 1.90, "Cooldown 2.20 → 1.90 seconds"],
	["R05", "Luck II", "R04", 175, "luck_multiplier", 1.15, "Minor luck ×1.15"],
	["R06", "Quick Hands III", "R05", 275, "cooldown_set", 1.55, "Cooldown 1.90 → 1.55 seconds"],
	["R07", "Luck III", "R06", 350, "luck_multiplier", 1.20, "Minor luck ×1.20"],
	["R08", "BREAKTHROUGH I: RNG Overdrive", "R07", 800, "checkpoint_luck", 20.0, "TOTAL luck ×20 · unlock Luck Cap"],
	["R09", "Quick Hands IV", "R08", 350, "cooldown_set", 1.25, "Cooldown 1.55 → 1.25 seconds"],
	["R10", "Luck IV", "R09", 400, "luck_multiplier", 1.20, "Minor luck ×1.20"],
	["R11", "Quick Hands V", "R10", 550, "cooldown_set", 1.00, "Cooldown 1.25 → 1.00 seconds"],
	["R12", "Luck V", "R11", 550, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R13", "BREAKTHROUGH II: Viral Cascade", "R12", 1000, "checkpoint_luck", 20.0, "TOTAL luck ×20 again"],
	["R14", "Quick Hands VI", "R13", 700, "cooldown_set", 0.80, "Cooldown 1.00 → 0.80 seconds"],
	["R15", "Luck VI", "R14", 700, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R16", "Quick Hands VII", "R15", 900, "cooldown_set", 0.65, "Cooldown 0.80 → 0.65 seconds"],
	["R17", "Luck VII", "R16", 900, "luck_multiplier", 1.25, "Minor luck ×1.25"],
	["R18", "BREAKTHROUGH III: Singularity RNG", "R17", 1300, "checkpoint_luck", 20.0, "TOTAL luck ×20 again"],
]
const OPTIONAL := [
	["RO1", "Skip Common Reveal", "R04", 150, "skip_common", 1.0, "Threshold below 100: 0.20-second toast"],
	["RO2", "Auto-Sell Duplicates", "R08", 450, "auto_sell", 1.0, "Auto-sell duplicate Normal rolls · default threshold ≤100"],
	["RO3", "Filter I", "R08", 300, "filter_1", 1.0, "Auto-sell thresholds 20 / 100 / 1,000"],
	["RO4", "Filter II", "R13", 500, "filter_2", 1.0, "Use any discovered base slime's threshold"],
	["RO5", "Super Roll", "R13", 650, "super_roll", 1.0, "Every 100th Lifetime Roll uses ×5 luck once"],
	["RO6", "Variant Sense", "R13", 700, "variant_sense", 1.0, "Variant chances ×1.25 · Shiny 1/80"],
	["RO7", "Quick Hands VIII", "R18", 1400, "cooldown_set", 0.50, "Post-campaign cooldown 0.65 → 0.50 seconds"],
]
const LEGACY_NODES := {
	"quick_hands_1": {"id": "R01", "paid": 10},
	"luck_1": {"id": "R02", "paid": 15},
	"auto_roll": {"id": "R03", "paid": 25},
}
const SUPER_ROLL_INTERVAL := 100
const SUPER_ROLL_MULTIPLIER := 5.0
const DEFAULT_SELL_THRESHOLD := 100
const FILTER_I_THRESHOLDS := [20, 100, 1000]

static func row(id: String) -> Array:
	for entry in MAINLINE + OPTIONAL:
		if entry[0] == id: return entry
	return []
