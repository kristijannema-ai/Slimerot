# Slimerot

Offline Android · top-down 2D · Godot 4.5.1 / GDScript. Prompts 1–7 are implemented: the Hub and eight physical campaign zones, complete rolling math, 24 canonical base slimes, four variants, team/inventory/collection, both complete skill trees, automatic projectile combat, and the Coin economy.

## Play and controls

Import `project.godot` and press F5. Touch: drag the 90 px joystick and tap ROLL with another finger. Desktop: WASD/arrows move, Space rolls, E interacts, Escape / Android Back returns from copy management to Inventory, closes an open menu, or opens Pause from gameplay. Rolling remains in the world during movement, combat, and non-pausing menus. Settings pauses active gameplay.

New saves have zero currencies, 100 HP, 180 px/s movement, x1 luck, a 2.4-second cooldown, and one slot. The first base result is always Tung Tung Tung Sahur and auto-equips. Like every roll, its variant is drawn separately. Normal Tung Tung now has the canonical 7 damage and 5 base sell value.

Enter Backyard, approach Laglings within 180 px for automatic slime attacks, and earn five base Coins per kill. The Bedroom Hub contains the 25-Coin Shrine and 75-Coin Sell Terminal; their old Backyard placements have moved without resetting unlock flags. Death loses no currencies or copies.

## Exact rolling

A completed manual or automatic roll grants exactly +1 spendable **Rolls** and +1 **Lifetime Rolls**. Pressing ROLL is free. Only Roll-tree purchases spend Rolls; there are no other minting paths. Schema validation enforces lifetime = balance + recorded Rolls spent on purchased nodes.

The global pool contains all slimes with zone_unlock <= highest_zone_unlocked, regardless of current location. Effective Luck is the product of minor luck effects, x20 per Breakthrough, and the active potion multiplier. The score is L/U with U in (0,1], selecting the highest eligible threshold reached, otherwise Tung Tung.

`SlimerotRoster.gd` contains all 24 canonical IDs, names, zones, and thresholds. Damage = round(6 × N^0.32); base sell = max(1, round(4 × N^0.45)). Tests compare all values against the supplied table. Cards say **Rarity threshold: 1 in N**, not isolated probability.

A separate RNG stream draws one mutually exclusive variant: Golden 1/10,000, Glitched 1/1,000, Shiny 1/100, otherwise Normal. Variant Sense multiplies each rare-variant chance by exactly 1.25. Ordinary luck, potion luck, and Luck Cap never enter this variant draw. Damage multipliers are 1/1.5/2.5/4; sale multipliers are 1/2/5/10.

After R08, Roll Settings exposes MAX / x20-era / x1. MAX is the initial and first-Breakthrough default. Caps are absolute persistent/potion rolling-luck ceilings of none / 20 / 1. Super Roll applies its temporary x5 after the selected cap, so it remains exactly x5 in every mode. Combat and uncapped luck statistics are unchanged.

## Complete Roll progression

`SlimerotRollTree.gd` centralizes all 18 mandatory nodes R01–R18 and seven independent optional branches RO1–RO7, with exact costs, prerequisites, descriptions and effects. R01 is the mainline starting node. Repairing the Bedroom Shrine adds the Skills HUD button and opens the Roll/Coin panels. Optional purchases never become mainline prerequisites.

Mandatory spending blocks are 1,865 / 2,850 / 4,500 Rolls. Quick Hands sets cooldowns to 2.20 / 1.90 / 1.55 / 1.25 / 1.00 / 0.80 / 0.65 seconds. RO7 is the 1,400-Roll post-campaign 0.50-second upgrade. Derived minor multipliers and exactly x20 per Breakthrough yield x30.36 / x910.8 / x28,462.5 before potions. Nothing destructively multiplies saved luck.

R03 unlocks Auto Roll while walking/fighting. RO1 shortens only reveals below threshold 100. RO2 unlocks opt-in auto-sale of newly rolled Normal duplicates at threshold <=100; it does not require the manual Sell Terminal. Existing inventory is never swept. At least one copy per pair and every favorite/equipped copy are protected. RO3 adds 20/100/1,000 filters; RO4 permits any discovered base threshold. These branches are independent. Filters and enable state persist.

