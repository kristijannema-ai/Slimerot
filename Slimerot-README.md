# Slimerot

Offline Android · top-down 2D · Godot 4.5.1 / GDScript. Prompts 1–14 are integrated: the Hub and eight physical campaign zones, complete rolling math, 24 canonical base slimes, eight combinations of three independent variant flags, team/inventory/collection, both complete skill trees, automatic projectile combat, and the Coin economy. Prompt 9 adds developer playtest logging, reproducible pacing estimates, and targeted HP, gate-price and Breakthrough-price tuning. Prompt 10 fixes large-inventory stalls, loaded HUD portraits and an exported developer-class reference, and adds campaign, endurance and packaged-resource validation. See the [final integration audit](docs/Slimerot-Final-Audit.md) for results, architecture, export instructions and remaining real-device/human acceptance work.

Prompt 12 adds zone luck, combined effective rarity/damage, hidden pity, the Variant Shrine and an adaptive reveal queue while preserving Prompt 11 offline/save/input behavior. See the [Prompt 12 report](docs/Slimerot-Prompt-12.md) for that RNG baseline. Prompt 13 adds earlier Auto Roll, three Super Roll tiers, six Coin nodes and schema 11 save compatibility. The [Prompt 13 report](docs/Slimerot-Prompt-13.md) contains the exact node delta, luck components, schedule policy, provisional balance and validation.

Prompt 14 replaces the mobile interface with a compact HUD, Team/Collection/Items hub, consolidated Settings and a real pannable/pinch-zoom skill tree. Backend systems and schema 11 remain unchanged. See the [Prompt 14 report](docs/Slimerot-Prompt-14.md) for the screen map, generated icons, changed files and validation.

## Play and controls

Import `project.godot` and press F5. Touch: drag the 90 px joystick and tap ROLL with another finger. Desktop: WASD/arrows move, Space rolls, E interacts, Escape / Android Back returns from copy management to Team, closes an open menu, or opens Pause from gameplay. Rolling remains in the world during movement, combat, and non-pausing menus. Settings pauses active gameplay.

New saves have zero currencies, 100 HP, 180 px/s movement, x1 luck, a 2.4-second cooldown, and one slot. The first base result is always Tung Tung Tung Sahur and auto-equips. Like every roll, its variant is drawn separately. Normal Tung Tung now has the canonical 7 damage and 5 base sell value.

Enter Backyard, approach Laglings within 180 px for automatic slime attacks, and earn five base Coins per kill. The Bedroom Hub contains the 25-Coin Shrine and 75-Coin Sell Terminal; their old Backyard placements have moved without resetting unlock flags. Death loses no currencies or copies.

## Exact rolling

A completed manual, automatic or offline-simulated roll grants exactly +1 spendable **Rolls** and +1 **Lifetime Rolls**. Pressing ROLL is free. Only Roll-tree purchases spend Rolls; there are no other minting paths. Schema validation enforces lifetime = balance + recorded Rolls spent on purchased nodes.

All 24 bases are rollable from the start; zone metadata identifies origin only. `RollManager.get_effective_luck(context)` multiplies minor Roll-tree, Breakthrough and Coin luck, unlocked gameplay zones (Z1 ×1 through Z8 ×8, excluding Hub), potion and one-roll Super. The score is L/U with U in (0,1], selecting the highest threshold reached, otherwise Tung Tung. Zone luck is derived on every read and never compounded on load.

`SlimerotRoster.gd` contains all 24 canonical IDs, names, zones, and thresholds. Effective rarity multiplies base threshold N by 100/400/1,600 for each active Shiny/Glitched/Golden flag. Raw damage = round(6 × effective_rarity^0.32); base sell = max(1, round(4 × N^0.45)). Tests compare all values against the supplied table. Cards say **Rarity threshold: 1 in N**, not isolated probability.

