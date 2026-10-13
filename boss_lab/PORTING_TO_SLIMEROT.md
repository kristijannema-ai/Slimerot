# Porting an approved Boss Lab encounter to Slimerot

This document describes a future, separately reviewed integration. No Boss Lab boss has been installed in the main game. `boss_lab/` has its own `project.godot`; its `.gdignore` keeps these resources outside the main project's import and class scan. Keep that boundary while experimenting. The main game must continue to launch, export and load saves without Boss Lab present.

The portable encounter code consists of the small attack modules, data profiles, scheduler, controller and geometry runtime. `BLAttack` is typed against `BLContext`, and that context is typed against `BLPlayer`. Those are encounter-core types, not Lab menu/debug dependencies. They nevertheless require an explicit adapter for Slimerot's existing player and combat backend; copying a profile alone is not a working port.

## What to promote

Promote only a boss version approved through manual feedback and integration validation. Copy the selected files to a new main-game encounter directory, for example `scripts/encounters/`, and give its types a production namespace or deliberately retain the unique `BL` namespace. Update all `res://` paths to the new location. Do not reference `res://boss_lab/...` from the main project or remove `.gdignore` to make imports work.

| Portable source | Production responsibility |
| --- | --- |
| `core/Attack.gd` | Per-move event timeline, duration, recovery and owner cleanup. |
| `core/AttackScheduler.gd` | Phase weights, anti-repetition and explicit two-attack combinations. |
| `core/BossController.gd` | Encounter HP, phases, attack lifecycle, interruption and defeat notification. Adapt its arena/visual setup to production. |
| `core/Context.gd` | Player/boss references, arena geometry, seeded RNG, hazard/shot creation, repositioning and feedback hooks. This is the main integration boundary. |
| `core/HazardPool.gd` | Exact circle, ring, capsule lane, moving wall, rectangle, rotating sector, annular and control-field geometry; warnings and damage use the same shapes. |
| `core/ProjectilePool.gd` | Bounded hostile projectiles, swept collision, orbit/lock/release behavior and optional impact puddles. |
| `core/Effects.gd` | Bounded cosmetic feedback, or replace with an adapter to existing combat feedback. |
| `core/Profile.gd`, `core/Balance.gd` and selected `data/*.tres` / profile scripts | Approved boss parameters and shared movement/collision assumptions. Do not import Lab DPS presets as player progression. |
| Selected `attacks/<boss>/` scripts | Meaningful independent moves listed below. |
| Selected local `assets/` files | Optional approved boss presentation; adapt paths or use existing `SlimerotAssets` art. |

There are 25 move modules:

| Boss / main encounter | Modules |
| --- | --- |
| Espresso Golem / zone 2 | `EspressoSlam`, `CaffeineCharge`, `EspressoShots`, `DoubleShot`, `Overcaffeinated` |
| Sand Router / zone 4 | `SandFan`, `SandWall`, `RouteRecalculation`, `QuicksandNodes`, `MirageRouters`, `SandCollapse` |
| Backrooms Janitor / zone 6 | `JanitorTeleport`, `MopSweep`, `WetFloor`, `CleaningCart`, `LightsOut`, `WrongDoor` |
| Singularity Admin / zone 8 | `GravityWell`, `Repulsion`, `AdminDelete`, `OrbitalProjectiles`, `EventHorizon`, `FreezeFields`, `Collapse`, `SingularityDash` |

The profile scripts and `.tres` resources are the editable attack/phase data; they preload individual modules. Keep attack IDs stable once promoted so attribution, metrics and saved diagnostics stay understandable. Detailed experimental figures and responses are in [Espresso/Sand](attacks/ESPRESSO_SAND.md) and [Janitor/Admin](attacks/JANITOR_ADMIN.md).

## Player and damage adapter

The existing production actor is `scripts/world/SlimerotPlayer.gd`, registered as `CombatManager.player`. It already supplies `request_dash()` and `is_dashing()`, has upright visuals, wall collision, a 0.16 s / 240 px Dash and a 1.0 s cooldown. Reuse those controls and the existing HUD/joystick. Never create a second controllable player or a second Dash cooldown.

