# Slimerot Prompt 9 — balance and playtest instrumentation

> **Historical record — Prompt 16:** Historical Prompt 9 tuning evidence. Its 20–30-minute farming walls, 210-minute campaign target and old RNG/variant assumptions are superseded by Prompt 16 constant-pace acceptance. Do not use the targets or estimates below as the current design; use the Prompt 16 report, requirement matrix and provisional inventory. Historical measurements and the reasons for those former edits are retained.

The integration pass adds an opt-in developer observer, reproducible pacing estimates, and measured combat fixtures. It reduces late-game enemy sponginess and adjusts six gates plus two Breakthrough prices. The final 12-seed mainline estimate reaches the final boss at **210.57 active minutes median (207.40–213.87)**. This is a model result, not a completed human campaign; the remaining acceptance gaps are explicit below.

## Repository and scope

Origin was verified as `https://github.com/kristijannema-ai/Slimerot.git`. After fetching, `main` was still Prompt 7 at `136392cd2961be9120b939ec5a09879473710e60`. The user explicitly approved using the existing Prompt 8 branch instead. `slimerot/stage-9-balance` therefore starts at `f55b8a3c470e5196b18b3c68f0d984091fecb58b` from `slimerot/stage-8-save`. A review against that main includes Prompt 8 as a prerequisite. Main was not merged or changed by this work.

The existing eight gameplay managers and presentation service remain in place. All three Breakthroughs still multiply luck by exactly x20. Optional nodes remain independent of mainline prerequisites. No gate requires a specific slime. There is no Prompt 10 content, new player feature category, offline reward, save schema change, or network dependency.

## Developer logger and overlay

Run the project from the Godot editor/debug executable with these user arguments:

```sh
godot --path . -- --slimerot-playtest
```

The normal game still loads and saves its ordinary local progression. Use a disposable playtest save/profile for a fresh campaign. The observer itself never grants currency, purchases, rolls, equips, changes a save, or consumes either gameplay RNG stream. It is absent from ordinary launches; activation requires both a debug build and the explicit flag. `dev/*`, `tools/*`, `tests/*`, and `docs/*` are excluded from the Android export preset. The dynamically guarded world bootstrap also tolerates missing developer resources.

Snapshots contain active play seconds, observer run/segment seconds, Lifetime and spendable Rolls, Coins, Team DPS, slots, Effective Luck, strongest currently owned/equipped copies and variants, zone, purchases, Luck Cap and Auto Sell settings, potion state, currency accounting, and observed boss damage/time. Milestones include the first roll, skill purchases and Breakthroughs, first observed zone entry, gates/structures, boss start/defeat/end, completion, and changes to strongest copies, team, or gate blockers.

Samples occur every 30 active seconds. Pause does not advance their clock. Events and samples are bounded to 2,048 and 1,024 entries, with drop counts disclosed. Every applied save starts an explicit observation segment, even when its clock is identical or moves forward. Imported progress becomes a baseline instead of falsely earned milestones. Backward-clock resets are also segmented. SaveManager emits a read-only notification after restoration and before arena cleanup; boss timing does not cross that boundary.

**F8 / Hide log** toggles details; **F9 / Export log** writes JSON and a tab-separated text summary. Labels are click-through; only the two explicit buttons consume taps. The layout follows the HUD safe area and leaves movement/ROLL controls available. Exports include a run ID, UTC start, balance-source fingerprint, stable fields, assumptions, and timestamps for comparison. Closing normally also exports; an abrupt process kill can lose unexported diagnostic samples. Default destination: `user://Slimerot-playtests`. Override it with `--slimerot-playtest-output=<directory>`. Export errors appear in the overlay and do not affect gameplay.

## Every tuned gameplay constant

Values below compare the Prompt 8 base with the final Prompt 9 source. HP array order is Chaser / Shooter / Tank. There are **19 distinct values**; the Z1 gate also has an existing compatibility alias which is kept in sync.

