# Boss Lab validation

Godot 4.5.1, Windows desktop, GL Compatibility. These are technical/runtime measurements of the experimental Lab, not evidence of human first-clear rates or physical Android performance.

Final integrated result: **1,398 checks, zero failures** in both headless and rendered runs. Seven final rendered captures cover selection, all four encounters, Tools and the result card. The standalone release pack contains 120 verified entries, with no test files, Markdown or main-game scripts, and boots for 120 frames in an empty scratch project.

## Acceptance matrix

| # | Requirement | Result and evidence |
| ---: | --- | --- |
| 1 | Independent launch | Pass: own project imports and launches; its exported pack also boots in an otherwise empty scratch project. |
| 2 | Main game launches | Pass: main imports and runs 120 headless frames with isolated estimate-mode save behavior; no script errors. |
| 3 | Main independent of Lab | Pass: no modified main-game files, no BL classes in its class cache, and all 442 exported main pack entries have verified hashes with zero Lab paths. |
| 4 | Four bosses selectable | Pass: all four Resources load; selection and complete HP-driven encounters exercise each. |
| 5 | Retry under ~1 second | Pass: direct Retry, actual viewport touch Retry and keyboard R return immediately without a scene reload; node count stable. Prior sound/shake reset. |
| 6 | Dash works | Pass: actual CharacterBody2D travel ~240 px, cooldown, active immunity, wall collision and simultaneous joystick/Dash touches. |
| 7 | Automatic Expected DPS slimes | Pass: three visible representatives deal 150 stable total DPS; all real phases clear in the target duration under God practice. |
| 8 | Accurate tells/hitboxes | Pass technically: shared drawing/collision geometry for circles, capsule lanes, rectangles, sweeping sectors, rings, moving gaps and annuli; no early damage. Rendered captures reviewed. Phone readability still needs feedback. |
| 9 | Distinct identities | Design/runtime review: rhythmic melee/charge, route weaving, teleport/memory/control, gravity/arena manipulation. Human comparative review pending. |
| 10 | Harder late phases | Pass technically: real HP thresholds add stronger geometry, denser fans, faster recovery and authored pairs; Admin has four phases and warned final inset. Difficulty ranking requires people. |
| 11 | Authored combinations | Pass: six explicit external pairs, phase gating, light partner variants, at most two active modules; no arbitrary combinations. |
| 12 | No obvious unavoidable attacks | Sampled geometry and reachability review passes: safe cells, broad connected routes, locked aim, minimum warnings, immunity/grace and bounded control forces. Sampling does not prove every human trajectory is fair. |
| 13 | Active pacing | Pass technically: recovery 0.16–0.45 s, attacks retain active projectile flight, phase change 0.9 s. Human boredom/pressure feedback pending. |
| 14 | Practice works | Pass: God, slow speed, practice DPS, display controls; Normal denies cheats. |
| 15 | Hitbox debug | Pass: toggles the actual hazard and projectile geometry. |
| 16 | Phase jumping | Pass: touch controls force HP/phase, clamp phase count and clean prior effects. |
| 17 | Attack forcing | Pass: named selection and Force start the real module; required phase is selected. Normal disallows it. |
| 18 | Killing attack report | Pass: actual lethal hit records source, duration, phase, remaining HP, hits and Dashes; result capture reviewed. |
| 19 | Local statistics | Pass: mode separation, attempts/wins/mean/pre-clear best HP, damage attribution, first clear, 500-detail cap, bounded all-time aggregates and save recovery. |
| 20 | Portable boss code | Pass for separation: core/data/move modules have no UI/history/main-game imports; adapter plan maps all 25 moves. No port has occurred. |
| 21 | No uncontrolled node growth | Pass: fixed pools, full fights and 100 Admin final-phase retries preserve exact scene population and bounded memory. |
| 22 | No parser/runtime errors | Pass: final headless/rendered suite and standalone packed smoke; known host certificate/Android SDK setup messages are outside the encounter scripts. |

## Test methods

`tests/BossLabTests.gd` executes actual `BLSession`, `BLBossController`, `BLContext`, `BLPlayer` and pools. Geometry boundary checks validate the same formulas used to draw attacks. Pattern tests run phase-eligible modules and combinations, assert cleanup/phase/scheduler behavior, and verify Resource overrides reach actual collision/projectile values. UI tests inject Godot viewport ScreenTouch/InputEventKey events, including two simultaneous fingers, 21 modal cycles, Android Back notifications and rapid Retry feedback cleanup. They inspect control containment at 720×1280, 720×1560 and 800×1280. Metrics tests use an isolated workspace history file.

