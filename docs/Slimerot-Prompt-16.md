# Prompt 16 — final integration, QA and balance

Desktop automated validation **PASS**. Overall release acceptance is **PENDING** because physical Android lifecycle/airplane-mode execution and a representative human campaign have not been run. This report does not convert desktop simulations into device results.

Prompt 16 preserves Prompts 11–15 backend authority and adds no feature category. It fixes old-price save validation, retains overflowed power-record presentation in a bounded summary, adds complete power/migration/stress audits, extends local telemetry, and tunes provisional progression costs, gates, HP and Coin income. Source baseline: Prompt 15 commit `538630f3c28954d4742483491ceb680552e32060` (now merged into main).

## Deliverables and evidence

| Requested deliverable | Location |
|---|---|
| 1. Complete requirement matrix | [204 individually sourced requirements](Slimerot-Prompt-16-Matrix.md), including explicit Android status |
| 2. Exact changed files | File inventory below |
| 3. Save versions and migration chain | [Schema 1–11 and process-death report](Slimerot-Prompt-16-Saves.md) |
| 4–6. RNG/luck, variant and damage formulas | Formulas below; [192-outcome power table](Slimerot-Prompt-16-Power-Table.md) |
| 7. Exact final skill delta | [All 27 Roll and six changed Coin-node prices](Slimerot-Prompt-16-Balance.md); all effects/prerequisites preserved |
| 8. Final UI navigation map | Navigation table below |
| 9. Boss summary | Boss table below |
| 10. Performance benchmark | Benchmarks below and [timing/memory details](Slimerot-Prompt-16-Balance.md) |
| 11. Android force-close results | All eight **NOT RUN**; [261 passing desktop analog checks](Slimerot-Prompt-16-Saves.md) |
| 12. Known issues and acceptance gaps | Explicit remaining items below |
| 13. Every proposed/provisional numeric choice | [Canonical values and provenance inventory](Slimerot-Prompt-16-Provisional.md) |

## Validation results

| Run | Result | What it establishes |
|---|---|---|
| Complete headless suite | **2,158 checks, 0 failures** | Existing systems plus final RNG, save and performance regressions |
| Focused rendered final suite | **215 checks, 0 failures** | Record-summary layout, migration and stress; actual rendered summaries inspected |
| Focused rendered mobile UI | **68 checks, 0 failures** | Tree pan/pinch/zoom/Fit, touches, navigation, Back/Close, portrait sizes and hidden overlays |
| Focused rendered combat | **106 checks, 0 failures** | Dash, projectile pool/friendly fire, boss phases, combined gates and compact reveals |
| Actual Windows process kill/reopen | **261 checks, 0 failures**, eight cases | Durable critical transactions and one-time offline claims across 17 processes, nine external kills |
| Isolated export audit | **223 checks, 0 failures** | Packaged resources load without source fallback; tests/tools/dev/docs excluded |
| Packed main scene | **120 frames, successful exit** | Exported gameplay scene starts from an empty scratch project |
| Final seeded campaign model | **36/36 complete** | Explicit-assumption pacing estimates; central-luck startup preflight passed |
| Physical Android | **NOT RUN** | No device result is claimed |

These suites overlap; counts must not be added as distinct test cases. All completed final runs were checked for script/parser errors as well as failure totals. The Windows engine's root-certificate-store warning is environmental; no runtime network client is used. Matching Android SDK/build/signing/device execution remains unavailable.

The standalone estimator now waits for all 54 skill definitions before using central luck and aborts if a known six-factor preflight fails. Earlier candidate campaign figures omitted skill luck and are invalid; only the corrected final estimate is reported. Test artifacts (logs, captures, packs and raw model JSON) stay outside publication. The requested editable 192-row audit table is included as documentation.

## Exact formulas and invariants

For each issued logical result, the sole guarded commit grants exactly **+1 spendable Rolls and +1 Lifetime Rolls**. ROLL is free. A purchased Roll node decreases spendable Rolls by its price and records that payment; Lifetime never decreases. `Lifetime = balance + historical Roll spend` remains validated. Offline Auto Roll calls the same resolution/commit backend. Reveals, Super and pity never create an additional reward. Auto Roll is one manager loop.