RO5 boosts every 100th Lifetime Roll by x5 once, including automatic completions. The HUD shows its countdown. Spending Rolls, skipping feedback and reloading do not reset cadence. RO6 gives the independent variant draw exact denominators 80 / 800 / 8,000. Breakthrough purchases show the old/new luck and x20 jump.

## Inventory, team, collection, and menus

Ownership uses unlimited quantities per slime + variant, stable copy IDs, per-copy favorites, and a group favorite toggle. Discovery is stored separately and survives all sales. Collection always has exactly 24 base cards; variants do not add entries. Best variant owned reflects current ownership.

Inventory sorts by DPS, rarity, or name. Its copy manager is paginated for performance without limiting ownership. Equipped/favorited copies cannot be sold. Sell Duplicates retains protected copies and at least one copy per pair; an individual unprotected copy can be sold after unequipping. Auto Equip Strongest selects highest actual variant-adjusted DPS, including multiple copies of one slime.

The five-slot Team view shows locked slots and each copy's rounded damage per hit. Coin-tree slots cost 350 / 3,500 / 25,000 / 250,000, requiring C01 / C05 / C08 / C13 respectively. Slots 3/4/5 also require Z2/Z4/Z6 boss flags. The exact table does not require earlier slot nodes, so each upgrade sets the maximum slot count directly. WorldManager uses stable `zone_2`, `zone_4`, `zone_6` defeat keys; all four boss encounters are playable.

Normal-enemy rewards use Coin Scavenger. Duplicate sales use Duplicate Dealer independently. Boss reward bookkeeping is one-time and ignores Coin Scavenger. Final Coin amounts are rounded to the nearest integer after multipliers.

## Coin progression and combat

`SlimerotCoinTree.gd` centralizes C01–C19 and CO1–CO2 with exact costs, node/world/boss/structure prerequisites and descriptions. Coin upgrades retain the existing Shrine unlock. Slime Bonds add to +150% at Final Bond (2.5x); Boss Hunter separately adds to +50% (1.5x against bosses). Coin Scavenger totals +100% for normal kills, Duplicate Dealer +75% for sales, Toughness gives 250 max HP, and Fleet Feet gives 216 px/s. Purchases update Coins Spent and Team DPS immediately; all Coin income updates Coins Earned. Roll balances and Lifetime Rolls are untouched by Coin purchases.

Slimes orbit in slot order without terrain collision or HP. Each searches from its own position for the nearest hostile within 180 px and fires independently every 1.00s. Slime projectiles fly a straight 500 px/s segment locked at firing. On arrival they apply the committed hit to the original target even if it moved, disappearing if that target died first. Damage is rounded once after base × variant × additive team multiplier × boss multiplier. Raw Team DPS sums those rounded ordinary hits; Boss Hunter is conditional, so it does not inflate the HUD's raw DPS.

Enemy contact uses per-enemy timers and separation/collision avoidance. `fire_enemy_projectile` exposes straight, dodgeable shots with swept player/terrain collision; boss targets use the `slimerot_bosses` group in addition to `slimerot_enemies`. Normal Shooters and the four canonical bosses use these projectile hooks. No player manual attack exists.

After four damage-free active seconds, HP regenerates at 5% of max HP per second. Any positive damage restarts the delay. At zero HP, a 1.5-second fade blocks movement, rolling and interactions; respawn restores full HP at the current entrance without removing progression. Pause freezes combat, projectiles, regeneration and the fade. Zone changes clear in-flight shots and attack timers.

The HUD shows Coins, Rolls, effective Luck, equipment portraits and DPS. Lifetime Rolls appears only in Stats. Menus include Inventory, Team, Collection, Roll/Coin skill tabs, Roll Settings, Stats, and pausing Settings with save status and a cancellable three-second reset hold.

