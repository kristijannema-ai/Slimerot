# Espresso Golem and Sand Router encounter data

These are provisional design values. Attack scripts use only `BLAttack` and the portable `BLContext` runtime, with no menu, metrics, save, or main-game dependencies. HP assumes continuous representative team DPS; difficulty comes from movement and timing rather than HP inflation. Human first-clear attempt targets have not been measured.

| Boss | HP | Expected DPS / duration | Low DPS / duration | High DPS / duration | HP phase thresholds |
|---|---:|---:|---:|---:|---|
| Espresso Golem | 18,000 | 150 / 120 s | 100 / 180 s | 225 / 80 s | 70%, 35% |
| Sand Router | 19,500 | 150 / 130 s | 100 / 195 s | 225 / 86.7 s | 70%, 35% |

Timings below are seconds from the move's start, excluding the scheduler's short phase recovery. Damage is per hit; the shared 0.35 s hit grace prevents simultaneous hazard/projectile stacks from removing all HP in one frame. Dash lasts 0.16 s, travels about 240 px, and has a 1 s cooldown. Orange/red marks are damage, yellow marks are moving attacks, purple marks are movement/control effects, and blue marks are routes or the live Mirage rune.

## Espresso Golem

| Move / script | Tell and execution | Damage / geometry | Intended response |
|---|---|---|---|
| Espresso Slam / `espresso/EspressoSlam.gd` | 0.65 s circle tell; 0.16 s impact. A ring is marked at 0.67 s, waits 0.30 s, then expands at 210 px/s for 1.95 s. Phase 3 adds a second ring 0.55 s later. Total 2.95 s / 3.50 s. | Impact 24, radius 115. Ring 18, width 26, 0.76 rad safe gap; the second gap rotates 0.30 rad. | Leave the impact circle, take the visible radial gap, or Dash through a wave. Consecutive waves are closer than Dash cooldown, so repeated Dash cannot substitute for reading the gap. |
| Caffeine Charge / `espresso/CaffeineCharge.gd` | Target predicted 0.45 s ahead and locked; yellow lane warns 0.55 s; crossing takes 0.30 s; wall recovery 0.45 s. Phase 3 marks a second turn at 1.20 s, warns 0.55 s, crosses for 0.30 s. Total 1.30 s / 2.40 s. | 27, 160 px lane, destination clamped 38 px inside arena. Maximum planned travel 700 px. Follow-up predicts 0.40 s, then turns by ±0.18 rad. | The wide locked lane makes Dash the reliable escape. Walking from lane center requires roughly 0.51 s before accounting for reaction. Read the second tell separately rather than dashing immediately again. |
| Espresso Shots / `espresso/EspressoShots.gd` | Three fans begin their 0.45 s tells at 0, 0.75, and 1.50 s; shots fire at 0.45, 1.20, and 1.95 s. Total 4.75 s includes projectile travel. Light combo version has two fans and lasts 4.00 s. | 12 per projectile, radius 8, speed 250 px/s, spread 1 rad. Alternating aim offsets −0.20/+0.20/−0.20 rad. Five shots in phases 1–2, seven in phase 3; light version three shots. Phase 2+ impacts leave the shared radius-22 puddle: 0.45 s tell, 0.80 s active, 10 damage. | Weave between spokes. Each volley predicts 1.10 s of current movement and then locks. Running unchanged around the perimeter does not avoid aimed interception by design. |
| Double Shot / `espresso/DoubleShot.gd` | ONE marks the predicted 0.35 s position and explodes after 0.70 s. TWO marks at 0.12 s using 0.80 s prediction and explodes at 1.12 s. Each impact lasts 0.18 s; total 1.65 s. | 22 each, circle radius 72, centers clamped 74 px inside arena. | Reverse or redirect after reading both marks. Their 0.42 s impact spacing punishes an early Dash aimed through the second future-position circle. Both tells remain visible before damage. |
| Overcaffeinated / `espresso/Overcaffeinated.gd` | 0.35 s steam/glow tell. Reuses Charge at 0.35 and 4.20 s, Slam at 1.60 and 5.00 s. Charges warn 0.42 s and cross in 0.24 s; Slams warn 0.52 s. Total 8.40 s. | Exact existing Charge 27, Slam 24, rings 18. No damage increase. Two-ring phase-3 Slam behavior remains. | Learn the charge/slam rhythm; route through ring gaps so Dash is available for fast charges. This major sequence never receives an additional scheduler combo. |

Phase 1 uses Slam, Charge, and Shots. Phase 2 adds Double Shot and warned coffee puddles. Phase 3 adds the two-ring Slam, turning charge follow-up, seven-shot fans, and Overcaffeinated. Attack `phase_weights` are respectively Slam `[3,3.5,3]`, Charge `[3,3.5,3]`, Shots `[3,2.5,2]`, Double `[0,2.5,3]`, and Overcaffeinated `[0,0,2]`.