**Luck:** `L = minor_roll_tree_product × breakthrough_product × zone_luck_multiplier × coin_tree_luck_product × active_potion_multiplier × super_roll_multiplier`. Breakthroughs are exactly **20 / 400 / 8000**. Gameplay zone luck is highest unlocked Z1–Z8 **×1…×8**, applied once; Hub adds no ninth factor. Fortune is **1.15 ×1.20 ×1.25 = 1.725** when all three are owned. Authoritative purchases, zone, potion identity and Super schedule are saved; accumulated derived luck is not restored into the calculation. Optional Luck Cap constrains the ordinary product before the one-roll Super multiplier. The developer breakdown exposes every factor and total.

**Base draw:** with uniform `U` in `(0,1]`, score `L/U` selects the highest reached canonical rarity threshold, otherwise the starter. All **24 bases are eligible from the start**; origin/zone metadata does not filter the pool. The forced first base remains the starter. A threshold is not the isolated final probability once higher thresholds compete.

**Variants:** Shiny, Glitched and Golden are independent flags with base probabilities **1/100, 1/400 and 1/1600**. For each category, `p = min(1, base_p × VariantSense × 1.05^unique_sacrificed_base_count)`; Variant Sense is 1.25 if purchased, otherwise 1. All eight masks coexist. Ordinary luck and zone luck do not enter those flag probabilities. The old five-Normals mutation recipe is inactive; one unprotected qualifying copy contributes to one selected active category, once per base/category. Favorites and equipped copies are protected.

**Rarity and damage:** `effective_rarity = N ×100^[Shiny] ×400^[Glitched] ×1600^[Golden]`; `raw_damage = round(6 × effective_rarity^0.32)`. Team and applicable boss/Brew modifiers are applied afterward with final hit rounding. Shiny base 1/2 and Normal 1/200 therefore share rarity 200 and raw damage. All 192 outcomes are audited for unique identity, exact formula and monotonic damage.

**Hidden pity:** stronger-outcome probability is computed from the current discrete sampler. Soft assistance begins after the expected interval and ramps to the provisional 25% bound; hard deadline is `ceil(3/P_better)`. It conditions one logical result rather than granting a second roll. When no stronger outcome exists, that impossible improvement deadline is disabled. Historical best and miss count persist even when the copy is sold or sacrificed.

**Super:** RO5/RO8/RO9 retain intervals **100/75/50** and multipliers **5/10/20**. The first tier schedules the next future Lifetime boundary; upgrades retain an earlier pending trigger and cap remaining wait at the new interval. The schedule survives spending and loading. A Super commit still grants only +1/+1. Hard team-slot cap remains five; there is no player XP.

## Progression and pacing

R01→R03→R02 keeps the requested 25 / 40 / 75 cost and early Auto ordering. Mainline spending blocks are now 600 / 795 / 1,125 Rolls. Breakthrough costs are 225 / 325 / 325; Super costs 165 / 225 / 375. Fortune costs are 3,000 / 30,000 / 150,000 Coins. The [exact delta tables](Slimerot-Prompt-16-Balance.md) include every changed node, HP, gate and reward.

The final corrected 12-seed-per-policy model gives median final-boss times **40.39 / 42.90 / 44.06 minutes**, with all 36 finishing in **37.96–46.15 minutes**. Median Chaser TTK is **3.06–3.51 seconds**, p90 **5.88–6.52 seconds**. None of **14,054** sampled Chaser encounters exceeds 15 seconds. The longest gap between modeled meaningful milestones is **4.63 minutes**. New-best auto-equip yields median Team DPS gains **30–34%**, but a marginal new record can add only **2.1%**.

These estimates assume immediate Equip Best and purchases, safe farming at 70% damage utilisation, no deaths and limited travel/menu overhead. They are not human playthroughs. All runs finish before B3 and Super II/III; those remain later chases, tested through deterministic purchase clocks and backend suites rather than observed before the final boss. Required unlock/first-multi/new-best timestamps and 30-second DPS/TTK/Coins/min/Rolls/min/luck samples are available in opt-in local telemetry. No online telemetry exists.

