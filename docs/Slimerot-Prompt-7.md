# Slimerot Prompt 7 implementation

Continued from `main` commit `c87e9a9aa438d33d9c4ee141b9bc356e65092867` (Prompt 6 merge). The origin was verified as `https://github.com/kristijannema-ai/Slimerot.git`; a fresh fetch before handoff confirmed main had not advanced. Gameplay progression, currency/rolling math, roster, saves, combat, zones and boss mechanics remain intact. No Prompt 8 feature was added.

## New files

- `scripts/data/SlimerotPresentation.gd`: exact reveal tiers/durations, mobile touch tuning and short Breakthrough duration.
- `scripts/presentation/SlimerotAssets.gd`: cached optional artwork/audio resolution.
- `scripts/presentation/SlimerotAudio.gd`: exploration/boss music, eight bounded effect voices, settings and event hooks.
- `scripts/ui/SlimerotSkillConnections.gd`: visible prerequisite paths.
- `scripts/ui/SlimerotTeamSlot.gd`: actual drawn chain/lock overlays.
- `tests/SlimerotUXTests.gd`: 200 additional UX/media assertions.
- `tools/SlimerotGeneratePlaceholders.py`: reproducible original art and melody generator.
- `assets/art/`: 80 SVGs: 24 slimes, one player, 24 enemies, four bosses, eight ground themes, nine structure/gate/portal sprites, ten icons.
- `assets/audio/`: ten WAVs, including two looping tracks and eight cues.
- Godot `.uid` and asset `.import` sidecars for these new resources.
- This report and `docs/Slimerot-Assets.md`.

## Modified files

- `project.godot`: expanding portrait canvas and presentation audio autoload.
- `scripts/managers/SlimerotRollManager.gd`: shared tier tuning; preserve active durations; coalesce/bound pending repeated feedback.
- `scripts/managers/SlimerotSlimeDatabase.gd`: canonical sprite paths and shared tier lookup.
- `scripts/ui/SlimerotHUD.gd`: safe-area-aware layout, wallet/icons, compact contextual interaction, touch scrolling, multi-touch input, navigation/back, cached team portraits, brief Breakthrough banners.
- `scripts/ui/SlimerotJoystick.gd`: exact 90 px touch acquisition and transformed pointer coordinates.
- `scripts/ui/SlimerotMenus.gd`: cohesive cards, five Team slots, prerequisite graphs, gated controls, live stats/save status, sound sliders, cancellable reset hold.
- `scripts/ui/SlimerotPortrait.gd`: original sprite rendering, flat silhouettes, variants, idle bob and attack squash support; clipped/offscreen animation skips.
- `scripts/ui/SlimerotReveal.gd`: distinct toast/card/large/full-width/jackpot treatments, responsive sizing, pulse, bounded sparkles and skip protection.
- `scripts/world/SlimerotPlayer.gd`, `SlimerotEnemy.gd`, `SlimerotBoss.gd`, `SlimerotWorld.gd`, `SlimerotZone.gd`: presentation-only sprites, hit feedback, existing projectile/attack hooks, themes and structures. Collision and combat rules are preserved.
- `tests/SlimerotTests.gd`: responsive touch coordinates and new suite integration.
- `Slimerot-README.md`, `docs/Slimerot-Testing.md`: current implementation and validation notes.

## Validation

Official Godot 4.5.1 on Windows. Original Prompt 6 baseline: **644 checks passed**. Combined Prompt 7 suite: **844 checks passed, 0 failures**, headless and rendered with the OpenGL compatibility renderer. Tests use isolated per-process saves under `.godot`; real player saves are not altered.

The suite exercises real Godot scene nodes and dispatched touch input: simultaneous joystick + ROLL, exact joystick boundary, nearby INTERACT, touch Collection scrolling, dragging from a Favorite button without activating it, subsequent tapping, sound slider movement, hold-reset cancellation by leaving/focus loss/Back, Android Back notification navigation, fresh and unlocked menu gating, all 24 Collection cards, five-slot Team, both prerequisite graphs, exact tier boundaries/deadlines, first/repeat jackpot touch skipping, bounded feedback queues and all three actual ×20 Breakthrough purchases.

Viewport checks and rendered captures cover 720×1280, 720×1440 and 800×1280 with simulated safe insets. Art loading, transparent 256px slime dimensions, all enemy/boss/theme/structure/icon families, optional missing paths, audio gain multiplication and music loop settings are checked. Existing save migration/recovery, rolling math, progression, combat, campaign, boss, potion and mutation assertions remain green.

Rendered Collection, Team, skill tree, world, boss, jackpot and phone-layout screenshots were inspected for readability and bounds. Source scans confirm that **no Braincells Lost stat exists**; intentional Brainrot content names are retained.

## Manual device checks remaining

1. Export with matching Godot templates, Android SDK/JDK and signing configuration; install on a midrange ARM64 phone.
2. Hold joystick with one finger while repeatedly rolling with another; verify real cutout/navigation-bar bounds.
3. Scroll each menu, use volume sliders, test hardware Back, background/resume and reset-hold cancellation.
4. Check speakers/headphones and long-session frame pacing during boss fights and high-luck Auto Roll.

Physical Android/APK validation was not available. Supplied art and audio are safe, replaceable placeholders, with replacement paths documented in `Slimerot-Assets.md`. Engine host warnings about the root certificate store and restricted shader-cache location are unrelated to Slimerot scripts. Full campaign pacing and physical device performance remain later-stage playtests.