A separate RNG stream makes three independent draws: Shiny 1/100, Glitched 1/400, Golden 1/1,600 before Shrine boosts. All eight masks can coexist in inventory. Variant Sense retains its ×1.25 effect on each flag. Ordinary/potion luck and Luck Cap do not enter variant odds. Combined sale multipliers provisionally multiply the existing 2/5/10 factors.

Hidden pity persists the historical best effective rarity and rolls since improvement. Exact current base × mask probability P_better determines expected rolls and a hard deadline ceil(3/P_better); valid stronger replacements ramp smoothly from zero at 1× expected to at most 25% before the guarantee. Pity is disabled when no stronger outcome exists and is never included in HUD Luck. Selling or sacrificing the former best does not erase it.

After R08, Roll Settings exposes MAX / x20-era / x1. MAX is the initial and first-Breakthrough default. Caps are absolute persistent/potion rolling-luck ceilings of none / 20 / 1. Super Roll applies its current tier’s temporary ×5 / ×10 / ×20 after the selected cap, preserving that exact multiplier in every mode. Combat and uncapped luck statistics are unchanged.

## Complete Roll progression

`SlimerotRollTree.gd` centralizes all 18 mandatory nodes R01–R18 and nine optional nodes RO1–RO9, with exact costs, prerequisites, descriptions and effects. R01 is the mainline starting node. Repairing the Bedroom Shrine adds the Skills HUD button and opens the Roll/Coin panels. Optional purchases never become mainline prerequisites.

Mandatory spending blocks are 1,965 / 3,150 / 4,500 Rolls. R08 costs 900 Rolls, R13 costs 1,300, and R18 costs 1,300. Quick Hands sets cooldowns to 2.20 / 1.90 / 1.55 / 1.25 / 1.00 / 0.80 / 0.65 seconds. RO7 is the 1,400-Roll post-campaign 0.50-second upgrade. Derived minor multipliers and exactly x20 per Breakthrough yield x30.36 / x910.8 / x28,462.5 before Fortune, zones or potions. The Breakthrough component alone is exactly ×20 / ×400 / ×8,000. Nothing destructively multiplies saved luck.

The mainline begins R01 (25 Rolls) → R03 Auto Roll (40) → R02 Luck I (75, ×1.10) → R04. Auto Roll therefore unlocks after only 65 total Rolls and works while walking/fighting. RO1 shortens small adaptive toasts to 0.20 seconds. RO2 unlocks opt-in auto-sale of newly rolled Normal duplicates at threshold <=100; it does not require the manual Sell Terminal. Existing inventory is never swept. At least one copy per pair and every favorite/equipped copy are protected. RO3 adds 20/100/1,000 filters; RO4 permits any discovered base threshold. These branches are independent. Filters and enable state persist.

RO5 Super Roll I requires R08 and costs 650 Rolls: every 100 rolls, ×5 luck. RO8 requires RO5 + R13 and costs 900: every 75, ×10. RO9 requires RO8 + R18 and costs 1,500: every 50, ×20. First unlock targets the next future 100th Lifetime Roll. Upgrades keep an earlier pending trigger and cap the remaining wait at the new interval; following triggers advance by that interval. The persisted countdown survives spending, skipping feedback, saves and offline catch-up. The HUD, Settings and reveals display the current tier. RO6 gives the independent variant draw base denominators 80 / 320 / 1,280 before Shrine boosts. Breakthrough purchases show the old/new luck and x20 jump.

## Team, collection, items, and menus

Ownership uses unlimited quantities per slime + variant, stable copy IDs, per-copy favorites, and a group favorite toggle. Discovery is stored separately and survives all sales. Collection always has exactly 24 base cards; variants do not add entries. Best variant owned reflects current ownership.

TEAM is the main slime hub: equipped slots, Team DPS, Equip Best and a list sorted by DPS, rarity or name. One card represents each unique slime/variant stack with an xN quantity, damage, variant flags and equip/favorite actions. Its optional copy manager is paginated for performance without limiting ownership. COLLECTION and ITEMS are tabs in the same hub; Items contains potions. Equipped/favorited copies cannot be sold. Sell Duplicates retains protected copies and at least one copy per pair; an individual unprotected copy can be sold after unequipping. Auto Equip Strongest selects highest actual variant-adjusted DPS, including multiple copies of one slime.

