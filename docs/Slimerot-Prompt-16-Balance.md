# Prompt 16 — balance and performance evidence

All tuning below is **PROVISIONAL**. The baseline is Prompt 15 commit `538630f3c28954d4742483491ceb680552e32060`; effects, persistent IDs, prerequisite order, base rarity thresholds, variant odds, damage exponent and exact Breakthrough multipliers are preserved. Prices paid by existing saves remain historical ledger entries; cheaper current prices do not trigger a mass refund.

## Exact tuning delta

Roll costs are spendable Rolls. Mainline block totals through B1 / B1→B2 / B2→B3 change from **1,965 / 3,150 / 4,500** to **600 / 795 / 1,125**. R01/R03/R02 remain the requested 25/40/75.

| ID | Node | Before | After |
|---|---|---:|---:|
| R01 | Quick Hands I | 25 | 25 |
| R03 | Auto Roll | 40 | 40 |
| R02 | Luck I | 75 | 75 |
| R04 | Quick Hands II | 125 | 30 |
| R05 | Luck II | 175 | 45 |
| R06 | Quick Hands III | 275 | 70 |
| R07 | Luck III | 350 | 90 |
| R08 | BREAKTHROUGH I: RNG Overdrive | 900 | 225 |
| R09 | Quick Hands IV | 350 | 90 |
| R10 | Luck IV | 400 | 100 |
| R11 | Quick Hands V | 550 | 140 |
| R12 | Luck V | 550 | 140 |
| R13 | BREAKTHROUGH II: Viral Cascade | 1,300 | 325 |
| R14 | Quick Hands VI | 700 | 175 |
| R15 | Luck VI | 700 | 175 |
| R16 | Quick Hands VII | 900 | 225 |
| R17 | Luck VII | 900 | 225 |
| R18 | BREAKTHROUGH III: Singularity RNG | 1,300 | 325 |
| RO1 | Skip Common Reveal | 150 | 40 |
| RO2 | Auto-Sell Duplicates | 450 | 115 |
| RO3 | Filter I | 300 | 75 |
| RO4 | Filter II | 500 | 125 |
| RO5 | Super Roll I | 650 | 165 |
| RO8 | Super Roll II | 900 | 225 |
| RO9 | Super Roll III | 1,500 | 375 |
| RO6 | Variant Sense | 700 | 175 |
| RO7 | Quick Hands VIII | 1,400 | 350 |

Super Roll I/II/III retain **100/75/50** intervals and **×5/×10/×20** luck. Quick Hands retains the 2.40→2.20→1.90→1.55→1.25→1.00→0.80→0.65→0.50 second cooldown ladder; RO7 is the post-campaign speed node.

Only the six Prompt 13 Coin additions receive new prices. All earlier Coin prices and all Coin effects/prerequisites remain unchanged.

| ID | Node | Before Coins | After Coins | Preserved effect |
|---|---|---:|---:|---|
| C20 | Fortune I | 8,000 | 3,000 | Luck ×1.15 |
| C21 | Fortune II | 80,000 | 30,000 | Additional luck ×1.20 |
| C22 | Fortune III | 600,000 | 150,000 | Additional luck ×1.25 |
| C23 | Slime Bond VI | 450,000 | 160,000 | Team damage +50 percentage points |
| C24 | Coin Scavenger IV | 500,000 | 200,000 | Normal-enemy Coins +100 percentage points |
| C25 | Fleet Feet III | 250,000 | 90,000 | Move speed +15 percentage points |

Triples below are **Chaser / Shooter / Tank**; `=` means unchanged. Contact damage, boss damage/rewards, spawn/respawn rules, repair costs and old Coin nodes are not retuned.

