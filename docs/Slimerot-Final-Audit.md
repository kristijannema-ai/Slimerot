# Slimerot v0.3 final integration audit

> **Historical record — Prompt 16:** Historical Prompt 10 audit, not the current acceptance report. Its four-exclusive-variant model, five-Normals mutation recipe, 46-node tree, separate Inventory/Potions/Roll Settings navigation, schema 8 and old balance targets are superseded by Prompts 11–16. Current variants are three independent flags/eight masks; the Variant Shrine consumes one protected-checked copy for one chosen category; the tree has 54 nodes; Team and Settings own the consolidated screens; saves use schema 11 with additive Dash. Historical measurements below are retained as evidence only.

This pass continues merged Prompt 9 from `main` at `f49c8cd` on `slimerot/stage-10-final`. The existing campaign and Prompt 9 tuning remain the baseline. The Android application version is now `0.3.0`, code `10`; the save schema remains `8`. No new progression system or content tier is introduced.

## Current game loop

Start beside the Bedroom exit, move with the joystick or WASD/arrows, and press ROLL for the guaranteed first Tung Tung Tung Sahur. Every completed roll grants one Rolls and one Lifetime Roll. Enter Backyard, let equipped slimes automatically attack, spend Coins on team/combat upgrades and structures, and spend Rolls on the separate Roll tree. Explore physical gates through eight zones while rolling. Three exactly x20 Breakthroughs expand obtainable power. Defeat the four bosses, enter the final completion portal, and keep exploring, rolling, fighting and using unlocked systems afterward. Death returns to the current entrance without losing progression.

## Content and integration audit

| First-build requirement | Repository evidence and integration |
| --- | --- |
| One Hub plus eight zones | Nine `scenes/zones/Slimerot*.tscn` scenes map to IDs 0–8 in `SlimerotCampaign`; `SlimerotWorld` loads only the current scene. |
| Exactly 24 base slimes | `SlimerotRoster.ROWS` supplies 24 base identities; Collection iterates the database independently of ownership. |
| Only four variants | `SlimerotBalance.VARIANTS` contains Normal, Shiny, Glitched and Golden; quantities and physical copy protection retain the variant. |
| Manual and Auto Roll | `RollManager` commits currency, inventory and independent variant draws while the world remains active; UI reveal state is separate. |
| Coins, Rolls, Lifetime Rolls | `GameState` owns balances and accounting; save validation checks the historical Roll-spend ledger. No other currency exists. |
| Complete skill trees | `SlimerotRollTree` contains R01–R18 and RO1–RO7; `SlimerotCoinTree` contains C01–C19 and CO1–CO2. Optional Roll branches do not gate the mainline. |
| Three exactly x20 Breakthroughs | `SkillTreeManager` derives luck from purchased node IDs and potion identity; save/load cannot add another purchase multiplier. |
| One to five team slots | Owned physical copy IDs fill the derived capacity; five is the hard maximum and slot upgrades check their boss prerequisites. |
| Automatic combat | `CombatManager` independently targets for each equipped slime, fires 500 px/s projectiles, applies rounded hit damage and drives regeneration/death. The player has no attack command. |
| Three normal archetypes | Chaser, Shooter and Tank reuse `SlimerotEnemy` with 24 fixed zone/archetype profiles; player power does not scale enemies. |
| Four bosses | Espresso Golem, Sand Router, Backrooms Janitor and Singularity Admin use selected-zone entrances, arena resets, telegraphs and one-time reward flags. |
| Five structures | Shrine: Hub/25 Coins; Sell Terminal: Hub/75; Potion Bench: Z2/900; Fast Travel Pillar: Z4/15,000; Mutation Lab: Z6/250,000. |
| Potions | Lucky Soda: 300 Coins/x2 luck; Hyper Soda: 8,000/x3 luck after Z4 boss; Boss Brew: 30,000/x1.25 boss damage after Z6 boss. Effects last 300 active seconds; the stronger soda wins and Brew has its own channel. |
| Fast Travel | The repaired Pillar permits Hub and unlocked zone entrances; arena combat blocks travel. |
| Mutation | Five unprotected Normal copies of one base plus 20 times its base sell value produce one Shiny; favorites and equipment are excluded before charging. |
| Required menus | Inventory/copy management/sales, Team, Collection, Roll/Coin skill tabs, Roll Settings, Stats, Pause/Settings, Potions, Map, Mutation and Completion have live UI actions. |
| Luck Cap and sale filters | Unlock checks guard MAX/x20-era/x1 and the corresponding filter choices; the selected values persist and do not change combat damage. |
| Local persistence | One logical save uses validated, checksummed generations with temporary replacement, backup recovery and a durable reset marker. Consequential events and lifecycle notifications save immediately. |
| Final portal and free roam | Final boss and portal flags persist independently; first rewards cannot repeat, and completion leaves the world playable. |
| Offline operation | Runtime scenes, scripts, audio and art are bundled locally. Source scanning found no runtime network clients, remote URLs, accounts or asset-download path; Internet and network-state permissions are disabled. |
| Naming and scope | Project/package title, source filenames, save/debug labels and new documentation use Slimerot. Brainrot City, Brainrot Dimension and Brainrot Singularity remain intentional content names. |

