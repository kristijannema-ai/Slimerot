# Backrooms Janitor and Singularity Admin

These are experimental Boss Lab encounters. Their mechanics and figures are provisional. Damage below is a hit, subject to the shared player grace interval and Dash immunity. A lingering danger can hit again if the player remains inside it after grace expires. All damage geometry is also the drawing and hitbox-debug geometry. No attack script calls menus, metrics, saves, or main Slimerot systems.

The shared balance defaults are 100 player HP, 180 px/s movement, 0.16 s Dash, 1.0 s Dash cooldown, 240 px Dash distance and 150 expected team DPS. Listed move recoveries are upper bounds; the controller caps Janitor recovery by phase at 0.35/0.25/0.20 s and Admin at 0.35/0.27/0.20/0.16 s. Safe corridors account for the 12 px player radius. Controls remain active in movement fields. Damage uses orange/red, moving attacks yellow, special mechanics purple, and wet/annular safe cues blue.

## Backrooms Janitor

19,500 HP gives 130 s at uninterrupted expected DPS, 195 s at low 100 DPS, and 86.67 s at high 225 DPS. These are arithmetic fight durations, not evidence of player clears. Phase 1 is 100–70% HP, phase 2 is 70–35%, phase 3 is 35–0%.

| Move / script | Tell and execution | Damage | Response |
| --- | --- | --- | --- |
| Janitor Teleport / `janitor/JanitorTeleport.gd` | Flicker and arrival circle for 0.70 s in P1, 0.60 s later. Boss travels during the last 0.08 s. Arrival then starts a separate 0.46 s sweep warning; 145 px rotating sector, 1.4 rad arc, 2.3 rad/s, 0.40 s active. Total 2.05 s; recovery 0.25 s. | 22 | Read the arrival, then leave the sector or Dash across it. Teleport itself has no damage. |
| Mop Sweep / `janitor/MopSweep.gd` | 0.65 s warning, 175 px radius, 1.22 rad current wedge sweeps clockwise at 4.2 rad/s for 1.10 s. P3 starts a reverse sweep at 2.05 s, with its own 0.55 s warning. Total 2.30 s early / 4.00 s P3; recovery 0.30 s. | 27 | Leave melee radius or time Dash through the moving wedge. The preview shows the entire upcoming sweep and its direction. |
| Cleaning Cart / `janitor/CleaningCart.gd` | 0.80 s lane warning. Cart rectangle is 64 ×116 px; moves left to right over 2.30 s early / 2.00 s P3. At the far wall, upward and downward bottle fans get 0.40 s warning; three bottles each, 0.6 rad spread, 230 px/s. Bottles fire at 3.50 s early / 3.20 s P3. Maximum total `max(4.65, bottle_fire + F(destination, 230))`; recovery 0.30 s. | Cart 24; bottle 12 | Move ahead or behind the cart; avoid the terminal bottle lanes. The drawn cart rectangle is the actual damaging footprint. |
| Wet Floor / `janitor/WetFloor.gd` | Two horizontal strips at 35% and 68% arena height, each 48 px wide; 0.65 s warning and 2.30 s wet duration. Movement multiplier 0.86, bounded slide with retained steering. Total 3.15 s; recovery 0.25 s. | 0 | Keep dry routes or compensate for sliding. This move always starts its authored Teleport partner in normal scheduling. |
| Wrong Door / `janitor/WrongDoor.gd` | Four edge doors flash at 0, 0.36, 0.72 and 1.08 s in a seeded, varying order. Boss fades to 22% opacity, emerges from the last highlighted door at 1.60 s, then warns 0.60 s before a 420 px, 1.4 rad sector sweeps at 2.8 rad/s for 1.00 s. Total 3.70 s; recovery 0.25 s. | 30 | Remember the last flash, leave that door’s directional sweep, or Dash through it. Arrival has no damage. |
| Lights Out / `janitor/LightsOut.gd` | Darkness amount 0.54; boss, player and bright warning lights remain readable. Three 76 px circles appear at 0.35 / 0.83 / 1.31 s, each with 1.05 s tell and 0.30 s damage duration. Darkness clears at 2.85 s. Total 3.10 s; recovery 0.30 s. | 22 | Read the marked circles and change route. An authored Wet Floor partner provides control pressure without adding more damaging patterns. |

The scheduler weights by phase are:

| Move | P1 | P2 | P3 |
| --- | ---: | ---: | ---: |
| Teleport | 3.0 | 2.7 | 2.3 |
| Mop Sweep | 3.0 | 2.4 | 2.8 |
| Cleaning Cart | 2.5 | 1.8 | 1.5 |
| Wet Floor | 0 | 2.1 | 2.2 |
| Wrong Door (major) | 0 | 2.5 | 2.3 |
| Lights Out (major) | 0 | 0 | 2.4 |