The only external Espresso combo is **light Espresso Shots + single Caffeine Charge**, phase 3+, with the charge starting 0.95 s after Shots. Three-shot, two-volley fans leave weaving space; the charge retains its 0.55 s warning and does not add the second charge. There are no arbitrary mixes with Double Shot or Overcaffeinated.

## Sand Router

| Move / script | Tell and execution | Damage / geometry | Intended response |
|---|---|---|---|
| Sand Fan / `sand/SandFan.gd` | Fans warn at 0 and 0.90 s for 0.50 s, firing at 0.50 and 1.40 s. Total 4.45 s includes travel. Light combo has one fan, total 3.55 s. | 12, five radius-8 shots, speed 230 px/s, 1 rad spread. Second aim offset 0.125 rad (half one spoke interval). Light fan: three shots, speed 210. | Thread the second set between the first spokes. Aim predicts 1.15 s and locks before each volley. |
| Sand Wall / `sand/SandWall.gd` | 0.90 s tell. Horizontal wall moves from a randomly selected top/bottom edge at 132 px/s for 5.65 s; total 6.65 s. | 23, thickness 28. Phase 1 has two 132 px gaps. Phases 2–3 have one 156 px gap moving sideways at 54/66 px/s, reflecting at arena limits. | Follow the blue gap or Dash through the wall. The primary gap starts near the predicted player x position, rather than selecting an unreachable random gap. Later gap motion uses identical geometry for drawing and collision. |
| Route Recalculation / `sand/RouteRecalculation.gd` | Three routes show immediately. After 0.95 s, orange routes damage for 1.65 s while the blue route remains safe. Total 2.95 s. | 20 on orange routes. Routes divide the full arena width into thirds, with lane width one third minus 10 px. Exactly one route is safe. | Move/Dash to the blue route. Selection is restricted to the current route or one neighbor, guaranteeing no full-width scramble. A neighboring route may require a decisive Dash. |
| Quicksand Nodes / `sand/QuicksandNodes.gd` | Three/four fields warn 0.65 s, then last 3.85 s. A light three-shot fan warns at 1 s for 0.50 s, fires at 1.50 s. Total 4.80 s includes travel. | Fields: no damage, radius 62, movement at 65%. Fan: 12, radius-8 shots, speed 210, spread 1 rad. | Steer around predicted/offset field placements and weave the fan. Dash remains usable; controls never lock. The internal light fan prevents a harmless waiting-only turn. |
| Mirage Routers / `sand/MirageRouters.gd` | Three copies appear; one consistently has a blue ground rune. Fan tells begin at 0.25 and 1.25 s, each warning 0.55 s. Total 4.90 s includes last fan travel. | Only the blue-rune copy fires: five shots, speed 235, spread 1 rad, damage 12. Purple copies show harmless empty fan tells. | Identify the ground rune instead of reacting to all copies. The live source is selected before tells and cannot change during the move. |
| Sand Collapse / `sand/SandCollapse.gd` | Initial edges warn 1.10 s. Thicker edges mark at 1.25 s, warn 0.80 s; final bands mark at 2.70 s, warn 0.80 s. Light fans warn at 1.50/3.40 s for 0.55 s. All edge danger ends by 5.95 s; total 6.35 s. | Edges 30, lane widths 100→180→250 (50→90→125 px inward from each edge). Two three-shot fans: 12, speed 210, spread 1.10 rad. In the 640×760 arena, final safe center is 390×510 before player-radius margins. | Move inward progressively, then weave the two light fans. The center stays broad; no wall, quicksand, rerouting, or additional full fan overlaps this major sequence. |

Phase 1 uses Fan, Wall with two gaps, and three Quicksand nodes. Phase 2 adds moving single-gap Walls, Route Recalculation, Mirage Routers, and the fourth Quicksand node. Phase 3 adds Sand Collapse and faster gap motion. Attack `phase_weights`: Fan `[3,2.5,2]`, Wall `[3,3,3]`, Quicksand `[2,2,1.5]`, Route `[0,2.5,3]`, Mirage `[0,2,2.5]`, Collapse `[0,0,2.5]`.

The only external Sand combo is **Sand Wall + light Sand Fan**, phase 2+, fan starting 1.20 s after Wall. Only three light projectiles fire; the wall keeps its visible 156 px route. Route Recalculation and Sand Collapse never combine with other scheduler moves.

## Fairness and tuning caveats