The five-slot Team view shows locked slots and each copy's rounded damage per hit. Coin-tree slots cost 350 / 3,500 / 25,000 / 250,000, requiring C01 / C05 / C08 / C13 respectively. Slots 3/4/5 also require Z2/Z4/Z6 boss flags. The exact table does not require earlier slot nodes, so each upgrade sets the maximum slot count directly. WorldManager uses stable `zone_2`, `zone_4`, `zone_6` defeat keys; all four boss encounters are playable.

Normal-enemy rewards use Coin Scavenger. Duplicate sales use Duplicate Dealer independently. Boss reward bookkeeping is one-time and ignores Coin Scavenger. Final Coin amounts are rounded to the nearest integer after multipliers.

## Coin progression and combat

`SlimerotCoinTree.gd` centralizes C01–C25 and CO1–CO2 with exact costs, node/world/boss/structure prerequisites and descriptions. Coin upgrades retain the existing Shrine unlock. C20/C21/C22 Fortune unlock at Z3/Z5/Z7 for 8,000/80,000/600,000 Coins and multiply luck by 1.15/1.20/1.25 (×1.725 together). Slime Bonds add to +200% with Final Bond and C23 (3x); Boss Hunter separately adds to +50% (1.5x against bosses). C24 raises Coin Scavenger to +200% for normal kills. Duplicate Dealer remains +75% for sales, Toughness gives 250 max HP, and C25 raises Fleet Feet to 243 px/s. The slot cap stays five. Purchases update Coins Spent and Team DPS immediately; all Coin income updates Coins Earned. Roll balances and Lifetime Rolls are untouched by Coin purchases.

Slimes orbit in slot order without terrain collision or HP. Each searches from its own position for the nearest hostile within 180 px and fires independently every 1.00s. Slime projectiles fly a straight 500 px/s segment locked at firing. On arrival they apply the committed hit to the original target even if it moved, disappearing if that target died first. Raw effective-rarity damage is rounded first, then each hit is rounded after team and applicable boss/Brew modifiers. Raw Team DPS sums those rounded ordinary hits; Boss Hunter is conditional, so it does not inflate the HUD's raw DPS.

Enemy contact uses per-enemy timers and separation/collision avoidance. `fire_enemy_projectile` exposes straight, dodgeable shots with swept player/terrain collision; boss targets use the `slimerot_bosses` group in addition to `slimerot_enemies`. Normal Shooters and the four canonical bosses use these projectile hooks. No player manual attack exists.

After four damage-free active seconds, HP regenerates at 5% of max HP per second. Any positive damage restarts the delay. At zero HP, a 1.5-second fade blocks movement, rolling and interactions; respawn restores full HP at the current entrance without removing progression. Pause freezes combat, projectiles, regeneration and the fade. Zone changes clear in-flight shots and attack timers.

The HUD top shows HP, zone, Coins, Rolls, effective Luck and Settings. The utility row contains TEAM, Shrine-gated SKILL TREE and repaired-Pillar-gated MAP. Joystick and ROLL/Auto occupy opposite bottom corners. Lifetime Rolls appears in Stats/About under Settings; Team DPS and equipment are in Team. Settings consolidates GENERAL, ROLLING and SAVE / SYSTEM, retaining the cancellable three-second reset hold.

Adaptive reveals use surprise (effective rarity / committed rolling luck), team relevance, discoveries, variant flags and historical power improvement. Tier durations are provisionally 0.50 / 1.40 / 3 / 4 / 5 seconds, with at least five seconds after a major sequence before another major starts. Upgrade and ≥85%-of-weakest results get meaningful feedback. First base-discovery jackpots cannot be skipped. A bounded presentation queue coalesces repeats independently of roll commits; it never grants rewards. Shiny sparkle/outline, Glitched chromatic jitter and Golden rays/aura combine. Major cards add darkness, optional controlled camera shake and dimmed HUD while movement, combat and Auto Roll continue. Offline catch-up reports its strongest combined drop without per-roll cinematics.

