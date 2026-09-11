# Slimerot

Offline Android · top-down 2D · Godot 4.5.1 / GDScript. Prompts 1–3 are implemented: the playable Bedroom/Backyard foundation, complete rolling math, 24 canonical base slimes, four variants, inventory/collection/team backends, and the complete Roll skill tree.

## Play and controls

Import `project.godot` and press F5. Touch: drag the 90 px joystick and tap ROLL with another finger. Desktop: WASD/arrows move, Space rolls, E interacts, Escape closes menus. Rolling remains in the world during movement, combat, and non-pausing menus. Settings pauses active gameplay.

New saves have zero currencies, 100 HP, 180 px/s movement, x1 luck, a 2.4-second cooldown, and one slot. The first base result is always Tung Tung Tung Sahur and auto-equips. Like every roll, its variant is drawn separately. Normal Tung Tung now has the canonical 7 damage and 5 base sell value.

Enter Backyard, approach Laglings within 180 px for automatic slime attacks, and earn five base Coins per kill. The Shrine costs 25 Coins; the Sell Terminal costs 75 Coins. These working stage-one systems are preserved. Death loses no currencies or copies.

## Exact rolling

A completed manual or automatic roll grants exactly +1 spendable **Rolls** and +1 **Lifetime Rolls**. Pressing ROLL is free. Only Roll-tree purchases spend Rolls; there are no other minting paths. Schema validation enforces lifetime = balance + recorded Rolls spent on purchased nodes.

The global pool contains all slimes with zone_unlock <= highest_zone_unlocked, regardless of current location. Effective Luck is the product of minor luck effects, x20 per Breakthrough, and the active potion multiplier. The score is L/U with U in (0,1], selecting the highest eligible threshold reached, otherwise Tung Tung.

`SlimerotRoster.gd` contains all 24 canonical IDs, names, zones, and thresholds. Damage = round(6 × N^0.32); base sell = max(1, round(4 × N^0.45)). Tests compare all values against the supplied table. Cards say **Rarity threshold: 1 in N**, not isolated probability.

A separate RNG stream draws one mutually exclusive variant: Golden 1/10,000, Glitched 1/1,000, Shiny 1/100, otherwise Normal. Variant Sense multiplies each rare-variant chance by exactly 1.25. Ordinary luck, potion luck, and Luck Cap never enter this variant draw. Damage multipliers are 1/1.5/2.5/4; sale multipliers are 1/2/5/10.

After R08, Roll Settings exposes MAX / x20-era / x1. MAX is the initial and first-Breakthrough default. Caps are absolute persistent/potion rolling-luck ceilings of none / 20 / 1. Super Roll applies its temporary x5 after the selected cap, so it remains exactly x5 in every mode. Combat and uncapped luck statistics are unchanged.

## Complete Roll progression

`SlimerotRollTree.gd` centralizes all 18 mandatory nodes R01–R18 and seven independent optional branches RO1–RO7, with exact costs, prerequisites, descriptions and effects. The Roll tree is available from Start; the repaired Shrine gates Coin upgrades. Optional purchases never become mainline prerequisites.

Mandatory spending blocks are 1,865 / 2,850 / 4,500 Rolls. Quick Hands sets cooldowns to 2.20 / 1.90 / 1.55 / 1.25 / 1.00 / 0.80 / 0.65 seconds. RO7 is the 1,400-Roll post-campaign 0.50-second upgrade. Derived minor multipliers and exactly x20 per Breakthrough yield x30.36 / x910.8 / x28,462.5 before potions. Nothing destructively multiplies saved luck.

R03 unlocks Auto Roll while walking/fighting. RO1 shortens only reveals below threshold 100. RO2 unlocks opt-in auto-sale of newly rolled Normal duplicates at threshold <=100; it does not require the manual Sell Terminal. Existing inventory is never swept. At least one copy per pair and every favorite/equipped copy are protected. RO3 adds 20/100/1,000 filters; RO4 permits any discovered base threshold. These branches are independent. Filters and enable state persist.

RO5 boosts every 100th Lifetime Roll by x5 once, including automatic completions. The HUD shows its countdown. Spending Rolls, skipping feedback and reloading do not reset cadence. RO6 gives the independent variant draw exact denominators 80 / 800 / 8,000. Breakthrough purchases show the old/new luck and x20 jump.