All literal production resource references in scripts/scenes were checked against disk. The audit found no missing `.gd`, `.tscn`, `.svg` or `.wav` path. Dynamically selected art is also covered by the existing presentation tests. Typed content contracts remain in `SlimerotData.gd`; the final pass does not replace the working managers with new architecture.

## Blockers fixed and final validation

Large inventories exposed repeated full-array scans. With 5,000 favorited copies, Auto Equip previously stalled for 4,859.726 ms; three synchronous saves took 400.976/652.830/751.387 ms. Auto Equip now keeps at most five strongest candidates with the same earliest-copy tie rule. Sales and mutation use per-pair protection lookups, and save validation uses hashed copy membership and reuses already parsed candidates. The final headless run measured Auto Equip at 9.155 ms, saves at 100.049/146.057/136.282 ms, load at 68.560 ms and a 4,998-copy duplicate sale at 5.174 ms. Timings vary with host load; saves remain synchronous and device hitch testing is still required. Checksums, validation, backups, currency accounting and copy protections are preserved.

Loading a different slime/variant under the same physical copy ID now refreshes the HUD portrait: its cache signature includes the content identity. The Android pack audit also exposed a global class-cache entry pointing at the excluded developer pacing tool. That class now uses explicit preloads only, removing the invalid packed reference without changing the model. Android vibration permission and release version metadata complete the repository configuration fixes.

| Validation performed on the final source | Result and limit |
| --- | --- |
| Godot editor import and actual rendered/headless project runs | No Slimerot parser/runtime errors in final runs. Host certificate-store and missing Android build-tools warnings are environmental. |
| Combined automated suite, headless and OpenGL rendered | **1,383 checks, zero failures in each run**; includes all 1,165 merged Prompt 9 checks. |
| Continuous accelerated campaign | Real context gates, enemies/boss nodes and manager signals exercise all nine locations, five structures, 46 skill nodes, potions, mutation, final rewards, save/load and completed free roam. The fixture supplies currency and resolves combat directly; it is not a human-paced campaign. |
| Fresh/existing/reset saves and acceptance assertions | First roll and movement, 100-roll accounting, 40-Roll spending, repeated B1 load, physical team restoration, death, collection, gates, bosses, timers, settings and final portal pass. Earlier Prompt 7 touch/Back/menu assertions remain passing. |
| Large-inventory regression | 5,000 favorites round-trip; strongest-copy tie order, reused-ID HUD refresh, exact bulk sale/protected survivors and repeat-sale rejection pass. |
| Bounded endurance | 1,800 projectile lifetimes, 45 zone loads, 20 arena resets, 3,600 Auto Rolls, 84 menu cycles and 1,000 audio switches pass cleanup/resource bounds. Auto Roll represents 30 accelerated minutes, not 30 wall-clock minutes or a device soak. |
| Actual process kill and reopen | **11 checks, zero failures** in a new Godot process after force-terminating the writer following its durable save. Android process/lifecycle behavior still needs device testing. |
| Exported PCK audit | **148 checks, zero failures**; all runtime resources and 80 art SVGs plus icon/10 WAVs load with source fallback unavailable; developer/test/tool files are excluded. Packed main scene also runs for 120 frames. This is a PCK validation, not an APK export. |
| Project/export configuration | Seven assertions pass for name, portrait resolution/stretch, offline permissions, vibration, version and exclusions. Source audits find no gameplay network APIs or stale app name. |
| Pacing estimator | Twelve seeds reproduce the merged Prompt 9 data fingerprint `333ba5f44403db07bbc1374f2d1462b556852220aefb8be1d9ec8943eb0f451d` and its reported milestone estimates. No balance values changed. |
| Manual visual review | Rendered 720×1280 HUD, Settings and final-boss telegraph captures inspected. These are fixture captures, not manual touch play or a manually defeated boss. |

Pack SHA-256: `b513d55be691f03ad441e1a29e3cf8826b760d4af8e944b44fba29429d00e56d`. Generated captures/logs/packs are local validation outputs, not tracked assets. See [test reproduction and detailed coverage](Slimerot-Testing.md).

## Files changed

Created `tests/SlimerotFinalIntegrationTests.gd`, `tests/SlimerotEnduranceTests.gd`, `tests/SlimerotSavePerformanceTests.gd`, `tools/SlimerotExportAudit.gd` and their Godot `.uid` files, plus this report.

