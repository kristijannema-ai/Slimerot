# Prompt 16 — provisional numbers and provenance

This inventory separates exact requested invariants from provisional balance and implementation choices. The available feedback consists of Prompts 12–16 and the retained Prompt 11 issue report; earlier numeric origins cannot be verified from an unseen original specification. **Inherited** therefore means present in the repository baseline, not a claim that the user supplied that number. Historical reports retain their original numbers; the tables here read the current data definitions. Prompt 16 deltas and measured reasons are in the final integration report.

All campaign HP/gates/income, skill costs other than explicitly fixed constraints, player/boss timing and optional presentation/engineering limits below remain **PROVISIONAL** until representative Android and human campaign tests. Data extraction is documentation only: it does not change or duplicate gameplay authority. Colors, SVG path coordinates, font glyph metrics and ordinary enum/ID numbering are authored appearance/encoding rather than balance proposals; gameplay collision geometry and UI interaction limits are included below.

## Explicit feedback formulas and adopted proposed baselines

| Value | Exact current rule | Available source/provenance |
|---|---|---|
| Currencies | One logical committed roll: +1 Rolls, +1 Lifetime; free ROLL; skill spend changes only Rolls | P12 A/P16 B exact invariant |
| Roster/slots | 24 bases; 8 masks; 5 equipped maximum; zones 1–8 exclude Hub | P12 B/D, P13 D, P16 C/D |
| Luck | minor × Breakthrough × zone × Fortune × potion × current Super; Breakthrough 20/400/8000; zone 1…8 | P13 B/P16 C exact invariant |
| Variant odds | independent Shiny 1/100, Glitched 1/400, Golden 1/1600 | P12 D/P16 D exact baseline |
| Variant rarity | base N ×100 if Shiny ×400 if Glitched ×1600 if Golden | P12 E/P16 D exact formula |
| Raw damage | round(6 × effective_rarity^0.32), before team/boss modifiers | P12 E/P16 D exact formula |
| Shrine | 1.05^unique category count; cap probability 1; one physical copy→one chosen active flag | P12 G; one-category behavior explicitly PROPOSED then adopted |
| Pity | start 1×expected, force 3×expected, maximum soft assist 0.25; smoothstep ramp | P12 H PROPOSED soft constants; hard ceil(3×expected) requested |
| Adaptive reveal | surprise 25/100/1000; relevance 0.85×weakest; major breathing gap≥5 s | P12 I/J thresholds/relevance PROPOSED; 5 s requested |
| Auto/Luck order | R01 25; R03 40 requires R01; R02 75 requires R03 and luck×1.10 | P13 A exact requested values |
| Super cadence | 100/75/50 rolls; ×5/×10/×20 | P13 C PROPOSED adopted baseline; current costs listed below |
| Fortune effects | ×1.15/×1.20/×1.25, cumulative×1.15/×1.38/×1.725 | P13 D PROPOSED adopted effects; current prices below |
| New Coin bonuses | C23 team +50 percentage points; C24 normal Coins +100 percentage points; C25 movement +15 percentage points | P13 D PROPOSED adopted effects |
| Tree zoom | .55 minimum,1.8 maximum | P14 G PROPOSED adopted bounds |
| Friendly fire | round(target.max_hp×.20), normals only, never source/boss | P15 C exact requested rule |
| Dash | .16 s; 240 px from 1500 px/s; 1 s from start | P15 D PROPOSED .16 s/220–260 px/1 s; 240 px midpoint and 1500 px/s implementation choice |
| Dash unlock | Free at Z2 boss gate before Espresso; legacy reached Z2 defaults unlocked | P15 D PROPOSED unlock adopted; migration choice documented |
| Chaser QA | 2–10 s target; sustained 15–20 s flags sponge risk | P16 E PROPOSED QA target, not forced scaling |
| Ready boss QA | 45–180 s | P16 E PROPOSED QA target; overgear remains permitted |

## Canonical campaign values — PROVISIONAL

Source: `scripts/data/SlimerotCampaign.gd: ROWS`. Triples are Chaser / Shooter / Tank. Levels are metadata, not player XP. Values inherited unless the Prompt 16 delta table identifies a tuning change.