| Zone | Normal HP before → after | Coins per normal kill before → after | Gate kills before → after | Gate Coins before → after |
|---|---|---|---|---|
| Z1 Backyard | 45/70/130 (=) | 5/7/10 (=) | 12 (=) | 1,000 → 150 |
| Z2 Italian Village | 180/280/520 (=) | 18/25/40 (=) | 20 (=) | 4,000 → 1,000 |
| Z3 Cursed Forest | 700/1,100/2,000 (=) | 65/90/150 → 130/180/300 | 40 → 25 | 30,000 → 4,000 |
| Z4 Sahara | 2,600/4,000/7,500 → 1,900/3,000/5,500 | 250/350/600 → 500/700/1,200 | 30 (=) | 18,000 → 9,000 |
| Z5 Brainrot City | 9,000/14,000/26,000 → 4,000/6,500/12,000 | 900/1,300/2,200 → 1,800/2,600/4,400 | 60 → 40 | 200,000 → 45,000 |
| Z6 Backrooms | 15,000/24,000/45,000 → 6,500/10,500/20,000 | 3,500/5,000/8,500 → 7,000/10,000/17,000 | 40 (=) | 1,000,000 → 180,000 |
| Z7 Moon | 35,000/55,000/105,000 → 13,000/21,000/40,000 | 14,000/20,000/34,000 → 28,000/40,000/68,000 | 90 → 45 | 5,000,000 → 900,000 |
| Z8 Brainrot Dimension | 65,000/104,000/195,000 → 20,000/32,000/60,000 | 55,000/80,000/140,000 (=) | 100 → 30 | 0 (=) |

| Boss | HP before | HP after |
|---|---:|---:|
| Z2 Espresso Golem | 3,000 | 3,000 |
| Z4 Sand Router | 50,000 | 50,000 |
| Z6 Backrooms Janitor | 260,000 | 150,000 |
| Z8 Singularity Admin | 2,000,000 | 600,000 |

The final data changes reduce HP/gates, raise Z3–Z7 normal-enemy income and reduce skill costs. No pity, rarity, variant-power or Breakthrough nerf was used. All inherited and new provisional numbers are catalogued in [the provenance inventory](Slimerot-Prompt-16-Provisional.md).

## Deterministic purchase clocks

These are affordable-purchase timestamps from actual cost/cooldown tables, with the free starter at second zero, immediate purchases, no input/menu delay and 60 Hz cooldown quantisation. They do not establish when a player repairs the Shrine or finishes the campaign. Mainline-first policies buy the optional branches only after R18; convenience buys each optional block as it unlocks. The older model never bought delayed optional branches, so its missing Super timestamps are not failures.

| Policy | Auto R03 before → after | B1 before → after | B2 before → after | B3 before → after | New RO5 / RO8 / RO9 clock |
|---|---|---|---|---|---|
| mainline_continuous | 2.43 → 2.43 min | 56.30 → 18.06 min | 115.97 → 33.13 min | 172.80 → 47.34 min | 51.62 / 57.31 / 61.37 min |
| mainline_90_percent | 2.70 → 2.70 min | 62.56 → 20.06 min | 128.85 → 36.81 min | 192.00 → 52.60 min | 57.35 / 63.67 / 68.19 min |
| convenience_continuous | 2.43 → 2.43 min | 61.05 → 19.32 min | 156.88 → 43.57 min | 248.72 → 66.53 min | 28.49 / 52.32 / 70.59 min |

## Seeded campaign estimate

The standalone runner now defers estimation until all 54 live skill definitions are ready. It aborts on an empty tree or a failed six-component luck preflight; the verified preflight total is **7,286,400** (1.10 ×8000 ×8 ×1.725 ×3 ×20). Early candidate reports created before this fix omitted skill luck and are invalid; their campaign times are excluded. The purchase-clock comparison above is independent of that defect.

Final valid run: Godot 4.5.1, model 5, 12 seeds (9001–9012) per policy, 36/36 campaigns complete. Data fingerprint: `778e32390b0e16df67f7aeebd26612fe176dbd928adc8f38e20e43bbf7ef2739`. All values below come from the final Sahara HP revision.

| Policy | Final boss min / median / max (min) | Chaser median / p90 (s) | Longest meaningful gap (min) | Median new-best Team DPS gain |
|---|---|---|---:|---:|
| mainline_continuous | 37.96 / 40.39 / 41.90 | 3.06 / 5.88 | 3.00 | +33.5% |
| mainline_90_percent | 40.67 / 42.90 / 44.93 | 3.42 / 6.52 | 3.89 | +30.1% |
| convenience_continuous | 40.47 / 44.06 / 46.15 | 3.51 / 6.05 | 4.63 | +33.9% |