Reveals last 0.35s (0.20s with Skip Common), 0.65s, 1.10s, 1.70s, or 2.80s for a first jackpot / 1.00s for repeats. First base discoveries at threshold >=1,000,000 cannot be skipped or displaced by another roll. Every active tier completes its specified duration unless explicitly skipped; later feedback queues behind it. Pending repeats coalesce, and the queue is bounded to 32 entries without discarding first discoveries. Committing inventory/currency is separate from feedback. The 24 original transparent slime sprites support Shiny sparkles, Glitched chromatic jitter, and Golden aura, with safe procedural fallback if art is absent. Rare reveals add pulse/particles, optional subtle shake, and replaceable sound stings.

## Saves and extension points

Eight gameplay autoloads remain the architecture: GameState, SlimeDatabase, SkillTreeManager, InventoryManager, WorldManager, CombatManager, RollManager, SaveManager. The presentation-only `SlimerotSound` autoload supplies bounded audio playback. Typed content contracts are in `SlimerotData.gd`; shared balance is in `SlimerotBalance.gd`, and reveal/mobile tuning is in `SlimerotPresentation.gd`.

Schema 6 saves under `user://Slimerot-save.json` preserve discovery history, favorite copy IDs, statistics, potion state, and a `roll_skill_spend` ledger. Schema 1–5 migrate automatically: provisional Quick Hands I, Luck I and Auto Roll become R01/R02/R03 while recording their historical 10/15/25 costs. Missing ancestors for previously unlocked standalone upgrades are granted with zero recorded spend. Neither wallet nor Lifetime Rolls changes, and existing Auto Roll stays unlocked. Legacy team_slot_2/3/4/5 become C02/C06/C10/C15, granting required Bond ancestors without charging Coins or changing historical Coins Earned/Spent. Existing equipment capacity is preserved. New purchases always pay canonical prices. Pre-stage-3 auto-sale settings initialize OFF at threshold 100; schema 3 settings persist. Recoverable historical Coin spending is reconstructed for schema 1; absent historical luck/DPS records cannot be fully reconstructed. Invalid/future saves remain protected rather than silently overwritten.

Ten-second autosave, immediate progression/lifecycle saves, flushed temporary files, and backup recovery remain intact. Super completions and automatic sales also save immediately. Pause stops active play, roll cooldowns, combat, and potion duration. There is no offline progress.

## Stage boundary

All nine separately loaded locations now exist: Bedroom Hub → Backyard → Italian Village → Cursed Forest → Sahara → Brainrot City → Backrooms → Moon → Brainrot Dimension. Each campaign scene uses a portrait 20×30 grid of 50 px tiles (1000×1500), a main route, a connected farming loop, themed collision props, a safe entrance, return gate, and far-end progression point. Eleven enemies per zone reuse Chaser/Shooter/Tank behavior with theme palettes. Only the current scene stays active.

SlimerotCampaign.gd is the canonical source for all 24 fixed enemy HP/damage/reward combinations, zone level ranges, exact kill requirements and gate prices. No enemy scales with player stats. Chasers pursue; Shooters keep distance and fire dodgeable projectiles with their own timer and terrain line-of-sight; Tanks move slowly and hit harder. Grid routing handles props, enemies separate, and defeated spawns return after five seconds when the player is not standing on them. Behavior speeds and firing intervals are centralized tuning values because the specification does not fix them.

Gate interaction shows kills, Coins and boss requirements. A successful purchase saves a permanent unlocked_gate_flags entry, spends the exact price once, and immediately expands the global roll pool. Returning through a gate preserves unlocks and arrives near that zone's far exit. Death always returns to the current zone entrance. The save accepts all eight current-zone IDs, saves gates/kill counters, and preserves earlier global unlocks during migration.

Late-Z3/Z5/Z7 walls retain exactly 40/60/90 kills and 4,000/75,000/1,200,000 Coins, with farming hints for the corresponding Breakthrough. Gates never require a specific slime or a mandatory Breakthrough. Boss flags remain mandatory at Z2/Z4/Z6/Z8. Meeting the zone kill requirement opens the boss entrance. Defeating the boss grants its fixed first reward; the normal gate still charges its listed price. The Z8 victory unlocks the completion portal.

XP, manual weapons, online systems, monetization and prestige remain deferred. Exact balance numbers are preserved. Full hourly pacing, boss-clear timing and the >=3x Coins/minute progression target still require equipped-team campaign playtests; no three-hour playtest is claimed.

## Bosses, structures and completion