| Zone | Level range | HP | Coins per kill | Contact/shot damage | Kills to gate | Gate Coins |
|---|---|---|---|---|---|---|
| 1 | 1, 3 | 45, 70, 130 | 5, 7, 10 | 8, 6, 12 | 12 | 150 |
| 2 | 4, 7 | 180, 280, 520 | 18, 25, 40 | 12, 10, 18 | 20 | 1000 |
| 3 | 8, 12 | 700, 1100, 2000 | 130, 180, 300 | 18, 15, 26 | 25 | 4000 |
| 4 | 13, 18 | 1900, 3000, 5500 | 500, 700, 1200 | 26, 22, 38 | 30 | 9000 |
| 5 | 19, 26 | 4000, 6500, 12000 | 1800, 2600, 4400 | 38, 32, 55 | 40 | 45000 |
| 6 | 27, 36 | 6500, 10500, 20000 | 7000, 10000, 17000 | 55, 45, 80 | 40 | 180000 |
| 7 | 37, 48 | 13000, 21000, 40000 | 28000, 40000, 68000 | 75, 65, 110 | 45 | 900000 |
| 8 | 49, 65 | 20000, 32000, 60000 | 55000, 80000, 140000 | 100, 85, 150 | 30 | 0 |

## Boss values — PROVISIONAL

Source: `scripts/data/SlimerotEncounters.gd: BOSSES`. These are inherited numeric baselines except documented Prompt 16 HP changes. The feedback requires preserving four identities/reward flags, not silently replacing rewards.

| Zone/boss | HP | Contact | Slam | Shot/beam | Final AoE | Coins | Potion | Move px/s |
|---|---|---|---|---|---|---|---|---|
| 2 / Espresso Golem | 3000 | 16 | 24 | 0 | 0 | 1000 | lucky_soda | 65.0 |
| 4 / Sand Router | 50000 | 35 | 0 | 50 | 0 | 20000 | hyper_soda | 70.0 |
| 6 / Backrooms Janitor | 150000 | 65 | 0 | 80 | 0 | 350000 | none | 0.0 |
| 8 / Singularity Admin | 600000 | 110 | 0 | 140 | 170 | 6000000 | none | 75.0 |

## Every Roll node price/effect

Source: `scripts/data/SlimerotRollTree.gd: MAINLINE/OPTIONAL`. Prices are spendable Rolls, individually charged. R01/R03/R02 requested prices remain fixed; other inherited or subsequently tuned prices are PROVISIONAL. All Breakthrough effects stay exactly ×20. Legacy ledgers preserve historical prices instead of retroactively charging these.

| ID/name | Prerequisites | Rolls | Effect/value | Provenance |
|---|---|---|---|---|
| R01 Quick Hands I | root | 25 | cooldown_set 2.2 | P13 A exact cost |
| R03 Auto Roll | R01 | 40 | auto_roll 1.0 | P13 A exact cost |
| R02 Luck I | R03 | 75 | luck_multiplier 1.1 | P13 A exact cost |
| R04 Quick Hands II | R02 | 30 | cooldown_set 1.9 | Inherited / P16 tuning if changed |
| R05 Luck II | R04 | 45 | luck_multiplier 1.15 | Inherited / P16 tuning if changed |
| R06 Quick Hands III | R05 | 70 | cooldown_set 1.55 | Inherited / P16 tuning if changed |
| R07 Luck III | R06 | 90 | luck_multiplier 1.2 | Inherited / P16 tuning if changed |
| R08 BREAKTHROUGH I: RNG Overdrive | R07 | 225 | checkpoint_luck 20.0 | Inherited / P16 tuning if changed |
| R09 Quick Hands IV | R08 | 90 | cooldown_set 1.25 | Inherited / P16 tuning if changed |
| R10 Luck IV | R09 | 100 | luck_multiplier 1.2 | Inherited / P16 tuning if changed |
| R11 Quick Hands V | R10 | 140 | cooldown_set 1.0 | Inherited / P16 tuning if changed |
| R12 Luck V | R11 | 140 | luck_multiplier 1.25 | Inherited / P16 tuning if changed |
| R13 BREAKTHROUGH II: Viral Cascade | R12 | 325 | checkpoint_luck 20.0 | Inherited / P16 tuning if changed |
| R14 Quick Hands VI | R13 | 175 | cooldown_set 0.8 | Inherited / P16 tuning if changed |
| R15 Luck VI | R14 | 175 | luck_multiplier 1.25 | Inherited / P16 tuning if changed |
| R16 Quick Hands VII | R15 | 225 | cooldown_set 0.65 | Inherited / P16 tuning if changed |
| R17 Luck VII | R16 | 225 | luck_multiplier 1.25 | Inherited / P16 tuning if changed |
| R18 BREAKTHROUGH III: Singularity RNG | R17 | 325 | checkpoint_luck 20.0 | Inherited / P16 tuning if changed |
| RO1 Skip Common Reveal | R04 | 40 | skip_common 1.0 | Inherited / P16 tuning if changed |
| RO2 Auto-Sell Duplicates | R08 | 115 | auto_sell 1.0 | Inherited / P16 tuning if changed |
| RO3 Filter I | R08 | 75 | filter_1 1.0 | Inherited / P16 tuning if changed |
| RO4 Filter II | R13 | 125 | filter_2 1.0 | Inherited / P16 tuning if changed |
| RO5 Super Roll I | R08 | 165 | super_roll 1.0 | P13 C proposed branch; see P16 delta |
| RO8 Super Roll II | RO5, R13 | 225 | super_roll 2.0 | P13 C proposed branch; see P16 delta |
| RO9 Super Roll III | RO8, R18 | 375 | super_roll 3.0 | P13 C proposed branch; see P16 delta |
| RO6 Variant Sense | R13 | 175 | variant_sense 1.0 | Inherited / P16 tuning if changed |
| RO7 Quick Hands VIII | R18 | 350 | cooldown_set 0.5 | Inherited / P16 tuning if changed |