## Final navigation map

| Previous entry | Current route |
|---|---|
| Separate Inventory and Team HUD entries | **TEAM** → equipped 1–5 slots, unique-stack ownership, quantities, damage, variant flags, sort/favorite/equip/Equip Best and Team DPS |
| Collection in Info | **TEAM → COLLECTION** |
| Separate Potions HUD button | **TEAM → ITEMS** (potions) |
| Separate Roll Settings tab | **SETTINGS → ROLLING** |
| Audio/effects controls | **SETTINGS → GENERAL** |
| Save/reset | **SETTINGS → SAVE / SYSTEM**, protected hold-to-reset |
| Redundant Info tabs | **SETTINGS → Stats / About** |
| Old Skill Tree list | Shrine-gated **SKILL TREE** → 2D Roll/Coin canvases, prerequisite lines, drag/pinch, +/−/Fit and node details |
| Fast travel | Repaired-Pillar-gated **MAP** |

HUD: HP, zone, Coins, Rolls, Luck, Settings; bottom joystick and ROLL/quick Auto; Dash when unlocked. Every root has one Close path; child modals have Back. Android-style Back dispatch closes one top modal. Hidden overlays do not consume joystick/ROLL touches. Centered world labels use anchors/containers. No user slime art was overwritten and no new SVGs are introduced in Prompt 16.

## Boss summary

| Boss | Final HP | Presentation / combat | First reward |
|---|---:|---|---|
| Espresso Golem, Z2 | 3,000 | Warned slam combo, locked charge lane, recovery; free Dash unlock at its gate | 1,000 Coins + Lucky Soda |
| Sand Router, Z4 | 50,000 | Warned fan, crossing beams and sweeps | 20,000 Coins + Hyper Soda |
| Backrooms Janitor, Z6 | 150,000 | Fade/marker/arrival/windup teleport, aimed bursts, changing safe columns | 350,000 Coins |
| Singularity Admin, Z8 | 600,000 | Combined warned patterns, faster phase at 40% HP, recovery-only circles | 6,000,000 Coins + completion portal |

Retreat/death clears transient attacks and resets the encounter; first-clear flags prevent repeated rewards. Each boss zone has one combined gate that becomes the next-zone route after victory. Rare and summarized record reveals use the passive currency-header strip during combat, preserving boss warnings. Fixed-rotation player, Dash collision/i-frames, friendly fire and the original P15 telegraph timings remain covered. Real-projectile Normal-team fixtures with explicit 70% firing windows clear the bosses in **81.25 / 157.25 / 126.25 / 56.13 seconds**; incoming attacks are disabled for these timing fixtures.

## Performance and durability

| Stress | Measured outcome |
|---|---|
| 192 stacks ×1,000,000 copies; 1,000 Equip Best calls | Focused rendered: **1.212 seconds total**, constant 228 scene nodes; +5,636 bytes across measured batches |
| 15-minute equivalent at 0.50-second Auto cooldown | **1,800 actual commits**, rendered wall time **1.468 seconds**, constant 228 nodes; backlog ≤9 |
| 100 overflowing all-time power records | Bounded 32 pending entries plus one count/strongest summary; all 100 represented; strongest displayed; zero currency effect |
| Projectile/effect stress | Existing 1,800-lifetime endurance and 1,000-lifetime P15 pool checks pass; fixed 128 projectile pool, 48 feedback records and eight Dash afterimages |

Auto stress uses accelerated real backend ticks, with render settling twice per simulated minute. It does not claim 15 minutes of real GPU/mobile execution. Inventory/discovery storage grows as actual ownership changes; no per-roll UI-node growth was observed. Machine-dependent timings and full memory samples are described in the [benchmark report](Slimerot-Prompt-16-Balance.md).