Only two authored combinations are allowed: Wet Floor + Teleport from P2 (0.85 s partner delay, 100% when Wet Floor is selected), and Lights Out + Wet Floor from P3 (0.10 s delay, 100%). These are alternatives; no three-way darkness/floor/teleport stack. Interruption cleanup restores darkness and boss opacity.

## Singularity Admin

22,500 HP gives 150 s at uninterrupted expected DPS, 225 s at low DPS, and 100 s at high DPS. Phase thresholds are exactly 70%, 40% and 15%, yielding four phases. Final phase insets each arena edge by 24 px during a warned, harmless phase transition.

| Move / script | Tell and execution | Damage | Response |
| --- | --- | --- | --- |
| Gravity Well / `admin/GravityWell.gd` | 220 px field, 0.85 s tell, 4.10 s active; inward force 48 px/s. Light three-shot fans warn 0.55 s beginning at 0.25 / 1.10 / 1.95 s; 0.85 rad spread, 190 px/s. Final fire 2.50 s; maximum total `max(5.25, 2.50 + F(source, 190))`; recovery 0.25 s. | Field 0; shot 10 | Walk against pull, route outside the field or Dash out; weave the light fan. Force never takes away input. |
| Orbital Projectiles / `admin/OrbitalProjectiles.gd` | Six orbiters in P1/P2, eight in P3/P4; 96 px orbit radius, 1.70 rad/s. Release begins at 1.15 s and staggers by 0.32 s. Each orbiter locks a fresh target and shows its exact launch lane 0.45 s before release; no homing after release. Speed 225 px/s; radius 8 px. Final release 2.75 s early / 3.39 s late; maximum total `last_release + F(center, 225) + 96/225`; recovery 0.25 s. | 12 | Harmless orbit is preparation time; respond to each staggered locked trajectory. |
| Singularity Dash / `admin/SingularityDash.gd` | Fixed 70 px capsule lane warns 0.78 s early / 0.66 s P4. Boss traverses in 0.20 s; lane damages for 0.24 s. At tell +0.30 s, a 180 px gravity-wake field warns 0.30 s then pulls 42 px/s for 0.85 s. Total 2.70 s; recovery 0.25 s. | Dash 30; wake 0 | Sidestep the locked lane or Dash; resist the bounded wake before the next pattern. |
| Repulsion / `admin/Repulsion.gd` | Central field and four exact edge rectangles warn 1.05 s. Push is 95 px/s for 0.55 s; edge danger lasts 1.45 s. Edge strips are 70 px early / 82 px P4. Total 2.85 s; recovery 0.30 s. | Edge 26; push 0 | Position inward before the burst. Central space itself deals no damage; needless outward Dash risks the edge. |
| Admin Delete / `admin/AdminDelete.gd` | Two corner rectangles P2, three P3, four P4. Rectangles each cover 38% arena width ×29% height. 1.05 s tell, 1.45 s active. A 24%-width vertical and 42%-height horizontal central cross always remains connected. Total 3.00 s; recovery 0.25 s. | 28 | Leave the red DELETE blocks into the broad central cross. |
| Admin Command: Freeze / `admin/FreezeFields.gd` | Four 78 px circles warn 0.85 s and remain 3.55 s. Inside speed multiplier is 0.45; no literal freeze. Light three-shot fans warn 0.60 s beginning at 0.20 / 1.25 s, spread 0.80 rad, speed 180 px/s. Final fire 1.85 s; maximum total `max(4.85, 1.85 + F(source, 180))`; recovery 0.25 s. | Field 0; shot 10 | Navigate the connected routes between fields; movement and Dash remain available. |
| Event Horizon / `admin/EventHorizon.gd` | Major, isolated. Boss recenters in 0.45 s. Whole mechanic warns 1.45 s; safe ring starts at radius 170 px, full width 160 px, expands 40 px/s over 4.40 s. Inner and outer space are dangerous. Three single shots warn 0.65 s beginning at 1.60 / 2.35 / 3.10 s, speed 160 px/s. Final fire 3.75 s; maximum total `max(6.10, 3.75 + F(center, 160))`; recovery 0.40 s. | Outside band 32; shot 10 | Reach the broad blue band and follow its expansion; the 12 px body leaves 136 px effective radial tolerance. The usable band moves from 102–238 px to 278–414 px: no stationary radius stays safe for the entire sequence. |
| Collapse / `admin/Collapse.gd` | Major, isolated. One quadrant P3, two adjacent quadrants P4. Rectangle footprints leave a 96 px center cross joining remaining areas. 1.25 s tell, 3.45 s active. Easy three-shot fans warn 0.65 s beginning at 0.55 / 1.45 s, 0.9 rad spread, 170 px/s. Final fire 2.10 s; maximum total `max(5.15, 2.10 + F(source, 170))`; recovery 0.30 s. | Quadrant 32; shot 10 | Exit marked quadrants, using Dash for distant corners; use the central connecting paths. |