## Historical save-price limits — compatibility, not current prices

`SlimerotRollTree.HISTORICAL_PRICES` retains published prices as validation bounds and as the fallback for ancient canonical-ID saves without a spend ledger. Explicit saved payments remain unchanged, including zero-cost migrated grants. These historical values never refund the wallet or change Lifetime Rolls. The oldest named nodes map `quick_hands_1`→R01 paid 10, `luck_1`→R02 paid 15 and `auto_roll`→R03 paid 25.

| ID | Highest accepted published Rolls price |
|---|---|
| R01 | 25 |
| R02 | 75 |
| R03 | 75 |
| R04 | 125 |
| R05 | 175 |
| R06 | 275 |
| R07 | 350 |
| R08 | 900 |
| R09 | 350 |
| R10 | 400 |
| R11 | 550 |
| R12 | 550 |
| R13 | 1300 |
| R14 | 700 |
| R15 | 700 |
| R16 | 900 |
| R17 | 900 |
| R18 | 1300 |
| RO1 | 150 |
| RO2 | 450 |
| RO3 | 300 |
| RO4 | 500 |
| RO5 | 650 |
| RO6 | 700 |
| RO7 | 1400 |
| RO8 | 900 |
| RO9 | 1500 |

## Every Coin node price/effect

Source: `scripts/data/SlimerotCoinTree.gd: ROWS`. All current prices are PROVISIONAL. C20–C25 effects/prerequisites came from P13 proposed baselines; current prices can be tuned under P16 F. Other values are inherited. `+` prerequisites combine with the listed zone/boss/structure requirements.

| ID/name | Prerequisites | Coins | Effect/value | Zone | Boss | Structure |
|---|---|---|---|---|---|---|
| C01 Slime Bond I | root | 100 | team_damage_add 0.1 | 1 | none | none |
| C02 Equipped Slot 2 | C01 | 350 | slot_set 2 | 1 | none | none |
| C03 Coin Scavenger I | C01 | 600 | coin_scavenger 0.2 | 1 | none | none |
| C04 Toughness I | C01 | 750 | hp_add 50 | 1 | none | none |
| C05 Slime Bond II | C01 | 1200 | team_damage_add 0.15 | 1 | none | none |
| C06 Equipped Slot 3 | C05 | 3500 | slot_set 3 | 1 | 2 | none |
| C07 Duplicate Dealer I | root | 2500 | duplicate_dealer 0.25 | 1 | none | sell_terminal |
| C08 Slime Bond III | C05 | 5000 | team_damage_add 0.2 | 1 | none | none |
| C09 Boss Hunter I | root | 6000 | boss_damage_add 0.2 | 1 | 2 | none |
| C10 Equipped Slot 4 | C08 | 25000 | slot_set 4 | 1 | 4 | none |
| C11 Coin Scavenger II | C03 | 20000 | coin_scavenger 0.3 | 4 | none | none |
| C12 Toughness II | C04 | 20000 | hp_add 100 | 4 | none | none |
| C13 Slime Bond IV | C08 | 30000 | team_damage_add 0.25 | 4 | none | none |
| C14 Duplicate Dealer II | C07 | 50000 | duplicate_dealer 0.5 | 5 | none | none |
| C15 Equipped Slot 5 | C13 | 250000 | slot_set 5 | 1 | 6 | none |
| C16 Slime Bond V | C13 | 200000 | team_damage_add 0.3 | 6 | none | none |
| C17 Boss Hunter II | C09 | 250000 | boss_damage_add 0.3 | 1 | 6 | none |
| C18 Coin Scavenger III | C11 | 300000 | coin_scavenger 0.5 | 6 | none | none |
| C19 Final Bond | C16, R18 | 1000000 | team_damage_add 0.5 | 7 | none | none |
| C20 Fortune I | root | 3000 | luck_multiplier 1.15 | 3 | none | none |
| C21 Fortune II | C20 | 30000 | luck_multiplier 1.2 | 5 | none | none |
| C22 Fortune III | C21 | 150000 | luck_multiplier 1.25 | 7 | none | none |
| C23 Slime Bond VI | C16 | 160000 | team_damage_add 0.5 | 7 | none | none |
| C24 Coin Scavenger IV | C18 | 200000 | coin_scavenger 1.0 | 7 | none | none |
| C25 Fleet Feet III | CO2 | 90000 | move_speed_add 0.15 | 7 | none | none |
| CO1 Fleet Feet I | root | 2000 | move_speed_add 0.1 | 2 | none | none |
| CO2 Fleet Feet II | CO1 | 40000 | move_speed_add 0.1 | 5 | none | none |