## Saves and extension points

Eight gameplay autoloads remain the architecture: GameState, SlimeDatabase, SkillTreeManager, InventoryManager, WorldManager, CombatManager, RollManager, SaveManager. The presentation-only `SlimerotSound` autoload supplies bounded audio playback. Typed content contracts are in `SlimerotData.gd`; shared balance is in `SlimerotBalance.gd`, and reveal/mobile tuning is in `SlimerotPresentation.gd`.

Schema 11 saves under `user://Slimerot-save.json` preserve discovery history, favorite copy IDs, statistics, potion state, and a `roll_skill_spend` ledger. Schemas 1–10 migrate automatically, preserving the historical R02/R03 purchase order without refunds and adding a persisted next Super trigger. Unknown purchased IDs remain inert with valid historical spending preserved. Migrations include legacy single variants to flags 0/1/2/4 and empty Shrine/pity history defaults: provisional Quick Hands I, Luck I and Auto Roll become R01/R02/R03 while recording their historical 10/15/25 costs. Missing ancestors for previously unlocked standalone upgrades are granted with zero recorded spend. Neither wallet nor Lifetime Rolls changes, and existing Auto Roll stays unlocked. Legacy team_slot_2/3/4/5 become C02/C06/C10/C15, granting required Bond ancestors without charging Coins or changing historical Coins Earned/Spent. Existing equipment capacity is preserved. New purchases always pay canonical prices. Pre-stage-3 auto-sale settings initialize OFF at threshold 100; schema 3 settings persist. Recoverable historical Coin spending is reconstructed for schema 1; absent historical luck/DPS records cannot be fully reconstructed. Invalid/future saves remain protected rather than silently overwritten.

Prompt 8 adds checksummed generations, validated temporary-file replacement, newest-generation recovery, protected legacy migration, and a durable reset marker. Ten-second autosave and immediate progression/lifecycle saves remain intact. Potion multipliers derive from recipe identity, and independent pause/focus latches prevent early resume. See [Slimerot save architecture](docs/Slimerot-Saves.md) and [Android readiness](docs/Slimerot-Android.md). Super completions and automatic sales also save immediately. Pause stops active play, roll cooldowns, combat, and potion duration. Prompt 11 adds data-only offline Auto Roll catch-up at the saved cooldown when Auto Roll is enabled. Rewards and the consumed timestamp commit together before play resumes. Fractional cycles persist, potions and active playtime remain frozen, and no combat farming occurs offline. See the [stability report](docs/Slimerot-Prompt-11.md) for schema 9, compact inventory identities, input fixes and Android force-close checks.

Prompt 9 retains schema 8. Existing saves keep historical Roll prices in their spend ledger, retain unlocked gates, and receive no retroactive charge or refund. A read-only save-load notification lets the developer logger distinguish restored state from newly earned milestones.

## Stage boundary

All nine separately loaded locations now exist: Bedroom Hub → Backyard → Italian Village → Cursed Forest → Sahara → Brainrot City → Backrooms → Moon → Brainrot Dimension. Each campaign scene uses a portrait 20×30 grid of 50 px tiles (1000×1500), a main route, a connected farming loop, themed collision props, a safe entrance, return gate, and far-end progression point. Eleven enemies per zone reuse Chaser/Shooter/Tank behavior with theme palettes. Only the current scene stays active.

SlimerotCampaign.gd is the canonical source for all 24 fixed enemy HP/damage/reward combinations, zone level ranges, exact kill requirements and gate prices. No enemy scales with player stats. Chasers pursue; Shooters keep distance and fire dodgeable projectiles with their own timer and terrain line-of-sight; Tanks move slowly and hit harder. Grid routing handles props, enemies separate, and defeated spawns return after five seconds when the player is not standing on them. Behavior speeds and firing intervals are centralized tuning values because the specification does not fix them.

