# Slimerot

Offline Android · top-down 2D · Godot 4.5.1 / GDScript. Prompts 1 and 2 are implemented: the playable Bedroom/Backyard foundation, complete rolling math, 24 canonical base slimes, four variants, and inventory/collection/team backends.

## Play and controls

Import `project.godot` and press F5. Touch: drag the 90 px joystick and tap ROLL with another finger. Desktop: WASD/arrows move, Space rolls, E interacts, Escape closes menus. Rolling remains in the world during movement, combat, and non-pausing menus. Settings pauses active gameplay.

New saves have zero currencies, 100 HP, 180 px/s movement, x1 luck, a 2.4-second cooldown, and one slot. The first base result is always Tung Tung Tung Sahur and auto-equips. Like every roll, its variant is drawn separately. Normal Tung Tung now has the canonical 7 damage and 5 base sell value.

Enter Backyard, approach Laglings within 180 px for automatic slime attacks, and earn five base Coins per kill. The Shrine costs 25 Coins; the Sell Terminal costs 75 Coins. These working stage-one systems are preserved. Death loses no currencies or copies.

## Exact rolling

A completed manual or automatic roll grants exactly +1 spendable **Rolls** and +1 **Lifetime Rolls**. Pressing ROLL is free. Only Roll-tree purchases spend Rolls; there are no other minting paths. Schema validation enforces lifetime = balance + costs of purchased Roll nodes.

The global pool contains all slimes with zone_unlock <= highest_zone_unlocked, regardless of current location. Effective Luck is the product of minor luck effects, x20 per Breakthrough, and the active potion multiplier. The score is L/U with U in (0,1], selecting the highest eligible threshold reached, otherwise Tung Tung.

`SlimerotRoster.gd` contains all 24 canonical IDs, names, zones, and thresholds. Damage = round(6 × N^0.32); base sell = max(1, round(4 × N^0.45)). Tests compare all values against the supplied table. Cards say **Rarity threshold: 1 in N**, not isolated probability.

A separate RNG stream draws one mutually exclusive variant: Golden 1/10,000, Glitched 1/1,000, Shiny 1/100, otherwise Normal. Variant Sense multiplies each rare-variant chance by exactly 1.25. Ordinary luck, potion luck, and Luck Cap never enter this variant draw. Damage multipliers are 1/1.5/2.5/4; sale multipliers are 1/2/5/10.

After a purchased checkpoint effect, Roll Settings exposes MAX / x20-era / x1. MAX is the initial and first-Breakthrough default. Caps are absolute rolling-luck ceilings of none / 20 / 1; combat and uncapped luck statistics are unchanged.

## Inventory, team, collection, and menus

Ownership uses unlimited quantities per slime + variant, stable copy IDs, per-copy favorites, and a group favorite toggle. Discovery is stored separately and survives all sales. Collection always has exactly 24 base cards; variants do not add entries. Best variant owned reflects current ownership.

Inventory sorts by DPS, rarity, or name. Its copy manager is paginated for performance without limiting ownership. Equipped/favorited copies cannot be sold. Sell Duplicates retains protected copies and at least one copy per pair; an individual unprotected copy can be sold after unequipping. Auto Equip Strongest selects highest actual variant-adjusted DPS, including multiple copies of one slime.

The five-slot Team view shows locked slots. Coin-tree slots use canonical costs of 350 / 3,500 / 25,000 / 250,000 and sequential prerequisites. Slots 3/4/5 also require Z2/Z4/Z6 boss flags. WorldManager uses stable `zone_2`, `zone_4`, `zone_6` defeat keys; no boss encounters are introduced here.

Normal-enemy rewards use Coin Scavenger. Duplicate sales use Duplicate Dealer independently. Boss reward bookkeeping is one-time and ignores Coin Scavenger. Final Coin amounts are rounded to the nearest integer after multipliers.

The HUD shows Coins, Rolls, effective Luck, equipment portraits and DPS. Lifetime Rolls appears only in Stats. Menus include Inventory, Team, Collection, Roll/Coin skill tabs, Roll Settings, Stats, and pausing Settings with save status and a cancellable three-second reset hold.

Reveals last 0.35s (0.20s with Skip Common), 0.65s, 1.10s, 1.70s, or 2.80s for a first jackpot / 1.00s for repeats. First base discoveries at threshold >=1,000,000 cannot be skipped or displaced by another roll; later results queue behind them. Committing inventory/currency is separate from feedback. Original procedural portraits support Shiny sparkles, Glitched chromatic jitter, and Golden aura. Rare reveals add pulse/particles, optional subtle shake, and a generated sound sting.

## Saves and extension points

Eight autoloads remain the architecture: GameState, SlimeDatabase, SkillTreeManager, InventoryManager, WorldManager, CombatManager, RollManager, SaveManager. Typed content contracts are in `SlimerotData.gd`; shared balance is in `SlimerotBalance.gd`.

Schema 2 saves under `user://Slimerot-save.json` add discovery history, favorite copy IDs, statistics, and active potion multiplier. Schema 1 migrates automatically, preserving ownership, equipment, currencies, settings, and upgrades. Recoverable historical Coin spending is reconstructed from structures and purchased nodes; past luck/DPS records absent from schema 1 cannot be fully reconstructed. Invalid/future saves remain protected rather than silently overwritten.

Ten-second autosave, immediate progression/lifecycle saves, flushed temporary files, and backup recovery remain intact. Pause stops active play, roll cooldowns, combat, and potion duration. There is no offline progress.

## Stage boundary

All 24 roll entries and eight-zone eligibility work now. Physical zones remain Bedroom and Backyard; later zone construction and boss encounters belong to later prompts. The database does not require those scenes to exist.

Existing provisional early Roll prices/effects remain Quick Hands I 10 Rolls / cooldown x0.9, Luck I 15 Rolls / luck x1.25, Auto Roll 25 Rolls. Early Lagling HP/damage/speed/respawn remain provisional. The supplied prompt does not price Breakthrough, Variant Sense, Skip Common, potions, or auto-sell unlocks, so no new invented purchases or potion sources were added. Their specified stat/reveal hooks are implemented and tested through fixtures. Auto-sell, Super Roll, Fast Travel, mutations, XP, manual weapons, online systems, monetization and prestige are not introduced.

## Run validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --slimerot-test
```

Tests use per-process saves under `.godot/`, never player saves. For rendered captures omit `--headless` and append `--slimerot-capture` after `--slimerot-test`. See `docs/Slimerot-Testing.md` for results and the manual checklist.

The 720×1280 portrait Android ARM64 preset disables Internet/network permissions. Export requires locally installed matching Godot templates, Android SDK/JDK and signing configuration. No credentials are committed. Physical Android and APK validation remain outstanding.