## Roster thresholds and sale economy

Source: `scripts/data/SlimerotRoster.gd: ROWS`. The 24 thresholds are inherited; no exact threshold list was supplied in P12–16, and P16 requires tuning them last. Origin remains metadata only. Raw damage follows the exact feedback formula above. Base sale is inherited `max(1, round(4 × base_N^0.45))`; variant sale multipliers are inherited Shiny×2, Glitched×5, Golden×10, multiplicative for combinations, then purchased Duplicate Dealer effects. Sale economy is PROVISIONAL; canonical variant rarity multipliers never change with Shrine odds.

| Base ID | Origin zone | Base N |
|---|---|---|
| tung_tung_tung_sahur | 1 | 2 |
| brr_brr_patapim | 1 | 12 |
| chimpanzini_bananini | 1 | 75 |
| ballerina_cappuccina | 2 | 20 |
| cappuccino_assassino | 2 | 120 |
| tralalero_tralala | 2 | 800 |
| lirili_larila | 3 | 100 |
| frigo_camelo | 3 | 700 |
| bombardiro_crocodilo | 3 | 4000 |
| trippi_troppi | 4 | 400 |
| bombombini_gusini | 4 | 2500 |
| girafa_celestre | 4 | 15000 |
| orangutini_ananasini | 5 | 1500 |
| bobritto_bandito | 5 | 10000 |
| la_vaca_saturno_saturnita | 5 | 60000 |
| cacto_hipopotamo | 6 | 6000 |
| glorbo_fruttodrillo | 6 | 40000 |
| talpa_di_ferro | 6 | 250000 |
| blueberrinni_octopussini | 7 | 20000 |
| chef_crabracadabra | 7 | 150000 |
| celestial_tralalero | 7 | 900000 |
| cosmic_tung_tung_sahur | 8 | 80000 |
| nuclear_bombardiro | 8 | 600000 |
| brainrot_singularity | 8 | 4000000 |

## Structures and potions — inherited PROVISIONAL prices/timers

Source: `scripts/data/SlimerotEncounters.gd: STRUCTURES/POTIONS`. Shrine displays Variant Shrine while retaining the `mutation_lab` persistent ID.

| Structure ID | Zone | Repair Coins | Local position |
|---|---|---|---|
| skill_tree_shrine | 0 | 25 | (450, 500) |
| sell_terminal | 0 | 75 | (770, 500) |
| potion_bench | 2 | 900 | (780, 970) |
| fast_travel_pillar | 4 | 15000 | (780, 970) |
| mutation_lab | 6 | 250000 | (780, 970) |

| Potion | Coins | Boss required | Luck |
|---|---|---|---|
| Lucky Soda | 300 | none | 2.0 |
| Hyper Soda | 8000 | 4 | 3.0 |
| Boss Brew | 30000 | 6 | 1.0 |