Gate interaction shows kills, Coins and boss requirements. A successful purchase saves a permanent unlocked_gate_flags entry, spends the exact price once, and immediately raises the global zone-luck component. All bases remain rollable in every zone. Returning through a gate preserves unlocks and arrives near that zone's far exit. Death always returns to the current zone entrance. The save accepts all eight current-zone IDs, saves gates/kill counters, and preserves earlier global unlocks during migration.

Gate prices from Z1 through Z8 are 1,000 / 4,000 / 30,000 / 18,000 / 200,000 / 1,000,000 / 5,000,000 / 0 Coins. Late-Z3/Z5/Z7 walls retain exactly 40/60/90 kills, with farming hints for the corresponding Breakthrough. Gates never require a specific slime or a mandatory Breakthrough. Boss flags remain mandatory at Z2/Z4/Z6/Z8. Meeting the zone kill requirement opens the boss entrance. Defeating the boss grants its fixed first reward; the normal gate still charges its listed price. The Z8 victory unlocks the completion portal.

Prompt 9 reduces Chaser/Shooter/Tank HP to 15,000/24,000/45,000 in Z6, 35,000/55,000/105,000 in Z7, and 65,000/104,000/195,000 in Z8. Normal-enemy damage and Coin rewards, Coin-node prices, rarity thresholds and the three x20 effects remain unchanged. Prompt 10 retains those values and the first-build scope; XP, manual weapons, online systems, monetization and prestige remain deferred.

The historical Prompt 9 12-seed continuous-Auto-Roll estimate reaches the final boss at a median 210.57 active minutes (207.40–213.87 range). This is a model with explicit combat/travel assumptions, not a completed human playthrough. Same-team farming gains between adjacent zones remain below the requested >=3x target; buying every pre-completion optional Roll branch also pushes the modeled completion later. See [Prompt 9 changes, measured results and remaining targets](docs/Slimerot-Prompt-9.md).

## Bosses, structures and completion

SlimerotEncounters.gd centralizes all boss profiles, structures and recipes. Espresso Golem has 3,000 HP, contact 16, a 3s chase then 0.8s warning/slam for 24, and rewards 1,000 Coins plus a Lucky Soda. Sand Router has 50,000 HP, contact 35, a telegraphed five-way 50-damage fan every 4s, and rewards 20,000 Coins plus Hyper Soda. Backrooms Janitor has 260,000 HP, contact 65, teleports among four points every 6s and fires two aimed three-shot 80-damage bursts; its reward is 350,000 Coins. Singularity Admin has 2,000,000 HP, contact 110, alternating fan/teleport shots for 140, and adds shrinking 170-damage warning circles at 40% HP; victory gives 6,000,000 Coins and the completion portal.

A closed collision arena suspends normal-zone enemies while the fight is active. Crossing the gold reset boundary returns to the entrance, clears projectiles, resets boss HP/patterns and leaves player HP and progression unchanged. Death uses the ordinary loss-free current-zone respawn. Fast Travel and world gates are blocked in combat. Boss rewards are one-time fixed payouts, never multiplied by Scavenger. Reloading does not resume a partly damaged boss. Entering the final portal saves campaign completion without adding repeated rewards or prestige.

The five permanent structures are Shrine (Hub, 25), Sell Terminal (Hub, 75), Potion Bench (Italian Village, 900), Fast Travel Pillar (Sahara, 15,000), and Variant Shrine (Backrooms, 250,000; persistent ID `mutation_lab`). Crafting and sacrifices require their actual zone and repaired structure. Fast Travel permits only Hub and unlocked zone entrances. Existing structure flags survive the location correction.