Assumptions: safe Chaser farming at 70% effective damage utilisation, two seconds travel per encounter, strongest copies equipped immediately, immediate eligible skill purchases, no deaths, no dodging physics, no menu latency, no potions/offline rewards/Shrine sacrifices. Sale travel is approximate; after Fast Travel it is optimistic. Mainline-first now purchases optional branches after R18; this differs from the older model that left them unbought forever. Convenience purchases optional blocks as soon as their trunk prerequisite unlocks. These are estimates, not human campaign times.

| Milestone | Mainline continuous median (observed/12) | Mainline 90% median (observed/12) | Convenience median (observed/12) |
|---|---|---|---|
| R03 | 2.43 min (12/12) | 2.70 min (12/12) | 2.43 min (12/12) |
| Z2 | 4.60 min (12/12) | 4.68 min (12/12) | 4.60 min (12/12) |
| Z3 | 7.40 min (12/12) | 7.43 min (12/12) | 7.40 min (12/12) |
| Z4 | 15.99 min (12/12) | 18.98 min (12/12) | 17.82 min (12/12) |
| Z5 | 21.42 min (12/12) | 24.09 min (12/12) | 22.85 min (12/12) |
| Z6 | 28.94 min (12/12) | 30.58 min (12/12) | 30.02 min (12/12) |
| Z7 | 33.85 min (12/12) | 35.53 min (12/12) | 34.80 min (12/12) |
| Z8 | 37.49 min (12/12) | 39.72 min (12/12) | 39.57 min (12/12) |
| R08 | 18.06 min (12/12) | 20.06 min (12/12) | 19.32 min (12/12) |
| R13 | 33.13 min (12/12) | 36.81 min (12/12) | 43.57 min (8/12) |
| R18 | Not reached before final boss (0/12) | Not reached before final boss (0/12) | Not reached before final boss (0/12) |
| RO5 | Not reached before final boss (0/12) | Not reached before final boss (0/12) | 28.49 min (12/12) |
| RO8 | Not reached before final boss (0/12) | Not reached before final boss (0/12) | Not reached before final boss (0/12) |
| RO9 | Not reached before final boss (0/12) | Not reached before final boss (0/12) | Not reached before final boss (0/12) |
| C02 | 5.03 min (12/12) | 5.02 min (12/12) | 5.03 min (12/12) |
| C06 | 15.78 min (12/12) | 15.88 min (12/12) | 15.88 min (12/12) |
| C10 | 24.89 min (12/12) | 26.36 min (12/12) | 25.25 min (12/12) |
| C15 | 35.01 min (12/12) | 36.98 min (12/12) | 36.43 min (12/12) |
| C20 | 14.53 min (12/12) | 15.01 min (12/12) | 14.64 min (12/12) |
| C21 | 26.64 min (12/12) | 28.74 min (12/12) | 27.57 min (12/12) |
| C22 | 34.57 min (12/12) | 36.38 min (12/12) | 35.26 min (12/12) |
| variant_shrine | 33.85 min (12/12) | 35.53 min (12/12) | 34.80 min (12/12) |
| boss_Z2 | 7.40 min (12/12) | 7.43 min (12/12) | 7.40 min (12/12) |
| boss_Z4 | 21.42 min (12/12) | 24.09 min (12/12) | 22.85 min (12/12) |
| boss_Z6 | 33.85 min (12/12) | 35.53 min (12/12) | 34.80 min (12/12) |
| boss_Z8 | 40.39 min (12/12) | 42.90 min (12/12) | 44.06 min (12/12) |

Across 14,054 kill-weighted Chaser samples, 0 exceed 15 seconds and 0 exceed 20 seconds; maximum 14.59 s. Modeled boss fights range 22.31–121.63 s: none exceed 180 s, while overgeared runs can finish below 45 s. The weakest new-best Team DPS increase is +2.1%, so a large visible jump on every marginal rarity record is not established.

All final bosses are cleared before B3 in these runs. Super II/III and some other nodes remain post-boss chases; their later purchase-clock timestamps are projections, not observed campaign milestones. The local logger records these when actually reached, plus first multi-variant and each new-best timestamp. A player can continue rolling, fighting and purchasing after campaign completion; no prestige or new currency is added.

**Controlled real-projectile boss tests:** at an explicit 70% firing window (seven seconds of each ten, with in-flight shots continuing), Normal-team fixtures clear Z2/Z4/Z6/Z8 in **81.25 / 157.25 / 126.25 / 56.13 seconds**. All meet the proposed 45–180-second ready-state band. Incoming attacks are disabled in these fixtures; a separate moving/Auto Roll combat test exercises live AI.