| Constant / source | Old → new | Reason |
| --- | --- | --- |
| Z6 HP, `SlimerotCampaign.gd` | 30,000 / 48,000 / 90,000 → 15,000 / 24,000 / 45,000 | The ready Normal-team Chaser fixture exceeded 20 seconds. Halve this tier's HP while retaining archetype proportions. |
| Z7 HP, same file | 95,000 / 150,000 / 280,000 → 35,000 / 55,000 / 105,000 | The old Chaser took 29 seconds at the reference progression; bring ordinary fighting back near 10 seconds. |
| Z8 HP, same file | 300,000 / 480,000 / 900,000 → 65,000 / 104,000 / 195,000 | The old Chaser exceeded the fixture's 30-second limit; make the final zone playable with Normal post-B3 copies. |
| Janitor HP, `SlimerotEncounters.gd` | 650,000 → 260,000 | The ready projectile fixture took 392 seconds before tuning; the final value takes 157 seconds. |
| Admin HP, same file | 7,500,000 → 2,000,000 | The old value exceeded the 400-second fixture limit; the final ready-team fixture takes 137 seconds. |
| Z1 gate, `SlimerotCampaign.gd` and `SlimerotBalance.BACKYARD_GATE_COINS` | 150 → 1,000 | The original estimated Z2 arrival was about 5 minutes; this reaches about 10 minutes including the Hub repairs. |
| Z2 gate, `SlimerotCampaign.gd` | 900 → 4,000 | Preserve an early farming/upgrade interval before the late-Z3 wall after reducing later combat time. |
| Z3 gate, same file | 4,000 → 30,000 | Keep a meaningful B1 farming wall while allowing one exit within 20 minutes after B1 in the final mainline seeds. |
| Z5 gate, same file | 75,000 → 200,000 | Keep the second wall relevant as slots, damage, and duplicate values rise. |
| Z6 gate, same file | 300,000 → 1,000,000 | Offset the shorter Janitor/normal fights and place Z7 near its 135–155-minute window. |
| Z7 gate, same file | 1,200,000 → 5,000,000 | Preserve the third wall after HP reductions, while permitting its exit within 20 minutes after B3 in the tested mainline seeds. |
| R08 cost, `SlimerotRollTree.gd` | 800 → 900 Rolls | Continuous Auto Roll reached B1 at 53.72 minutes; one 100-Roll step moves it to 56.30. |
| R13 cost, same file | 1,000 → 1,300 Rolls | Move B2 into its window at 115.97 minutes and consequently B3 to 172.80 without changing R18. |

Mandatory spend blocks consequently change **1,865 / 2,850 / 4,500 → 1,965 / 3,150 / 4,500**, cumulative **1,965 / 5,115 / 9,615**. These are derived totals, not additional tuned constants. Historic purchases retain their recorded old prices; no existing wallet is charged the difference. Previously paid gates remain open without a second payment.

Z1–Z5 normal HP, Z4 gate (18,000), all kill requirements, all enemy damage/rewards, boss damage/patterns/rewards, Coin-node costs/effects, optional Roll costs, speed effects, rarity thresholds, variant chances, damage/sale formulas, potions, and structures are unchanged. Runtime constants remain centralized in the original data files; the estimator reads them.

Tuning followed the requested order. The original two-seed end-to-end estimates finished at 254.78–270.71 minutes and the late combat fixtures exposed excessive HP. The HP-only pass passed all 106 scoped combat checks but made the 12-seed mainline median about 176.67 minutes. Gate scenarios then restored the farming intervals. Only after that were R08/R13 increased in 100-Roll steps. A final reduction of provisional Z3/Z7 gate costs from 35,000/6,000,000 to 30,000/5,000,000 shortened the post-Breakthrough exits. Coin-node costs and rarity thresholds were not retuned.

## Final pacing estimates

Reproduce from the project root with a Godot 4.5.1 debug executable:

```sh
godot --headless --path . --script res://tools/SlimerotPacingEstimator.gd -- --slimerot-estimate --slimerot-estimate-seeds=12 --slimerot-estimate-output=/absolute/path/Slimerot-pacing
```

Use an appropriate absolute output path on Windows. The CLI writes `.json` and `.txt`; omit the output flag to print only. Both the runner and SaveManager guard estimation so project autoloads cannot load or save player progression. The model uses local RNGs and copied scenario data, never live manager mutations.

Final constant fingerprint: `333ba5f44403db07bbc1374f2d1462b556852220aefb8be1d9ec8943eb0f451d`.