All potions last 300 active seconds; Boss Brew is a separate ×1.25 boss-damage channel. Stronger soda wins without wasting a weaker bottle. `MUTATION_COPIES=5` and `MUTATION_FEE_MULTIPLIER=20`, if retained in Encounters, are inactive legacy constants: `InventoryManager.mutate()` rejects the old recipe, and no current UI offers it. They are not active provisional gameplay.

## Player/enemy/arena and feedback choices — PROVISIONAL

| Source | Knobs | Current values and provenance |
|---|---|---|
| SlimerotBalance.gd | Player | HP 100; move 180 px/s; starter damage 7; initial roll cooldown 2.4 s; attack 1 s/range 180 px/projectile 500 px/s; regen delay 4 s then 5% max HP/s; death fade 1.5 s; orbit 52 px; interact 110 px. Inherited. |
| SlimerotCampaign.gd | Archetypes | Chaser/Shooter/Tank speeds 75/60/32 px/s, attack intervals 1/1.8/1.6 s; aggro 300 px; leash 400 px; Shooter preferred 125–230 px; normal shot 240 px/s; respawn 5 s. Inherited. |
| SlimerotCampaign.gd enemy() | Optional speed modifiers | Shooter projectile Z3×1.10, Z4×.90, Z7×1.15, Z8×1.10; other zones×1. Prompt 15 implementation choice. |
| SlimerotPlayer.gd | Dash/trails | Duration 0.16 s, speed 1500 px/s, cooldown 1 s; eight ghosts,.18 s lifetime,.025 s emission; 19 px collider; hit flash 0.12 s; camera combined offset cap 12 px. Choice within P15 proposed motion. |
| SlimerotEncounters.gd | Arena | 900×1200 px at(1200,0); reset Rect(45,55,810,1090); player(450,930); boss(450,550); teleports(220,360),(680,360),(220,770),(680,770). Inherited. |
| SlimerotBoss.gd | Espresso | 3 s chase,.8 s first/.65 s second slam warning,.22 s release,1 s charge warning,700 px/s charge up to 360 px,1.25 s recovery; 62 px contact/charge collision radius; charge clamp(95,110)…(805,1080). Prompt 15 choices. |
| SlimerotBoss.gd | Ranged/fan | 3.2 s normal/1.8 s final chase; five/.28 rad or seven/.25 rad fan; .8 s warning,.3 s release; 1.4 s recovery. Prompt 15 choices. |
| SlimerotBoss.gd | Teleport/bursts | Wait 2.2 s Janitor/1.2 s Admin; fade-out 0.35 s, marker 0.65 s, fade-in 0.40 s; destination≥210 px when candidate permits; two 3-shot bursts,.18 rad spread,.65 s warning,.2 s release. Prompt 15 choices. |
| SlimerotBoss.gd | Beams | Warning 1.05 s, sweep 0.9 s, active 0.4 s; 74 px normal lanes; vertical y 130…1060, x clamp 180…720; horizontal x 95…805, y clamp 240…960; Janitor safe gap 300 px, centers 330/570, field x 80…820. Prompt 15 choices. |
| SlimerotEncounters.gd; SlimerotBoss.gd | Other boss geometry/cadence | Shot 250 px/s; slam radius 150 px; AoE 85 px with 1.2 s warning; final phase ≤40% HP and circle eligible ≥4 s only at recovery; contact timer 1 s. Inherited/Prompt 15 choices. |
| SlimerotCombatFeedback.gd | Reusable effects | 48 fixed records,.42 s effect lifetime; player shake 7 px/.18 s; unlock shake 3 px/.22 s. Hit/death/boss/Dash/impact/unlock burst(count, radius): (8,44)/(12,72)/(8,48)/(7,46)/(4,26)/(4,24)/(14,140); ordinary enemy hit(6,36). Prompt 15 choices. |
| SlimerotProjectile.gd; SlimerotCombatManager.gd | Projectile limits | 128 preallocated shots; saturation declines new shot; hostile lifetime 6 s; spawn 0.09 s; no per-hit particles nodes. Prompt 15 implementation choices. |
| SlimerotAssets.gd | Attack squash | .12 s. Inherited presentation choice. |

## UI/reveal and engineering choices — PROVISIONAL

