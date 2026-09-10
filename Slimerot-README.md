# Slimerot

Godot 4.x / GDScript. An offline, portrait Android game about exploring, rolling slimes, and automatic team combat. This repository implements **prompt 1: foundation and the canonical new-save loop**. Validated with Godot 4.5.1.

## Play

Import `project.godot` into Godot 4.5.1 and press F6 on `scenes/Slimerot.tscn`, or F5 to run the project. No external plugins, assets, service accounts, or network connection are needed.

- Mobile: drag the lower-left joystick; tap ROLL with another finger. Context actions appear above the controls.
- Desktop: WASD / arrow keys move, Space rolls, E interacts, Escape closes a menu. The joystick can also be dragged with the mouse.
- Start beside the Bedroom exit with 0 Coins, 0 Rolls, 0 Lifetime Rolls, 100 HP, x1 luck, one equipment slot, and a 2.4-second roll cooldown.
- First roll guarantees Tung Tung Tung Sahur, adds exactly one Rolls and one Lifetime Roll, and equips its copy. The reveal never takes over the world or pauses movement.
- Enter Backyard and approach Level 1 Laglings. The equipped slime attacks within 180 px every second. Kills grant five Coins directly; death returns to the current entrance without losing anything.
- Repair the Skill Tree Shrine for 25 Coins to access early Roll upgrades. Repair the Sell Terminal for 75 Coins to sell duplicates. Equipped/favorited copies are protected.

## Stage boundary and provisional values

The repository was empty at implementation time. No previous Godot code or balance tables were available. The supplied excerpt defines the full game's shape but names only the starter slime and does not provide the other 23 slime rows, boss attacks, variant math, or full skill tables.

Only Bedroom, Backyard, Tung Tung Tung Sahur, and Laglings are populated. Other rolls currently return starter duplicates. Italian Village is a clearly marked later-stage entrance; it cannot charge the player or load an unfinished zone. This stage does not claim to meet the full 3-hour progression or the 2–4 distinct slimes target. The required typed contracts exist for later content.

All balance numbers live in `scripts/data/SlimerotBalance.gd`. **Provisional** values: starter damage 10 / sell value 2; Lagling HP 30, damage 8, speed 55, respawn 5 seconds; Quick Hands I costs 10 Rolls / cooldown x0.9, Luck I costs 15 Rolls / luck x1.25, Auto Roll costs 25 Rolls. Exact requested starting stats, five-Coin rewards, structure costs, and future Backyard gate requirement are preserved. These provisional numbers are not a claim about the missing canonical tables.

No XP, manual weapons, online systems, monetization, prestige, bosses, mutations, potions, or later zones are implemented. Their required save/data fields are reserved without exposing unfinished purchase actions. Three variant IDs are reserved; rolls produce only normal copies until variant rules are supplied. All art is original code/SVG placeholder art; audio is intentionally silent.

## Architecture and saves

Eight autoloads separate state, content, derived stats, inventory, world progression, combat, rolling, and saving. `SlimerotData.gd` declares Resource contracts for SlimeData, EnemyData, BossData, SkillNodeData, ZoneData, and StructureData. The world reuses player, enemy, joystick, and proximity-interaction components.

`SkillTreeManager.derived_stats()` is the only stat calculation entry point. It derives base stats plus purchased effects, clamps equipment to 1–5, and supports exact x20 checkpoint effects without adding those later nodes. Save restore derives stats from purchased IDs rather than trusting cached stats. Inventory tracks stable copy IDs grouped by slime + variant with quantity and favorite protection.

The local save is `user://Slimerot-save.json`, schema 1. Saves include every field requested by prompt 1 plus current zone, next copy ID, and remaining roll cooldown. Autosave runs every ten active seconds, and immediately after purchases, first/rare rolls, team/favorite changes, selling, zone changes, pause/focus loss, and exit. Future boss/mutation systems can emit the same `GameState.critical_change` event when implemented.

Writes flush a temporary file before rotating the previous generation to `.bak` and replacing the main file. Load validates data before applying it; missing/corrupt main files recover from a valid temporary file or backup. Unrecoverable and future-version saves are preserved with saving disabled and an on-screen warning. Active play, potions, roll cooldown, and combat stop while the application is suspended. There is no offline progress.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --slimerot-test
```

The integration suite uses per-process test files under `.godot/`, never the player's save. It checks the new-save contract, actual physics movement/collision, rolling during movement, cooldown rejection, ownership/equipment, context transition, injected two-finger touch input, actual automatic combat, death, purchases, protected selling, JSON round trips, and corrupt-save recovery. A rendered run can capture screens with `-- --slimerot-test --slimerot-capture` (omit `--headless`).

See `docs/Slimerot-Testing.md` for validation results and the manual device checklist.

## Android

The viewport is 720×1280, portrait, using Godot's compatibility renderer. `export_presets.cfg` includes **Slimerot Android**, ARM64, package `com.slimerot.game`, with Internet and network-state permissions disabled. Install matching Godot export templates and configure the Android SDK, JDK, and signing credentials in your own Godot editor before exporting. No keystores or credentials belong in this repository. An APK and physical-device test are not part of this validation environment.