| Milestone | Target, active minutes | Continuous mainline median | Min–max, 12 seeds |
| --- | --- | --- | --- |
| Z2 | 8–12 | 10.01 | 10.01–10.01 |
| B1 / R08 | 55–65 | 56.30 | 56.30–56.30 |
| Z5 | 70–90 | 78.85 | 76.36–80.16 |
| B2 / R13 | 115–130 | 115.97 | 115.97–115.97 |
| Z7 | 135–155 | 152.62 | 148.43–156.37 |
| B3 / R18 | 170–190 | 172.80 | 172.80–172.80 |
| Final boss defeated | 200–230 | 210.57 | 207.40–213.87 |

All 12 mainline seeds finished. The Roll clock is deterministic within a policy because every ordinary completion earns one Roll. The model uses 60 Hz cooldown quantisation; it does not invent menu delays to meet the targets. Auto Roll continues during movement, combat and non-pausing menus; Settings/app pause stop active time.

Sensitivity policies are deliberately shown separately:

| Policy, 12 seeds each | B1 / B2 / B3 median | Final median (min–max) |
| --- | --- | --- |
| Continuous mainline | 56.30 / 115.97 / 172.80 | 210.57 (207.40–213.87) |
| 90% rolling uptime | 62.56 / 128.85 / 192.00 | 226.97 (222.94–231.06) |
| Buy every available RO1–RO6 convenience node immediately | 61.05 / 140.09 / 227.76 | 243.64 (238.33–245.46) |

All runs completed within the six-hour simulation horizon, including optional spending. Optional nodes do not gate the mainline, but their shared currency causes a real delay. The 90% policy is a cadence sensitivity, not an assertion that walking automatically interrupts Auto Roll. It also reaches Z2 at a 15.03-minute median due to the fixed five-minute sale cadence.

Assumptions: safe Chaser farming; six rotating Chaser positions and the live five-second respawn; 70% combat/boss damage utilisation; two seconds between farm targets; duplicate sales every five minutes; fixed Coin-node priorities; gates first when eligible; ordinary score and independent variant sampling; strongest copies equipped immediately. Travel before the Z4 Pillar is approximated from map distances. After Pillar repair, sale travel/menu interaction is assumed instantaneous, and repair-trip time before sales is omitted. No potions, mutation, death, dodging, frame stalls or human decision delays are simulated. This event model is intentionally optimistic in several respects; the outputs are estimates rather than gameplay recordings. JSON preserves raw runs, purchase clocks, actual completion counts, unreached nulls, snapshots, zone residence and coin-blocked time.

## Breakthrough and farming acceptance gaps

In the final continuous-mainline runs, every seed exited **one** zone within 20 minutes of each Breakthrough, with no 3-zone instant skips. The ten-minute medians were 0 / 1 / 0 zone exits. At fixed purchase-time luck/cooldown, the analytic mean wait for the current-zone target-or-better is 3.40 minutes for Bombardiro after B1, 1.10 for La Vaca after B2, and 0.34 for Celestial after B3. These assume the target is unlocked and exclude subsequent speed upgrades, variants and potions. They do not guarantee an upgrade over an already lucky inventory: only 7/12, 8/12 and 4/12 runs acquired a copy with at least 25% more damage than their strongest owned copy within ten minutes. Girafa after unlocking Z4 has a fixed-rate mean of 12.76 minutes, outside 3–8. The desired emotional jump still needs human observation.

**The literal adjacent-zone ≥3× Coins/min target remains unmet.** With each reference team held constant between the two zones, equal travel/utilisation, Chasers only, and no boss payouts or duplicate sales, Z2–Z8 ratios are **1.73 / 1.66 / 1.50 / 1.35 / 2.51 / 1.97 / 2.43**. Each newest zone remains more profitable in these fixtures. Ratios against two zones back are 4.13 / 3.10 / 2.62 / 3.75 / 5.31 / 5.72, which is a different comparison and does not satisfy the adjacent-zone requirement. JSON labels both metrics and the separate different-loadout comparisons.

This pass retains existing Coin rewards and sale relationships instead of introducing a much larger economy rewrite to force the ratio. Acceptance of that tradeoff or a follow-up economy pass is still needed. Passing the runtime tests does not mean every balance target has passed. Some Z7 seed arrivals, 90%-uptime milestones, and the all-convenience policy also miss their stated windows.