Every damaging area receives at least 0.30 s of warning; projectiles receive a prior 0.45–0.55 s source fan tell. Aim snapshots never home after firing. Position prediction, alternating fans, two delayed marks, single moving gaps, and authored collapse edges challenge constant circle-running. Safe responses remain geometric: walking lanes/gaps, changing direction, or a timed Dash.

All modules clean up their owner hazards/projectiles. Overcaffeinated also cleans child attack owners. No move creates per-projectile scene nodes; every source uses the fixed shared pools. Fan durations deliberately include projectile travel so cleanup does not erase the last volley before a distant player can encounter it.

Known unpolished behavior to evaluate with human playtesting: Sand Wall can become easy when the player begins aligned with its gap; the Mirage rune is deliberately explicit and may be too easy after discovery; the Overcaffeinated ring/charge overlap may need wider gaps after mobile reaction testing; first-clear attempt counts and “fun” are design targets, not measured claims. These values must remain provisional until repeated human keyboard/touch sessions establish the intended attempt ranges.

## Resource override keys

Open `data/Espresso.tres` or `data/Sand.tres` in Godot and expand **Attack Overrides**. Add an attack ID entry whose value is a dictionary of the following keys. Numeric defaults are listed in the move tables above; absent keys preserve those defaults. The controller merges resource overrides into actual attack parameters. The committed pattern suite verifies resource changes reach real hazard geometry, warnings, projectile speed/count/damage, and slowing, rather than changing only debug labels. Keep damaging hazard tells at least 0.25 s.

| Attack ID | Supported meaningful parameter keys |
|---|---|
| `espresso_slam` | `tell`, `impact_radius`, `impact_active`, `impact_damage`, `ring_count`, `ring_delay`, `ring_interval`, `ring_tell`, `ring_active`, `ring_width`, `ring_speed`, `ring_damage`, `gap_width`, `gap_turn`, `recovery` |
| `caffeine_charge` | `tell`, `travel`, `width`, `damage`, `distance`, `lead`, `follow_delay`, `follow_tell`, `follow_lead`, `follow_turn`, `wall_recovery`, `follow_recovery`, `single`, `recovery` |
| `espresso_shots` | `tell`, `speed`, `projectile_damage`, `projectile_radius`, `count`, `volleys`, `volley_spacing`, `spread`, `aim_offset`, `lead`, `travel_allowance`, `puddle_radius`, `puddle_tell`, `puddle_active`, `puddle_damage`, `light`, `recovery` |
| `double_shot` | `first_tell`, `second_tell`, `second_delay`, `first_lead`, `second_lead`, `active`, `radius`, `damage`, `recovery` |
| `overcaffeinated` | `duration`, `power_tell`, `charge_times`, `slam_times`, `charge_params`, `slam_params`, `recovery`; the two nested dictionaries accept the corresponding reusable move's keys. Duration extends if a configured child would otherwise be cut off. |
| `sand_fan` | `tell`, `speed`, `projectile_damage`, `projectile_radius`, `count`, `volleys`, `volley_spacing`, `second_offset`, `spread`, `lead`, `travel_allowance`, `light`, `recovery` |
| `sand_wall` | `tell`, `active`, `speed`, `width`, `damage`, `gap_width`, `gap_speed`, `lead`, `recovery` |
| `route_recalculation` | `tell`, `active`, `damage`, `route_count`, `route_padding`, `recovery` |
| `quicksand_nodes` | `tell`, `active`, `radius`, `slow`, `node_count`, `spread_x`, `spread_y`, `angle_jitter`, `lead`, `fan_delay`, `fan_tell`, `fan_speed`, `fan_count`, `fan_spread`, `fan_lead`, `projectile_damage`, `projectile_radius`, `travel_allowance`, `recovery` |
| `mirage_routers` | `copies`, `source_y`, `copy_radius`, `rune_radius`, `first_fan`, `fan_spacing`, `fan_tell`, `count`, `speed`, `spread`, `lead`, `projectile_damage`, `projectile_radius`, `travel_allowance`, `recovery` |
| `sand_collapse` | `duration`, `edge_widths`, `edge_delays`, `edge_tells`, `edge_lifetimes`, `edge_damage`, `fan_times`, `fan_tell`, `count`, `speed`, `spread`, `lead`, `projectile_damage`, `projectile_radius`, `recovery`; the four edge arrays use matching indices. |

For example, set `espresso_slam: {"tell": 0.75, "impact_damage": 22, "ring_speed": 195.0}` to soften the first impact and slow its radial chase, or `sand_wall: {"gap_width": 180.0, "gap_speed": 42.0}` to broaden and slow the moving route. When lowering projectile speed, increase `travel_allowance` so the final volley is not cleaned before it reaches distant positions. Changes to speed, width, gap count, or warning durations require rerunning the pattern suite and movement playtests; geometric safety alone does not establish a fun or reachable response.