SlimerotEncounters.gd centralizes all boss profiles, structures and recipes. Espresso Golem has 3,000 HP, contact 16, a 3s chase then 0.8s warning/slam for 24, and rewards 1,000 Coins plus a Lucky Soda. Sand Router has 50,000 HP, contact 35, a telegraphed five-way 50-damage fan every 4s, and rewards 20,000 Coins plus Hyper Soda. Backrooms Janitor has 650,000 HP, contact 65, teleports among four points every 6s and fires two aimed three-shot 80-damage bursts; its reward is 350,000 Coins. Singularity Admin has 7,500,000 HP, contact 110, alternating fan/teleport shots for 140, and adds shrinking 170-damage warning circles at 40% HP; victory gives 6,000,000 Coins and the completion portal.

A closed collision arena suspends normal-zone enemies while the fight is active. Crossing the gold reset boundary returns to the entrance, clears projectiles, resets boss HP/patterns and leaves player HP and progression unchanged. Death uses the ordinary loss-free current-zone respawn. Fast Travel and world gates are blocked in combat. Boss rewards are one-time fixed payouts, never multiplied by Scavenger. Reloading does not resume a partly damaged boss. Entering the final portal saves campaign completion without adding repeated rewards or prestige.

The five permanent structures are Shrine (Hub, 25), Sell Terminal (Hub, 75), Potion Bench (Italian Village, 900), Fast Travel Pillar (Sahara, 15,000), and Mutation Lab (Backrooms, 250,000). Crafting and mutation require their actual zone and repaired structure. Fast Travel permits only Hub and unlocked zone entrances. Existing structure flags survive the location correction.

Crafting adds a bottle; drinking consumes it. Boss reward bottles may be drunk before repairing the Bench. Lucky Soda costs 300 for x2 Luck, Hyper Soda costs 8,000 after Z4 boss for x3 Luck, and Boss Brew costs 30,000 after Z6 boss for x1.25 boss damage. All last 300 active seconds. One luck channel keeps the stronger soda: weaker use is rejected without consuming a bottle; equal-strength use refreshes to 300s, and stronger use replaces the weaker effect. Brew has its own simultaneous timer and multiplies the existing Boss Hunter multiplier by 1.25 before final hit rounding. It never changes raw Team DPS. Pause/offline time consumes neither channel. Bottle counts and both effect timers persist in schema 6.

Mutation consumes exactly five eligible Normal copies of one base plus 20 times that base's sell value in Coins, then creates one Shiny. Group favorites, individual favorites, and equipped copies are protected; other variants cannot substitute. Checks occur before either fee or copies are consumed. Mutation saves immediately.

## Run validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --slimerot-test
```

Tests use per-process saves under `.godot/`, never player saves. For rendered captures omit `--headless` and append `--slimerot-capture` after `--slimerot-test`. See `docs/Slimerot-Testing.md` for results and the manual checklist.

The 720×1280 portrait Android ARM64 preset disables Internet/network permissions. Export requires locally installed matching Godot templates, Android SDK/JDK and signing configuration. No credentials are committed. Physical Android and APK validation remain outstanding.

## Prompt 7 mobile presentation

The HUD adapts to portrait aspect ratios and mobile safe areas: HP and location at top left; Coins, Rolls and Luck at top center; Pause and unlocked Fast Travel at top right; a 90 px joystick at bottom left; ROLL, Auto and the unlocked Super counter at bottom right; equipped portraits and Team DPS at bottom center. Only nearby world interactions show the compact INTERACT control.

Menus use touch-sized controls, scroll gestures that do not accidentally purchase or favorite items, live Stats/save/audio readouts, five visibly chained Team slots, and drawn prerequisite paths in both skill trees. Inventory actions retain scroll position. The three Breakthrough purchases each show their exact ×20 luck change in a 1.8-second celebration. Pause freezes gameplay while audio sliders remain previewable.

See [Prompt 7 implementation and validation](docs/Slimerot-Prompt-7.md), [asset replacement guide](docs/Slimerot-Assets.md), and [testing notes](docs/Slimerot-Testing.md). Art and music remain original, replaceable placeholders. Prompt 8 features are not implemented.