## Gameplay and regression validation

Official Godot **4.5.1 stable**, Windows:

- Prompt 8 baseline: 946 checks, zero failures before this pass.
- Final combined headless: **1,165 checks, zero failures**, successful exit.
- Final combined rendered: **1,165 checks, zero failures**, including the existing Prompt 7 touch/menu/reveal/Settings assertions. Developer overlay and Settings captures were inspected.
- Developer observer coverage: 87 checks covering opt-in guards, no progression/RNG mutation, current ownership/equipment, milestones, pause/sample bounds, JSON/text exports and errors, boss teardown, resets, and identical/forward/backward save-load boundaries.
- Controlled actual-projectile combat: all eight zones plus four bosses, using real CombatManager timers and flight at 1/60-second steps. Final Chasers take **3.27–10.35 seconds** with the documented Normal reference teams. Bosses take **57.27 / 112.27 / 157.15 / 137.15 seconds**. Hostile AI is frozen for these measurements: these are firing/HP fixtures, not human fight durations. The final boss fixture uses five Normal Singularity copies with the full reference damage build.
- A separate live movement/AI fight verifies actual movement, multiple Auto Rolls, a normal Coin-paying kill, and advancement of the ordinary active clock. Historical R08/R13 prices, unchanged wallets, derived-once luck, paid gate flags and repeated save/load also pass.
- The model tests cover sampled score/variant agreement with live methods, deterministic reruns, copied-data/RNG/progression isolation, derived effects, mandatory clocks and explicit unreached milestones.
- Real restart probe: a progressed writer saved, printed readiness, and was forcibly terminated. A new Godot process passed **11 additional checks**, preserving wallet/ledger, exact team/favorites/collection, luck, potion/cooldown/active-time values, gates and final completion. Probe saves are isolated under `.godot/`.

The Windows root-certificate warning is environmental. Final runs have no Slimerot parser/runtime failures. Generated logs, estimates, screenshots, isolated saves and caches are not repository deliverables.

## Human validation still required

Run a fresh 3–4-hour campaign with the observer enabled, normal equipment/menu habits and optional-node choices recorded. Export around each hour, each Breakthrough and final completion. Compare active-time milestones, actual boss DPS, deaths, farm routes/sales, strongest-copy improvements and the ten/twenty minutes after each x20 purchase. Assess the Z3/Z5/Z7 slow periods for frustration and confirm whether the larger Coin gates feel justified. Repeat with weaker luck and early convenience purchases; the current estimates do not cover all player policies.

Physical Android APK installation/export, safe areas and multi-touch on hardware, audio balance, thermal/performance behavior, airplane-mode play, and Android OS process death/background/resume remain device work. Desktop forced restart and rendered UI checks do not substitute for those checks. No completed human full playthrough or certified 3–3.5-hour experience is claimed.

## Files

Created:

- `dev/SlimerotPlaytestLogger.gd` and `dev/SlimerotPlaytestOverlay.gd`, with their Godot UID files.
- `tools/SlimerotPacingModel.gd` and `tools/SlimerotPacingEstimator.gd`, with UIDs.
- `tests/SlimerotPlaytestTests.gd` and `tests/SlimerotBalanceTests.gd`, with UIDs.
- This report, `docs/Slimerot-Prompt-9.md`.

Modified:

- `scripts/data/SlimerotCampaign.gd`, `SlimerotEncounters.gd`, `SlimerotBalance.gd`, `SlimerotRollTree.gd`: the complete tuning list above.
- `scripts/world/SlimerotWorld.gd`: guarded observer bootstrap.
- `scripts/managers/SlimerotSaveManager.gd`: estimator isolation and read-only load-boundary signal.
- `export_presets.cfg`: exclude developer tooling from player exports.
- `tests/SlimerotTests.gd`, `SlimerotCampaignTests.gd`, `SlimerotEncounterTests.gd`, `SlimerotSkillTreeTests.gd`, `SlimerotRestartProbe.gd`: integrate coverage and update intentional balance expectations.
- `Slimerot-README.md`, `docs/Slimerot-Testing.md`: current prices, developer usage, results and limits.