## Explicit loadout arithmetic

These are **arithmetic fixtures, not physics playthroughs or seeded arrival loadouts**. Each uses the listed all-Normal copies plus its explicit Coin-node bonuses. Chaser HP ÷ team DPS and boss HP ÷ boss DPS are evaluated at full uptime and at assumed 70% damage utilisation. The Z8 five-Singularity fixture is deliberately generous; it does not imply ordinary players arrive with this team.

| Zone | Normal-copy rarity thresholds | Team DPS | Chaser seconds full / 70% | Boss seconds full / 70% |
|---|---|---:|---|---|
| Z1 | 2 | 7 | 6.43 / 9.18 | — |
| Z2 | 75, 120 | 57 | 3.16 / 4.51 | 52.6 / 75.2 |
| Z3 | 700, 800, 120 | 186 | 3.76 / 5.38 | — |
| Z4 | 4000, 4000, 4000 | 369 | 5.15 / 7.36 | 112.6 / 160.9 |
| Z5 | 15000, 15000, 15000, 15000 | 884 | 4.52 / 6.46 | — |
| Z6 | 60000, 60000, 60000, 60000 | 1,380 | 4.71 / 6.73 | 90.6 / 129.4 |
| Z7 | 250000, 250000, 250000, 250000, 250000 | 3,200 | 4.06 / 5.80 | — |
| Z8 | 4000000, 4000000, 4000000, 4000000, 4000000 | 9,725 | 2.06 / 2.94 | 41.1 / 58.7 |

The fixtures give 2.06–6.43 s Chasers at full uptime, and 2.94–9.18 s at 70%. Ready-state boss fixtures give 52.6/112.6/90.6/41.1 s at full uptime and 75.2/160.9/129.4/58.7 s at 70%; the overgeared Z8 fixture is below the proposed 45 s lower bound at full uptime. A fixture pass cannot substitute for a representative campaign.

## Runtime stress benchmark

Windows Godot 4.5.1, rendered focused final suite: **215 checks, 0 failures**. These are observed local runtimes, not Android frame-rate claims. `tests/SlimerotFinalPacingTests.gd` emits machine-readable `SLIMEROT_P16_BENCHMARK` records; runtime logs remain outside the repository.

| Scenario | Work performed | Runtime | Scene-node trend | Memory trend |
|---|---|---|---|---|
| Equip Best | 24 bases × 8 masks; 1,000,000 copies per stack = 192,000,000 compact identities; 1,000 calls | 1,212.023 ms total; 1.212 ms/call | 228 at every 100-call sample; zero growth | 49,209,749→49,215,385 bytes over calls 100→1,000 (+5,636 bytes) |
| Fastest Auto Roll | 1,800 real backend commits at 0.50 s cooldown; 900 simulated seconds | 1,468.249 ms | 228 throughout; hidden Team build count unchanged | 49,228,917→49,470,137 bytes from minute 1→15 (+241,220 bytes) as bounded inventory/discovery state fills |

The Auto run drives the actual `RollManager._process` and commit path with accelerated half-second ticks; rendering settles twice per simulated minute. It proves exact +1/+1 commits and zero scene-node growth for this finite stress, not 15 wall-clock minutes of continuous GPU rendering or an asymptotic heap guarantee. Reveal backlog peaked at 9 pending entries, below its 32-entry cap. Equip Best retains compact copy ranges and a bounded copy cache. Queue overflow separately retains the strongest new-best record with a count summary; presentation never grants rewards.

## Local telemetry and acceptance limits

Opt-in debug telemetry now timestamps Auto Roll, every zone, B1–B3, all three Super tiers, slots 2–5, Fortune I–III, Variant Shrine, every boss, Dash, first multi-variant, every new all-time-best rarity and final completion. Its 30-second samples include Team DPS, current-zone Chaser TTK, earned Coins/min, Rolls/min, central effective luck, best effective rarity/raw damage and time since a meaningful milestone. The finite milestone index survives event-ring eviction. Previously discovered but consumed multi-variants do not create false first-discovery events after a load.

No representative full human playthrough or physical Android performance/force-close session has been run on this host. Runtime tests and model results must be kept separate; final acceptance remains pending those device/play-feel checks.