Modified `scripts/managers/SlimerotInventoryManager.gd`, `scripts/managers/SlimerotSaveManager.gd`, `scripts/ui/SlimerotHUD.gd`, `tools/SlimerotPacingModel.gd`, `tests/SlimerotBalanceTests.gd`, `tests/SlimerotTests.gd`, `export_presets.cfg`, `Slimerot-README.md`, `docs/Slimerot-Testing.md` and `docs/Slimerot-Android.md`. No roster, skill-tree, campaign-balance or saved-schema data changed.

## Architecture

| Component | Responsibility |
| --- | --- |
| `scripts/data/` | Central balance, roster, both skill trees, fixed campaign data, encounters/recipes, presentation constants and save codec. |
| `GameState` | Authoritative currencies, progression, active-time potion clocks, settings and pause state. |
| `SlimeDatabase` | Static 24-entry content lookup and display formatting. |
| `RollManager` | Cooldown, manual/automatic completion, score/variant RNG, currency grant and reveal events. |
| `InventoryManager` | Quantities, stable copies, favorites, equipment, sales, mutation and truthful derived team damage. |
| `SkillTreeManager` | Purchases/prerequisites and derived luck, cooldown, HP, speed, team capacity and bonuses. |
| `WorldManager` | Gates, kill counters, structures, encounters, potions, travel and completion flags. |
| `CombatManager` | Targets/projectiles, enemy reward sources, player damage, regeneration and respawn. |
| `SaveManager` | Schema 8 validation/migration, recovery, atomic replacement, autosave, lifecycle and reset protection. |
| `scripts/world/` and `scenes/` | Player, separately loaded zones, collision/navigation, encounters and context interactions. |
| `scripts/ui/` and `scripts/presentation/` | Safe-area HUD, touch routing, menus, reveal effects, cached optional assets and bounded audio playback. |
| `dev/`, `tools/`, `tests/` | Explicit developer observers, standalone estimator/asset generator and isolated validation. These are excluded from Android export. |

## Run and validate

Use Godot **4.5.1 stable** with matching export templates. Import `project.godot`, then press F5. The project has no package-manager install or runtime download step. Equivalent commands from this directory are:

```sh
godot --headless --path . --editor --import --quit
godot --path .
godot --headless --path . -- --slimerot-test
godot --path . -- --slimerot-test --slimerot-capture
```

Use the actual executable path if `godot` is not on PATH. Tests use isolated saves under `.godot`, not the player's `user://` save. Generated logs, captures, PCK/APK artifacts and estimates belong outside tracked source or under ignored build/cache directories. The separate forced-termination probe is documented in [Slimerot persistence](Slimerot-Saves.md). Final execution results are recorded in [Slimerot testing](Slimerot-Testing.md).

Desktop controls are WASD/arrows, Space for ROLL, E for INTERACT and Escape for Back. On a phone, hold the joystick and press ROLL with another finger. Ordinary menus retain live gameplay; Settings explicitly pauses it. Android Back navigates out of copy management or an open menu, and opens Pause from gameplay.

## Android export

Install matching Godot 4.5.1 export templates, OpenJDK 17 and the Android SDK packages specified by the [Godot 4.5 Android export instructions](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html). Configure Java SDK Path and Android SDK Path in local Editor Settings. Configure the intended signing identity outside tracked source; release keystore paths, aliases and passwords can use Godot's `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables. No credentials are supplied by this repository.