Before adapting the core, choose one explicit interface strategy: make a production actor interface used by the promoted context, or supply a typed `BLPlayer`-compatible facade that delegates to the actual `SlimerotPlayer`. A facade must synchronize position, velocity and HP and delegate damage/Dash to the real actor. Its inherited `step()` and collider must remain disabled; only the existing player moves. Apply its control-field modifiers to the existing player's movement calculation rather than moving a hidden second body. Because the current context accesses typed player properties directly, a facade needs more than the same method names.

Map the contract deliberately:

| Core access | Production source / adapter behavior |
| --- | --- |
| `player.global_position`, `velocity` | Existing player's world position and velocity in the same coordinate space as the boss/hazards. |
| `hp` / player death | `GameState.player_hp`, `GameState.player_dead`, and the existing death/respawn flow. |
| `request_dash()` / `is_dashing()` | Delegate to existing `SlimerotPlayer`; respect unlock, modal pause, death and wall collision. |
| `take_hit(amount, attack)` | Route through `CombatManager.damage_player(amount)`, preserve damage attribution, and return whether HP actually fell. Keep Dash immunity and a reviewed hit-grace policy. |
| `speed_modifier`, `external_force`, `sliding` | Per-tick modifiers applied to the real player's movement, cleared each tick and on exit. Bound forces and minimum steering as in the Lab; never replace player input with a freeze. |
| `balanced.player_radius` | Production collision/damage radius chosen explicitly. The Lab uses 12 px; the current main body uses a 19 px collider. Re-test gaps and safe bands when changing that assumption. |

The Lab's 0.35 s hit grace limits repeat damage from lingering hazards. The existing damage hook is not an interchangeable implementation of that policy. Decide how the promoted encounter applies grace and test it through the actual production hook, otherwise a hazard checked each frame can drain HP far faster than its Lab behavior. Preserve the current main damage rules until a scoped integration intentionally changes them. Likewise, do not silently multiply flat Lab damage by player HP; decide and document production damage scaling separately.

Use `GameState.is_paused()` and the production modal stack to suspend both attack clocks and pools. On player death, retreat, arena exit, scene replacement or encounter restart: cancel all scheduled events, clear both active attack owners and pending companions, cancel boss moves, clear projectiles/fields/FX, restore opacity/darkness and remove movement modifiers. A timed callback from the prior attempt must never damage the next attempt.

## Arena and coordinate mapping

The Lab viewport is 720 ×1280; its initial fight rectangle is `Rect2(40, 220, 640, 760)`. The main `SlimerotBossArena.gd` currently builds a 900 ×1200 world arena at `SlimerotEncounters.ARENA_ORIGIN`. These are different world geometries, not interchangeable screen coordinates.

Configure the promoted controller's arena from the real arena's playable bounds, converted once to world space. Replace the Lab controller's hard-coded initial rectangle and start coordinates with arena-supplied values. Boss positions, shot origins, hazard endpoints, prediction and collision must all use that same world space. Keep UI/camera offsets out of combat geometry.

Prefer one world-pixel scale for movement, Dash distance, hit radii and warnings. Do not independently stretch X and Y: that would turn circles into ellipses while circular collision still assumes a circle. Either preserve the learned arena dimensions inside the production arena, or re-author arena-relative positions and tune distances/speeds for the larger floor. Re-run escape-time and safe-path checks after either choice. Admin's final inset must shrink the playable bounds and player wall/clamp constraints together, with visible warning and a harmless relocation if needed.

Arena art and decorations must match usable collision bounds. Cleaning Cart is a moving damage rectangle; making it a solid physics obstacle is an additional mechanic that needs trap/path validation. Warnings must remain readable above floor art, below HUD, and visible during darkness, camera movement and phase effects.

## Slime attacking, rewards and progression

Keep `scripts/managers/SlimerotCombatManager.gd` as the player-team damage authority. Its equipped-copy attack timers, target selection, projectiles and `InventoryManager.damage_for_copy(..., true)` already represent real slime progression. Do not port the Lab session's synthetic three-slime DPS clock, `LOW/EXPECTED/HIGH` presets or unconditional damage ticks into the game.