## Inventory, team, collection, and menus

Ownership uses unlimited quantities per slime + variant, stable copy IDs, per-copy favorites, and a group favorite toggle. Discovery is stored separately and survives all sales. Collection always has exactly 24 base cards; variants do not add entries. Best variant owned reflects current ownership.

Inventory sorts by DPS, rarity, or name. Its copy manager is paginated for performance without limiting ownership. Equipped/favorited copies cannot be sold. Sell Duplicates retains protected copies and at least one copy per pair; an individual unprotected copy can be sold after unequipping. Auto Equip Strongest selects highest actual variant-adjusted DPS, including multiple copies of one slime.

The five-slot Team view shows locked slots. Coin-tree slots use canonical costs of 350 / 3,500 / 25,000 / 250,000 and sequential prerequisites. Slots 3/4/5 also require Z2/Z4/Z6 boss flags. WorldManager uses stable `zone_2`, `zone_4`, `zone_6` defeat keys; no boss encounters are introduced here.

Normal-enemy rewards use Coin Scavenger. Duplicate sales use Duplicate Dealer independently. Boss reward bookkeeping is one-time and ignores Coin Scavenger. Final Coin amounts are rounded to the nearest integer after multipliers.

The HUD shows Coins, Rolls, effective Luck, equipment portraits and DPS. Lifetime Rolls appears only in Stats. Menus include Inventory, Team, Collection, Roll/Coin skill tabs, Roll Settings, Stats, and pausing Settings with save status and a cancellable three-second reset hold.

Reveals last 0.35s (0.20s with Skip Common), 0.65s, 1.10s, 1.70s, or 2.80s for a first jackpot / 1.00s for repeats. First base discoveries at threshold >=1,000,000 cannot be skipped or displaced by another roll; later results queue behind them. Committing inventory/currency is separate from feedback. Original procedural portraits support Shiny sparkles, Glitched chromatic jitter, and Golden aura. Rare reveals add pulse/particles, optional subtle shake, and a generated sound sting.

## Saves and extension points

Eight autoloads remain the architecture: GameState, SlimeDatabase, SkillTreeManager, InventoryManager, WorldManager, CombatManager, RollManager, SaveManager. Typed content contracts are in `SlimerotData.gd`; shared balance is in `SlimerotBalance.gd`.

Schema 3 saves under `user://Slimerot-save.json` preserve discovery history, favorite copy IDs, statistics, potion state, and a `roll_skill_spend` ledger. Schema 1/2 migrate automatically: provisional Quick Hands I, Luck I and Auto Roll become R01/R02/R03 while recording their historical 10/15/25 costs. Missing ancestors for previously unlocked standalone upgrades are granted with zero recorded spend. Neither wallet nor Lifetime Rolls changes, and existing Auto Roll stays unlocked. New purchases always pay canonical prices. Old auto-sale settings initialize OFF at threshold 100. Recoverable historical Coin spending is reconstructed for schema 1; absent historical luck/DPS records cannot be fully reconstructed. Invalid/future saves remain protected rather than silently overwritten.

Ten-second autosave, immediate progression/lifecycle saves, flushed temporary files, and backup recovery remain intact. Super completions and automatic sales also save immediately. Pause stops active play, roll cooldowns, combat, and potion duration. There is no offline progress.

## Stage boundary

All 24 roll entries and eight-zone eligibility work now. Physical zones remain Bedroom and Backyard; later zone construction and boss encounters belong to later prompts. The database does not require those scenes to exist.

Early Lagling HP/damage/speed/respawn remain provisional. Potion sources, Fast Travel, mutations, XP, manual weapons, online systems, monetization and prestige are not introduced. Hourly campaign wall pacing requires the later physical zones and bosses; exact Roll-tree values are preserved without claiming a three-hour campaign playtest.

## Run validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --slimerot-test
```

Tests use per-process saves under `.godot/`, never player saves. For rendered captures omit `--headless` and append `--slimerot-capture` after `--slimerot-test`. See `docs/Slimerot-Testing.md` for results and the manual checklist.

The 720×1280 portrait Android ARM64 preset disables Internet/network permissions. Export requires locally installed matching Godot templates, Android SDK/JDK and signing configuration. No credentials are committed. Physical Android and APK validation remain outstanding.
