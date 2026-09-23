# Prompt 15 — combat, Dash, bosses and world presentation

Built on Prompt 14 (`c649bda804e62998b10dc31232a38f46e7eff945`, PR #16). That UI PR was still open at publication preparation; this branch includes its changes. Prompts 11–13 managers remain the authority for inventory, rolling, progression and luck. No slime artwork, RNG formulas, skill prices, currencies, XP, boss HP or rewards were replaced.

## Boss-by-boss changes

| Boss | New pattern | Readability / recovery | Preserved rewards |
|---|---|---|---|
| Espresso Golem | 3s chase → 0.8s slam warning → impact → separately warned second slam → locked charge lane | 0.65s second windup, 1s charge warning with capsule end caps, up to 360px charge, 1.25s recovery; free Dash tutorial before entry | 3,000 HP; 16 contact / 24 impact; 1,000 Coins + Lucky Soda |
| Sand Router | Five-shot fan → vertical beam → perpendicular sweep | 0.8s locked fan rays; 1.05s beam and 0.9s sweep warnings; identical warning/damage rectangles; 1.4s recovery | 50,000 HP; 35 contact / 50 shot or beam; 20,000 Coins + Hyper Soda |
| Backrooms Janitor | Distort/fade out → destination marker → fade in → two aimed bursts → shifting safe columns | 0.35 / 0.65 / 0.40s teleport stages, then separate 0.65s burst windups; arrival has no contact damage; 300px safe corridor | 260,000 HP; 65 contact / 80 shot or beam; 350,000 Coins |
| Singularity Admin | Fan → animated teleport → aimed bursts → crossing beams → recovery | At 40% HP, seven-shot fans and faster chase; locked 1.2s circle warnings only during recovery, avoiding overlapping teleport/beam attacks | 2,000,000 HP; 110 contact / 140 shot or beam / 170 circle; 6,000,000 Coins + completion portal |

Boss phase transitions advance at most one state per tick, preventing a slow frame from skipping a complete warning. Teleport destinations choose a deterministic point away from the player. Arenas preserve open movement space, wall collision and retreat reset. Warning geometry/projectiles are cleared on every arena exit; active Dash is cancelled before moving the player back to the world gate.

## Combat and Dash

- `SlimerotCombatFeedback` provides player-hit, enemy-hit/death, boss-hit and Dash hooks. Accepted player damage produces one short camera event and a flash, without pausing controls. Screen-shake settings are respected.
- Projectiles have a tapered trail, outlined diamond core, short spawn scale and impact burst. Zone colors distinguish hostile shots. Friendly slime shots retain their committed target/straight-flight contract.
- Collision layers are world 1, player 2, normal enemy 4, boss 8. Normal Shooter rays use mask 7 and exclude their source; boss shots use mask 3. Friendly fire deals `round(target.max_hp * 0.20)` through the ordinary guarded death/reward hook. Bosses cannot receive it.
- Dash unlocks free when approaching/using the Z2 progression gate, before Espresso. Touch has a dedicated button between joystick and ROLL; Q is the desktop action. Movement input aims the burst; stationary Dash uses the last facing.
- Dash is 0.16s at 1,500px/s (240px unobstructed), one-second cooldown measured from start, wall-swept `move_and_slide`, and invulnerability only during the active burst. The final tick is scaled to avoid excess distance. Player world rotation remains zero.
- Boss combat never stops Auto Roll. Reveals become a small card in the existing currency-header strip, with no fullscreen dim, portrait, rays or reveal camera shake. The central arena and boss warning text remain visible; zone-unlock banners hide during boss combat.

## Combined gates and saves

Each boss zone now has one progression gate. Before the first clear it starts the encounter after the existing kill requirement; after clear it becomes onward travel using the original Coin cost and gate purchase rules. The existing `boss_defeated_flags` remain authoritative. There is no separate physical boss entrance. Final Admin clear turns the same gate into the completion portal.

Schema 11 remains in use. `dash_unlocked` is an additive boolean. Existing supported saves missing it migrate to unlocked if they have reached Z2; earlier saves earn it at the gate. Explicit saved flags are preserved and malformed non-booleans are rejected. Nothing refunds skills or changes roll ledgers. Dash cooldown/in-progress movement is transient and resets on travel/load; the permanent unlock and boss/gate flags persist.

A new zone unlock emits presentation once only when `highest_zone_unlocked` increases. The next arrival shows its name and `Zone Luck xN`, with a camera/particle beat and gate opening ring; the existing gate-purchase sound hook plays. Revisits do not emit it. Presentation never writes a luck multiplier: the central Prompt 13 luck function continues deriving the Prompt 12 zone factor once.

## Assets and performance

41 original local SVGs: **32 zone assets** (obstacle, rock, prop and border in all eight zones) plus **nine structures/gates** (Shrine, Sell Terminal, Potion Bench, Fast Travel Pillar, Variant Shrine, closed/open gate, boss gate, completion portal). The [exact asset manifest](Slimerot-Prompt-15-Assets.md) lists every file and zone theme. Existing user slime art and prior art source files are untouched. Projectile cores/trails, particles, Dash ghosts, beams, warning rings and arena tiles are procedural drawings.

Projectiles are preallocated in a fixed **128-node pool**. Inactive nodes have physics disabled; saturation drops a new shot instead of allocating more. Practical boss fans are five/seven bullets and bursts three. Feedback uses **one drawing node with 48 reusable effect records**; player trails use at most eight records. No hit/death adds scene nodes. Zone art is cached and drawn without extra prop nodes. The 1,000-projectile stress reuses a single pool slot with zero node growth; the existing 1,800-lifetime endurance suite and 100 closed-Team Auto Rolls remain covered. Target-phone FPS, thermal behavior and battery use are not claimed.

Optional zone behavior is deliberately modest: existing Shooter data can supply `behavior_modifier.projectile_speed`. Z3 uses 1.10x, Z4 0.90x, Z7 1.15x, Z8 1.10x; other zones remain 1x. No new archetypes or status systems were introduced.

## Validation

- **1,943 full headless checks**, zero failures or Slimerot script errors.
- **106 focused rendered combat checks**, zero failures; screenshots inspected for all four bosses and compact combat reveal.
- **223 isolated exported-resource checks**, zero failures; all 41 new SVGs and feedback script present, developer tools excluded. Packed main scene completed 120 frames.
- Existing UI regression covers 720×1280, 720×1560 and 800×1280, modal cycling, touch isolation and closed-Team allocation stability.

| Required checks | Evidence |
|---|---|
| 1–2: one player camera event; enemy particles | Accepted damage event counters, active flash and fixed effect records |
| 3: 1,000 projectile lifetimes without leaks | Stable manager node count, one reused instance, zero active shots; saturation cap |
| 4–7: normal friendly fire, 20%, self exclusion, boss immunity | Real physics rays: 203 max HP → 41 damage; one guarded reward; boss layer untouched |
| 8–10: walls, cooldown, active-only i-frames | Real CharacterBody2D wall test, exact 240px unobstructed travel, one-second timing, post-burst damage |
| 11–13: warnings, animated teleport, exact beams | Full phase/windup timing, locked geometry, opacity stages and exact finite rectangle edge tests |
| 14–15: reset and reward once | All four arenas reset bullets/geometry/HP; repeat damage/finish cannot repay |
| 16–18: combined gate before/after and save reload | Physical gate count, pre-clear encounter route, disk save/reload, post-clear next zone |
| 19–20: luck once and first unlock once | Z2→Z3 total luck ratio 1.5, one event, revisit silent |
| 21–22: Auto Roll and unobscured patterns | Real roll commits while boss active; jackpot card constrained to existing top header |

The focused suite also injects a real second-finger Dash touch while joystick remains held, verifies retreat cancels Dash, checks legacy/malformed saves and prevents reveal camera shake in fights. Runtime test artifacts, screenshots, logs and export packs stay outside published source.

## Provisional decisions

Dash tuning, warning/recovery times, beam duration (0.40s), 74px narrow lanes, Janitor 300px safe gap, final-phase cadence and the four speed modifiers are provisional playtest numbers. Existing HP, damage upgrades and rewards still allow overgearing; no forced damage scaling was added. Physical Android input/device performance and less-skilled human difficulty testing remain outstanding. APK signing/installation has not been performed; validation uses the Android preset's resource pack and desktop touch-event simulation.

## Changed files

The 82 environment entries are the 41 SVGs in the linked manifest plus their matching Godot `.svg.import` settings. Other changed files:

- `Slimerot-README.md`
- `docs/Slimerot-Prompt-15-Assets.md`
- `docs/Slimerot-Prompt-15.md`
- `docs/Slimerot-Testing.md`
- `project.godot`
- `scripts/data/SlimerotCampaign.gd`
- `scripts/data/SlimerotData.gd`
- `scripts/managers/SlimerotCombatManager.gd`
- `scripts/managers/SlimerotGameState.gd`
- `scripts/managers/SlimerotSaveManager.gd`
- `scripts/managers/SlimerotWorldManager.gd`
- `scripts/presentation/SlimerotAssets.gd`
- `scripts/presentation/SlimerotCombatFeedback.gd`
- `scripts/presentation/SlimerotCombatFeedback.gd.uid`
- `scripts/ui/SlimerotHUD.gd`
- `scripts/ui/SlimerotReveal.gd`
- `scripts/world/SlimerotBoss.gd`
- `scripts/world/SlimerotBossArena.gd`
- `scripts/world/SlimerotEnemy.gd`
- `scripts/world/SlimerotPlayer.gd`
- `scripts/world/SlimerotProjectile.gd`
- `scripts/world/SlimerotWorld.gd`
- `scripts/world/SlimerotZone.gd`
- `tests/SlimerotBalanceTests.gd`
- `tests/SlimerotBossPresentationTests.gd`
- `tests/SlimerotBossPresentationTests.gd.uid`
- `tests/SlimerotCampaignTests.gd`
- `tests/SlimerotCombatPresentationTests.gd`
- `tests/SlimerotCombatPresentationTests.gd.uid`
- `tests/SlimerotCombatTests.gd`
- `tests/SlimerotDashTests.gd`
- `tests/SlimerotDashTests.gd.uid`
- `tests/SlimerotEncounterTests.gd`
- `tests/SlimerotEnduranceTests.gd`
- `tests/SlimerotFinalIntegrationTests.gd`
- `tests/SlimerotTests.gd`
- `tools/SlimerotExportAudit.gd`