The **Slimerot Android** preset targets ARM64, GL Compatibility, portrait 720×1280 with expanding canvas/safe-area UI, package `com.slimerot.game`, version `0.3.0`/`10`, and `build/Slimerot.apk`. Internet/network-state permissions and platform save backup remain disabled. `permissions/vibrate=true` fixes the existing haptic setting: [Godot requires VIBRATE for Android handheld vibration](https://docs.godotengine.org/en/4.5/classes/class_input.html#class-input-method-vibrate-handheld). This permission adds no network dependency.

After configuring the local SDK and signing identity:

```sh
godot --headless --path . --export-release "Slimerot Android" build/Slimerot.apk
```

Inspect the exported manifest for package/version, portrait orientation and disabled Internet/network-state permissions. Install on an ARM64 device using the same signing identity when preserving a previous installation's save. Keep SDK paths, signing material and generated artifacts local. APK installation, cutout behavior, real multi-touch/haptics, Android OS lifecycle and thermal performance still need device verification; a PCK or desktop run cannot establish those properties.

## Placeholder assets

The checked-in presentation assets are original, code-authored placeholders: 24 slime SVGs, one player, 24 enemy SVGs, four bosses, eight ground textures, nine structure/gate/portal images and ten UI icons, plus `assets/Slimerot.svg`. There are **80 art SVGs plus the app icon**, and **10 WAVs**: exploration/boss loops, roll/rare/jackpot, hit/enemy death, purchase/gate/Breakthrough. Geometry and text provide further procedural fallback. No external art pack is required.

`SlimerotAssets` loads local PNG/WebP/SVG replacements and OGG/MP3/WAV replacements in that order. Missing optional art falls back to drawn geometry, and missing audio stays silent. See [replacement instructions](Slimerot-Assets.md). Replacing presentation files does not change collision, balance or saved identities.

## Developer instrumentation and first-build scope

Ordinary launches do not construct the Prompt 9 observer. The world requires both a debug build and `--slimerot-playtest`; the logger independently checks opt-in. It observes manager signals using bounded event/sample buffers and does not mutate gameplay RNG or progression. The estimator runs as a separate script using copied data and isolated save behavior. Android exports exclude `dev/*`, `tools/*`, `tests/*` and `docs/*`.

The scope stays at 24 base slimes and the four defined variants. There are no accounts, multiplayer, cloud saves, leaderboards, social features, ads, premium currency, paid boosts, prestige, daily challenges, achievements, weather/events, minigames, secret-condition slimes, player weapons/manual attack, slime levels, gear, additional crafting trees or additional endgame skill trees. Quick Hands VIII remains the existing final optional speed node. The protected Settings reset deletes a local save; it is not a prestige system.

## Remaining acceptance work

These limitations do not block the playable progression, but they prevent claiming that every pacing/device target is proven:

- Prompt 9's 12-seed continuous-mainline estimate reaches B1/B2/B3 at 56.30/115.97/172.80 active minutes and the final boss at a 210.57-minute median. This is an estimate with optimistic travel/combat assumptions, not a normal human playthrough. Early optional-node purchases and reduced rolling uptime can miss target windows.
- The existing adjacent-zone same-team Coin/minute ratios are 1.73/1.66/1.50/1.35/2.51/1.97/2.43, below the desired threefold growth. The newest zone remains more profitable in those fixtures. This known balance target gap is retained for human evaluation; this integration pass does not silently retune merged Prompt 9 values.
- Real airplane-mode play from fresh launch through completion, Android force-stop/low-memory recovery, signing/install and cutout/gesture/haptic behavior require an APK and physical device.
- Placeholder presentation, audio mix, thermal stability, perceived input latency and storage hitches need representative-device observation. Automated bounded stress checks cannot prove absence of all long-session/device-specific problems.

## Manual QA checklist

1. With airplane mode already enabled, launch a disposable fresh save, move, complete the first roll, inspect +1 Rolls/+1 Lifetime Roll and auto-equipped Tung Tung, then enter Backyard and observe its first attack within 30 seconds.
2. Hold movement while repeatedly rolling and while Auto Roll fights. Open live menus, then Settings; verify only explicit pause/backgrounding stops active clocks. Test Android Back, two-finger interaction, scrolling, safe insets and reset-hold cancellation.
3. Buy R01 then the 40-Roll R02; verify balances and unchanged Lifetime Rolls. Buy each Breakthrough, observe the immediate exactly x20 jump, save/reload twice, and confirm luck stays unchanged. Try all unlocked Luck Caps and filters.
4. Equip duplicate physical copies within ownership/slot limits; test Auto Equip Strongest, individual/group favorites, protected sales and mutation. Verify five Normal copies plus the exact Coin fee create one Shiny and never consume equipped/favorited copies.
5. Traverse every zone gate, meet kill/boss requirements, repair all five structures at the listed prices and revisit unlocked entrances. Test blocked Fast Travel during an encounter and before unlock.
6. Fight all four bosses, read/dodge telegraphs, retreat/reset and die. Verify no progression loss, boss flags and fixed first rewards, then reopen the save and ensure rewards cannot repeat.
7. Craft/drink each potion, compare cost/effect, reject weaker soda without consuming it and run Brew with a soda. Background/lock/force-stop/reopen and verify remaining active seconds, team, favorites, discovery, settings, gates and skills.
8. Force-stop after consequential actions and between ordinary autosaves. Check recovery to the last completed save without partial transactions. Verify an existing save, malformed-save recovery, cancellation of reset, and a completed three-second reset on disposable data.
9. Defeat Singularity Admin, enter the portal, save/reopen and continue rolling, fighting, traveling, purchasing and using structures in free roam. Repeat victory interaction to check that the first reward remains one-time.
10. Complete a normal 3–4-hour playthrough with optional-node choices recorded; use the opt-in Prompt 9 logger for milestones. Observe frame pacing, input, audio, save stalls, active node/projectile counts and memory over sustained combat/rolling. Report actual target misses before tuning.

For the final report, distinguish automated/synthetic input and controlled timer advancement from physical touch, real fights and a complete human campaign. No real-device or uninterrupted full-playthrough acceptance is implied by a passing desktop suite.