| Source | Values | Provenance |
|---|---|---|
| SlimerotPresentation.gd | Adaptive tier durations 0.50/1.40/3/4/5 s; Skip Common 0.20 s; pending limit 32; variant tier floors 1/2/3 and all flags 4 | Prompt 12 authored tuning; .20 s inherited |
| SlimerotPresentation.gd | Legacy reveal thresholds 100/10000/100000/1000000; durations 0.35/.65/1.10/1.70/2.80 s; repeat jackpot 1 s | Legacy helper retained for compatible callers; current adaptive queue uses adaptive values |
| SlimerotPresentation.gd; HUD | Joystick 90 px; old touch setting 62 px; graph/Theme touch minimum 64 px; scroll deadzone 14 px; Breakthrough 1.8 s; menu debounce 0.4 s | Inherited/Prompt 14 implementation choices |
| SlimerotSkillTreeCanvas.gd | Node 172×104 px; y layout×.86; zoom 0.55…1.8; drag threshold 9 px; button zoom factor 1.2; Fit padding 28 px; focus zoom at least 0.85; per-copy page 12 entries in Menus | Zoom proposed P14; layout/pagination implementation choices |
| Reveal/Player | Noncombat reveal shake≤5 px/.75 s; combat card in existing y 138…200 header; no fullscreen reveal shake during bosses | Prompt 12/P15 implementation choices |
| SlimerotBalance.gd | Autosave 10 active seconds; offline slice 256 rolls/4000 microseconds; cancellable reset 3 s | Inherited implementation limits; not new reward formulas |
| SlimerotBalance.gd | Luck Caps MAX(unlimited)/20/1; Variant Sense×1.25; default autosell threshold 100; filter I 20/100/1000 | Inherited optional settings; independent variant denominator unchanged |
| SlimerotBalance.gd SETTINGS | Master 1.0, music 0.7, SFX 1.0; shake/vibration true; Auto/Auto Sell false; cap 0(unlimited) | Inherited new-save preference defaults |
| SaveFormat/SaveManager | Schema 11; variant bits 1/2/4; 32-bit RNG lattice 4294967296; exact integer maximum 9007199254740991 | Encoding/invariant implementation, not provisional power tuning |
| SlimerotInventoryManager.gd | Compact identity threshold 512 copies; bounded copy-lookup cache 128 entries | Inherited implementation limits; quantities stay authoritative |
| SlimerotVariants.gd | Shrine unique-category count clamped 0…24; probability capped 1 | Roster/cardinality constraint; canonical rarity denominators unaffected |
| project.godot; export_presets.cfg | Virtual 720×1280; ARM64; package com.slimerot.game; version code 10/name 0.3.0; network permissions false | Inherited package/layout settings; hardware acceptance pending |

## Local telemetry and pacing-model assumptions

These knobs are **PROVISIONAL MODEL ASSUMPTIONS**, not game rewards or human completion guarantees. Source: `dev/SlimerotPlaytestLogger.gd`, `tools/SlimerotPacingModel.gd`, `tools/SlimerotPacingEstimator.gd`. Current default seeds 12 starting 9001,360-minute model horizon (input clamp 1–720 minutes),60 Hz cooldown quantization,2 s between farm targets,70% normal/boss damage utilisation,300 s duplicate-sale cadence. Policies use continuous or 90% roll uptime. Six Chaser spawn slots share the live 5 s respawn. The initial guaranteed roll is at 0 s and modeled purchase delay 0 s. Potions/Shrine odds/human errors are omitted unless a scenario explicitly supplies them; pillar travel/menu assumptions are optimistic. Ten-minute/600 s longest-meaningful-unlock-gap warning is an implementation QA heuristic, not a feedback-supplied hard target. Existing 10-minute post-Breakthrough diagnostic windows and 1.25× strongest-copy improvement marker are model diagnostics, not requirements or bonus multipliers.

| Logger constant | Current source value | Provenance |
|---|---|---|
| SCHEMA_VERSION | `2` | Local diagnostic implementation choice |
| SAMPLE_SECONDS | `30.0` | Local diagnostic implementation choice |
| MAX_EVENTS | `2048` | Local diagnostic implementation choice |
| MAX_SAMPLES | `1024` | Local diagnostic implementation choice |
| MAX_MILESTONES | `384 # 192 rarity classes plus finite nodes, zones, bosses and structures.` | Local diagnostic implementation choice |

Stress durations/quantities and timing tolerances belong to tests, not player balance: Prompt 16 requires 192 stacks,1,000 Equip Best calls and≥15 minutes at fastest supported Auto cooldown. Any additional fixture counts, memory budgets or acceleration choices must be reported with the benchmark and must not be presented as Android performance guarantees.