Expose the promoted boss to existing targeting through `slimerot_enemies` / `slimerot_bosses`, the expected `dead` flag and the existing damage method. Forward accepted slime projectile damage to the new controller's `take_damage()` exactly once. Preserve boss-only damage bonuses and existing projectile ownership/friendly-fire rules. The main pool has different responsibilities and capacity; use a reviewed hostile encounter pool or extend it to support orbiters/hazards, without letting Lab pool code start damaging unrelated normal enemies.

Keep `SlimerotBossArena.finished`, arena retreat/death handling, `WorldManager.boss_active`, `WorldManager.finish_boss_reward(zone_id)` and the existing combined gate flow. Connect one authoritative defeat signal to that reward path and protect it from duplicate callbacks. Boss Lab selection, attempt records and retry are not substitutes for production campaign state. Do not alter roll commits, RNG, saves, wallets, Breakthroughs, zone luck, skill nodes or team slots as part of transferring an encounter.

Lab HP is provisional and tuned to a fixed test team. Current expected-DPS scripted durations of approximately 122/132/132/153 seconds include phase-transition behavior; they do not establish final campaign HP. Measure actual equipped-team damage, range uptime and damage bonuses at each production encounter before selecting its final HP. Difficulty should come from learned patterns rather than compensating for integration differences with excessive HP.

## Presentation hooks and files to leave in the Lab

Map `context.fx()` / `shake()` and boss hit/death/phase feedback to `SlimerotCombatFeedback`, `SlimerotAudio` and production accessibility/settings preferences. Preserve capped pools, clear source labels and accurate debug geometry. Use approved local assets; retain the user's existing slime artwork. Update project resource paths and UIDs through Godot import, then verify a packed export rather than relying on editor cache.

Leave `boss_lab/project.godot`, `lab/BossLabSession.gd`, the selection menu/HUD/joystick, practice controls, local attempt metrics, synthetic team beams, capture tools and Lab test-entry flags in the standalone project. None of those should become main-game autoloads or ship as new game menus. Main player saves must not read or write the Lab's `user://boss-lab-attempts.json`, and Lab retries must not trigger production rewards or save changes.

## Promotion checklist and grading

Grade each candidate on distinct axes: warning clarity, collision accuracy, valid escape routes, movement/Dash demand, attack variety and repetition, phase escalation, overlap readability, recovery cadence, punishment versus player survivability, mobile readability, performance, and repeated-attempt enjoyment. Keep per-axis notes rather than collapsing these into one automated pass. Human first-clear attempt targets need actual tester feedback; scripted clears are not human learning data.

Before promotion, collect manual feedback in Normal mode across multiple attempts, including a small phone screen and Android touch/Dash play. Record which attack kills the player, whether the rule was understood, whether an available response existed, and whether circling or edge camping trivializes the encounter. Re-tune weak patterns in Boss Lab, retaining comparison seeds and metrics. No current report claims a human first-clear attempt distribution.

For the scoped main integration, require:

- Accurate warning/hitbox tests at arena edges, corner cases and multiple player radii; moving walls, rectangles, orbit release locks, sweep directions and annular boundaries must agree with visuals.
- Reachability and connected-path checks for every phase and authored pair, including a player with Dash on cooldown; warning time and control fields must permit a valid response.
- Phase jump, defeat, retreat, pause, death and rapid retry cleanup tests, including interruptions during pending combinations, teleports and darkness.
- Real equipped-slime damage/targeting checks; one reward, one gate transition and compatible existing saves.
- Capped projectile/hazard/FX usage and stable nodes/memory through prolonged late-phase stress and repeated arena entries.
- Rendered phone-aspect verification, packed export validation, Android hands-on feedback and the existing main Slimerot regression suite.

The current Lab automated/rendered checks and constant-node stress results are useful baseline evidence, not a promotion approval. Transfer one approved encounter at a time on a review branch, preserve an easy way to compare the previous encounter, and describe the gameplay change and remaining manual findings in its pull request.