The suite simulates four complete Expected-DPS fights at 60 Hz with practice invulnerability, then 100 final-phase Admin orbital retries: 50,429 actual backend ticks. The headless and rendered runs repeat the same checks; their totals should not be added as independent coverage. Projectiles and effects use fixed dictionary slots, not scene nodes per item.

Extra Janitor/Admin phase/combo probes executed 39 individual casts and seven phase-eligible pairs, with 627 checks and no failures before the final lifetime pass. Final integrated pattern coverage executes 130 casts across all four bosses, six authored pair cases and 2,952 sampled safe-cell checks. These are sampled checks, not exhaustive pathfinding proofs. Late-volley regression checks also verify damaging shots survive long enough to reach distant players before owner cleanup.

## Desktop measurements

Measured full fights at Expected 150 DPS include phase-transition protection. Duration: Espresso 122.40 s, Sand 132.40 s, Janitor 132.40 s, Admin 153.28 s. Each real encounter visits every phase. The final scene population is 152 nodes throughout, including the arena visual clip control; no node is created per shot or hazard.

The final headless run took 536/589/508/714 ms of accelerated simulation for those four fights. The final rendered run took 269/304/257/363 ms. These timings run many 60 Hz simulation steps within a desktop process and are **not real-time FPS or device GPU benchmarks**. Rendering capture tests separately inspect the real viewport. Full-fight peaks were Espresso 12 hazards/21 projectiles, Sand 7/10, Janitor 5/6 and Admin 5/14; each peaked at 36 cosmetic effects.

The first headless boss allocated about 0.55 MiB including caches; subsequent fight retention was about 29 KiB each. Rendered full-fight retention was about 39 KiB per boss. One hundred Admin retries retained less than the 3 MiB test bound, with unchanged node count and capacity bounds. Memory differences include engine caches and cannot substitute for physical mobile profiling.

## Moving runtime exploit probes

Thirty-six Normal attempts ran the actual moving CharacterBody2D, damage, Dash cooldown, scheduler and phase logic: stationary, circular movement, and circular movement with Dash whenever ready, three seeds per boss. All 36 died before victory. Circular players travelled thousands of pixels; they were not static geometry stand-ins.

| Boss | Circle survival | Circle + cooldown-Dash survival |
| --- | --- | --- |
| Espresso | 15.9–26.4 s | 26.2–44.9 s |
| Sand | 42.6–51.8 s | 46.9–53.2 s |
| Janitor | 19.2–50.7 s | 36.0–118.3 s |
| Admin | 18.4–72.6 s | 55.7–93.5 s |

These measurements were taken before the final late-volley lifetime improvement. The longer projectile tails fix premature disappearance; the prior survival ranges are retained as dated iteration evidence, not silently relabeled as final balance. Further adaptive human testing should evaluate intentional dodging rather than unchanging circle movement.

Iteration corrected one-frame repulsion, early projectile cleanup, unreachable route selection, sector-direction preview, misleading wall-gap outlines, overly bright desert decoration, overlapping arena warning labels, stale Retry feedback and second-finger Dash. Darkness and opacity restore on interruption; all effects are clipped to arena bounds.

## Export, isolation and test limits

Both projects exported pack resources with their own presets. An offline directory/hash audit uses the [Godot 4.5 pack reader format](https://github.com/godotengine/godot/blob/4.5-stable/core/io/file_access_pack.cpp). The main pack contains no Lab entries; the Lab pack excludes tests and Markdown and has no main-game scripts. An empty-project packed smoke checks standalone runtime dependencies. No pack/build/log/capture is committed.

The host has reported an unavailable Android build-tools directory, a root-certificate-store error and an unavailable shader-cache directory. These are environment setup messages; pack export and runtime checks succeed. No Android APK, signing, installation or physical phone benchmark is claimed. A native desktop automation launch approval timed out; no human-controlled full playthrough is claimed. Testing used actual rendered Godot, runtime movement bots, viewport input events and inspected screenshots.

Human fun, fairness across different starting positions, new-player attempt ranges, skilled-player attempt ranges and the final comparative difficulty ranking remain unmeasured. Normal metrics provide the data collection path for those sessions. Do not promote these experimental encounters into the main game on automated results alone.