Save schema remains **11**. Published historical prices are immutable compatibility data distinct from current prices; old R08/R13/RO5 payments 900/1300/650 validate without changing either wallet, ownership or ledger. Ancient missing ledgers reconstruct the historical canonical prices. The [migration chain and eight-case table](Slimerot-Prompt-16-Saves.md) record all 164 migration checks and 261 desktop process-death checks. The eight requested Android cases are individually **NOT RUN**.

## Remaining issues and acceptance boundary

Required before overall release PASS: physical Android touch/Back/pinch, eight force-stop/resume cases, airplane-mode launch/gameplay, and representative human campaign/target-device performance. This host has no usable Android device tooling. Desktop source audit found no runtime HTTP/WebSocket/network/login/cloud/remote-asset client; Android Internet/network-state permissions and backup are disabled. This is source/export evidence, not an airplane-mode device test.

Non-blocking tuning limitations: timing/costs/HP remain provisional; immediate auto-equip assumptions are optimistic; later branches occur after the final boss in the model; not every tiny rarity record creates a large DPS jump; local benchmarks do not establish Android FPS/thermal/battery behavior. No known automated crash, duplicate currency transaction, lost critical purchase, new soft-lock or unbounded scene-node growth remains in the exercised coverage.

## Changed files

49 files relative to the Prompt 15 baseline. UIDs are Godot resource identifiers; no screenshots, packs, logs or raw benchmark dumps are committed.

- `Slimerot-README.md`
- `dev/SlimerotPlaytestLogger.gd`
- `dev/SlimerotPlaytestOverlay.gd`
- `docs/Slimerot-Android.md`
- `docs/Slimerot-Final-Audit.md`
- `docs/Slimerot-Prompt-11.md`
- `docs/Slimerot-Prompt-12.md`
- `docs/Slimerot-Prompt-13.md`
- `docs/Slimerot-Prompt-14.md`
- `docs/Slimerot-Prompt-15.md`
- `docs/Slimerot-Prompt-16-Balance.md`
- `docs/Slimerot-Prompt-16-Matrix.md`
- `docs/Slimerot-Prompt-16-Power-Table.md`
- `docs/Slimerot-Prompt-16-Provisional.md`
- `docs/Slimerot-Prompt-16-Saves.md`
- `docs/Slimerot-Prompt-16.md`
- `docs/Slimerot-Prompt-7.md`
- `docs/Slimerot-Prompt-9.md`
- `docs/Slimerot-Saves.md`
- `docs/Slimerot-Testing.md`
- `docs/Slimerot-UI-Polish.md`
- `scripts/data/SlimerotBalance.gd`
- `scripts/data/SlimerotCampaign.gd`
- `scripts/data/SlimerotCoinTree.gd`
- `scripts/data/SlimerotEncounters.gd`
- `scripts/data/SlimerotRollTree.gd`
- `scripts/managers/SlimerotSaveManager.gd`
- `scripts/managers/SlimerotSlimeDatabase.gd`
- `scripts/presentation/SlimerotRollRevealQueue.gd`
- `scripts/ui/SlimerotReveal.gd`
- `tests/SlimerotBalanceTests.gd`
- `tests/SlimerotBossPresentationTests.gd`
- `tests/SlimerotCampaignTests.gd`
- `tests/SlimerotEncounterTests.gd`
- `tests/SlimerotFinalPacingTests.gd`
- `tests/SlimerotFinalPacingTests.gd.uid`
- `tests/SlimerotFinalRestartProbe.gd`
- `tests/SlimerotFinalRestartProbe.gd.uid`
- `tests/SlimerotFinalRestartProbe.tscn`
- `tests/SlimerotFinalRngTests.gd`
- `tests/SlimerotFinalRngTests.gd.uid`
- `tests/SlimerotFinalSaveTests.gd`
- `tests/SlimerotFinalSaveTests.gd.uid`
- `tests/SlimerotPlaytestTests.gd`
- `tests/SlimerotSkillTreeTests.gd`
- `tests/SlimerotTests.gd`
- `tools/SlimerotFinalRestartMatrix.py`
- `tools/SlimerotPacingEstimator.gd`
- `tools/SlimerotPacingModel.gd`