| Move | P1 | P2 | P3 | P4 |
| --- | ---: | ---: | ---: | ---: |
| Gravity Well | 3.0 | 2.5 | 2.2 | 2.6 |
| Orbital Projectiles | 3.0 | 2.4 | 2.0 | 2.4 |
| Singularity Dash | 3.0 | 2.8 | 2.5 | 3.3 |
| Repulsion | 0 | 2.0 | 1.8 | 2.4 |
| Delete | 0 | 2.1 | 2.4 | 3.0 |
| Freeze | 0 | 1.8 | 1.5 | 1.0 |
| Event Horizon (major) | 0 | 0 | 2.8 | 2.5 |
| Collapse (major) | 0 | 0 | 2.3 | 2.6 |

Allowed external combinations are Gravity Well + Orbital Projectiles from P2 (0.80 s delay, 35% chance when Gravity Well is selected), and Admin Delete + Singularity Dash in P4 (0.45 s delay, 50%). Event Horizon and Collapse already include deliberately lighter projectile pressure; they receive no extra scheduler partner. The scheduler never launches arbitrary pairs and caps active attack modules at two.

## Projectile travel and recovery

In the timing tables, `F(origin, speed)` is the farthest playable-arena corner distance from the projectile origin divided by speed, plus 0.15 s. This is a bounded travel allowance, with normal 60 Hz callback quantization. Cart, Gravity Well, Freeze, Collapse, Orbital and Event Horizon recover early when their last authored activity has occurred and **their own** pending events, hazards and projectiles have cleared. Another attack owner or cosmetic FX cannot hold them open. The maximum ensures a distant final volley reaches its target; early recovery avoids silent waiting after close shots hit or leave the arena. Owner cleanup still runs on recovery and phase/retry interruption.

Gravity's field remains through 4.95 s, Freeze through 4.40 s, Collapse through 4.70 s and the Event Horizon annulus through 5.85 s. Orbital can recover after the last release and actual shot clearance; Cart after its bottle release and actual shot clearance. Attack lifetime therefore depends on source position and real projectile flight, rather than a misleading fixed total. HP-driven fight durations are unaffected because the test team attacks continuously outside phase-transition protection.

## Tuning and remaining playtest questions

Use `data/JanitorProfile.gd` / `data/AdminProfile.gd` for HP, phase thresholds, weights, combo probability, damage and exposed timing/geometry `params`. Values not exposed there live near the top of the corresponding small move script. Change the shared player/DPS settings in `data/Balance.tres`; attacks read the generic context, not the Lab UI.

Cart is a moving rectangular damage obstacle, not a physics wall that can trap the player. Door flashes deliberately offer memory training without randomness at the moment of impact. Lights Out uses bounded dimming, not black vision. Their difficulty and first-clear attempt targets still require human playtesting. Orbital release lock, swept-sector preview and continuous repulsion are shared runtime features required by these modules; integration tests must verify them. No first-clear attempt numbers are fabricated from scripted runs.

The most important human tuning questions are whether the cart plus terminal bottles is too easy when staying on its far side, whether the door memory cue is readable on a small phone, whether forward/reverse Mop timing encourages a learned Dash instead of simply always staying outside melee radius, and whether Admin’s light fans plus gravity maintain pressure without making the annular/collapse rules unreadable. AI geometry checks and scripted runtime scenarios supplement these questions; they cannot establish fun or a human learning curve.

## Automated move and combination probe

Godot 4.5.1 loaded both profiles and all 14 move scripts without parser errors. A production-context probe executed 39 phase-eligible individual move casts and all seven phase-eligible authored combination cases at 60 Hz: 627 checks, zero failures. The sampled arena retained safe cells throughout damaging patterns. Every cast ended, owner cleanup cleared its hazards/projectiles, temporary darkness and opacity reset, and the seven runtime nodes stayed constant. Peak concurrent hazards were five; peak shots were thirteen. This earlier probe is sampled geometry/cleanup evidence. The final integrated suite additionally verifies distant last-volley flight, early recovery after cleared nearby shots, and moving-band reachability; see [validation](../VALIDATION.md). No physical-device performance or human-playtest result is claimed.