Crafting adds a bottle; drinking consumes it. Boss reward bottles may be drunk before repairing the Bench. Lucky Soda costs 300 for x2 Luck, Hyper Soda costs 8,000 after Z4 boss for x3 Luck, and Boss Brew costs 30,000 after Z6 boss for x1.25 boss damage. All last 300 active seconds. One luck channel keeps the stronger soda: weaker use is rejected without consuming a bottle; equal-strength use refreshes to 300s, and stronger use replaces the weaker effect. Brew has its own simultaneous timer and multiplies the existing Boss Hunter multiplier by 1.25 before final hit rounding. It never changes raw Team DPS. Pause/offline time consumes neither channel. Bottle counts and both effect timers persist in schema 6.

The old five-Normals-plus-Coins mutation recipe is disabled. The Variant Shrine consumes one unprotected copy toward ONE active flag selected by the player. Each category records unique base IDs; its probability multiplier is 1.05^count. Duplicate base/category offerings are rejected without consuming a copy. Equipped and favorite copies are protected, no Coins are charged, and sacrifice saves immediately.

## Run validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --slimerot-test
```

Tests use per-process saves under `.godot/`, never player saves. For rendered captures omit `--headless` and append `--slimerot-capture` after `--slimerot-test`. See `docs/Slimerot-Testing.md` for results and the manual checklist.

The 720×1280 portrait Android ARM64 preset disables Internet/network permissions. Export requires locally installed matching Godot templates, Android SDK/JDK and signing configuration. No credentials are committed. Physical Android and APK validation remain outstanding.

## Prompt 9 developer playtesting

Launch a debug/editor build with the explicit opt-in flag:

```sh
godot --path . -- --slimerot-playtest
```

The overlay shows active play time, Lifetime and spendable Rolls, Coins, Team DPS, slots, Effective Luck, strongest owned/equipped copies, and observed boss timing. F8 or **Hide log** toggles details; F9 or **Export log** writes comparable JSON and text. Output defaults to `user://Slimerot-playtests`; append `--slimerot-playtest-output=<absolute directory>` to choose a directory outside the repository. Timestamped milestones and 30-active-second samples include a source fingerprint and distinguish save-load boundaries. The bounded observer does not alter progression, saves, or rolling RNG. Ordinary launches do not create it; `dev/*` and `tools/*` are excluded from Android exports.

Run the separate estimator against the current source tables:

```sh
godot --headless --path . --script res://tools/SlimerotPacingEstimator.gd -- --slimerot-estimate --slimerot-estimate-seeds=12 --slimerot-estimate-output=<absolute filename stem>
```

The required estimator flag disables save loading/writing before estimation. Reports contain raw seeded runs and clearly label continuous rolling, 90% rolling sensitivity, and optional-purchase policies. The estimator does not simulate player dodging, deaths, or full world physics; use the logger for a real uninterrupted campaign playtest. Full instructions, every tuned value and remaining acceptance gaps are in [the Prompt 9 report](docs/Slimerot-Prompt-9.md).

## Mobile presentation

The Prompt 14 HUD adapts to portrait aspect ratios and mobile safe areas. Nearby world interactions show one contextual INTERACT control. The shared `assets/ui/SlimerotTheme.tres` supplies rounded purple/lime/gold styles, consistent typography, large touch controls, currency chips, cards and distinct skill states. Original local SVGs supply the nine UI icons without changing slime artwork.

Each root screen has one Close control and each child modal one Back control. Android Back removes only the top layer. Team lists retain scroll position; the 2D Skill Tree retains pan/zoom while details are open. Drag pans, pinch zooms between 0.55 and 1.8, and minus/plus/Fit provide fallbacks. Prerequisite lines expose the trunk, optional/Super branches and Coin paths. Purchases and previews call the existing backend managers. The three Breakthrough purchases retain their exact ×20 celebration. Settings pauses gameplay while audio sliders remain previewable.

See [Prompt 7 implementation and validation](docs/Slimerot-Prompt-7.md), [asset replacement guide](docs/Slimerot-Assets.md), and [testing notes](docs/Slimerot-Testing.md). Art and music remain original, replaceable placeholders. Prompt 8 save hardening and Prompt 9 integration are described above.
