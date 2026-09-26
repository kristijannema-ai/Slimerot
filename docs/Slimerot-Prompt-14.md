# Slimerot Prompt 14 — mobile interface

> **Historical record — Prompt 16:** Historical Prompt 14 report. Its UI map and backend-authority rules remain current; Prompt 15 adds the separate Dash control, combined gates and compact boss-combat reveals. Current final acceptance is recorded in Prompt 16; test counts below describe Prompt 14 only.

Prompt 14 replaces the crowded HUD, global eight-button menu navigation and vertical skill lists with a compact HUD, a Team hub, consolidated Settings and a pannable 2D skill tree. It builds on merged Prompt 13 (`3a340b483959813c28d0a2f58e6346bdce5cd304`). Backend manager and data files from Prompts 11–13 are unchanged; saves remain schema 11.

## Old screen → new screen

| Previous entry | Prompt 14 destination |
| --- | --- |
| Inventory HUD button | **TEAM**, the main slime hub |
| Separate Team view | **Team → TEAM**: equipped slots, DPS, Equip Best, owned stack list |
| Collection in global/Info-style navigation | **Team → COLLECTION** |
| Potions HUD button | **Team → ITEMS**; Potion Bench opens the same tab |
| Separate Roll Settings | **Settings → ROLLING** |
| Settings / Pause | **Settings**, with GENERAL, ROLLING and SAVE / SYSTEM sections |
| Stats in global navigation | **Settings → Stats / About**, a child modal |
| Eight global navigation buttons on every menu | Three contextual Team tabs; other screens have one Close or Back control |
| Skills vertical list and optional-branch toggle | **SKILL TREE**, with Roll/Coin canvases, all optional branches visible beside the trunk |
| Full skill card in a scrolling list | Tap a graph node → **upgrade details** → Buy → return to preserved graph view |
| Inventory copy manager | **Team → stack → Manage copies**, bounded to 12 copies per page |
| Sell Terminal / duplicate sale | **Team → Sell spare copies**, available after repair |
| Fast Travel HUD entry | **MAP**, shown only after the Fast Travel Pillar is repaired |

The old navigation grid served the redundant Info role; it is removed. No empty Info or legacy navigation tabs remain. Internal `Inventory` and `Roll Settings` calls resolve to Team and Settings for compatibility with world interactions and existing integrations.

## HUD and screen behavior

The top contains HP, zone, Coins, Rolls, Luck and the Settings icon. Three evenly sized currency chips replace the multiline wallet panel. The lower utility row contains Team, Shrine-gated Skill Tree and repaired-Pillar-gated Map. Joystick remains bottom-left; ROLL and unlocked quick Auto remain bottom-right. The Super countdown is a compact single line. Persistent tutorial copy, the separate Potions button, Inventory entry and redundant HUD team portraits/DPS panel are removed.

Team shows five slot positions with backend locks, the actual equipped team and DPS, Equip Best, sorting and one card per unique slime/variant stack. Each card shows `xN`, damage, DPS, variant flags, rarity, favorite status and equip/unequip actions. Optional individual-copy management retains per-copy protections and bounded pagination; the main view never creates one card per physical copy. Collection retains all 24 bases and discovery history. Items contains crafting, bottles, consumption and live effect timers.

Settings pauses active gameplay as before. GENERAL contains music/master/SFX volume, screen shake and vibration. ROLLING contains Auto, Auto Sell, filters, Luck Cap and reveal information according to backend unlocks. SAVE / SYSTEM contains visible save status, Stats/About and the existing cancellable three-second reset hold. Quick Auto remains available during ordinary gameplay.

The Prompt 11 modal stack remains authoritative. Root screens have one Close button; details, Stats/About and copy management have one Back button. Android Back removes only the top layer, preserving any underlying Settings pause. Disposed overlays are removed from the tree immediately. Touch picking respects ancestor clipping and ignores passive controls, so off-canvas skill nodes cannot steal taps from zoom controls or gameplay. App focus loss/suspension cancels in-flight graph gestures.

## Theme, icons and world labels

`assets/ui/SlimerotTheme.tres` is the central Godot Theme, configured in `project.godot` and shared by HUD, menus, graph and captions. The palette uses deep purple, warm cream, lime and gold with thick rounded buttons, visible pressed states and clear contrast. Touch controls use a 64-pixel virtual minimum. Typography uses a consistent title/section/body/caption hierarchy and local system-font fallback, without downloading fonts.

Reusable variations: `PrimaryButton`, `SecondaryButton`, `IconButton`, `TabButton`, `ModalPanel`, `Card`, `CurrencyChip`, `SkillNode`, `LockedSkillNode`, `PurchasedSkillNode`, `BreakthroughSkillNode`. Slider tracks, filled ranges and large thumb textures also live in this resource. Per-card variant colors duplicate the central style before tinting it, so one card cannot mutate other controls.

Nine original local SVGs were generated under `assets/ui/icons/`:

| File | Purpose |
| --- | --- |
| `Slimerot_team.svg` | Team / old Inventory alias |
| `Slimerot_collection.svg` | Collection |
| `Slimerot_potions.svg` | Items / Potions |
| `Slimerot_skills.svg` | Skill Tree |
| `Slimerot_settings.svg` | Settings |
| `Slimerot_map.svg` | Fast Travel |
| `Slimerot_roll.svg` | Roll / Rolls |
| `Slimerot_coins.svg` | Coins |
| `Slimerot_luck.svg` | Luck |

Their `.svg.import` files are small source import settings. Existing slime artwork and all original art assets are unchanged; no external asset pack was downloaded.

Shrine, Sell Terminal, other structure and gate labels use passive centered Labels with full-rect anchors inside landmark-sized frames. Their width and position derive from landmark bounds instead of text-length guesses or resolution-specific baselines. Frames and labels ignore pointer input.

## Skill-tree canvas and backend authority

`SlimerotSkillTreeCanvas` lays out a winding central Roll trunk with convenience branches on the left and the full Super branch on the right. Auto Roll appears before Luck I. The Coin canvas groups damage/slots, normal Coins, Toughness, Fortune, boss/sale and speed branches, including the R18 cross-tree prerequisite. All lines come from the canonical prerequisite arrays. Future definitions without authored coordinates still receive an overflow position instead of disappearing.

One-finger drag pans; two Android-style touch contacts pinch around their centroid. Mouse drag/wheel, minus/plus and Fit provide alternatives. Zoom is clamped to **0.55–1.8**. Fit shows the full authored graph at standard phone dimensions. Purchased, available, locked and Breakthrough nodes have separate styles. A tap opens details only on release without a drag/pinch, and canceled touches cannot buy or select a node.

Details show name, effect, currency, price, skill/world prerequisites and current → new stats. Previews call `SkillTreeManager.derived_stats()` with the proposed ID list and `RollManager.get_effective_luck()` with explicit context. The Buy action delegates to `SkillTreeManager.purchase()`. No luck, progression, price, damage or unlock formula was reimplemented in the UI. Returning from details preserves pan/zoom after the new canvas receives its actual container layout.

## Refresh and performance

HUD notifications are coalesced into the next frame. Visible menu changes are debounced to 0.4 seconds and compared with a signature of relevant displayed data. HP changes do not rebuild Team; changes to wallet/unlocks update graph states and labels without rebuilding graph nodes or resetting the camera. Stats and active timers update existing labels. Closed screens have no card refresh or construction work. Inventory signatures scale with unique stacks rather than physical quantity.

The focused test uses a 100,003-copy stack plus another variant and verifies exactly two owned-stack cards. It also performs 100 genuine Auto Roll completions with Team closed and verifies unchanged HUD node count and zero menu rebuilds. These are deterministic desktop checks, not measurements of physical-device frame rate or battery use.

## Validation

| Check | Result |
| --- | --- |
| Full regression suite | **1,837 checks passed; 0 failures** |
| Focused rendered mobile UI suite | **68 checks passed; 0 failures** |
| Isolated exported-resource audit | **178 checks passed; 0 failures** |
| Packed main scene in an empty scratch project | **120 frames completed**, no Slimerot script errors |
| Godot editor import | No script/parser errors |

The 68 focused checks cover all 20 requested requirements, including real viewport touch dispatch for Team tabs, pan, pinch, zoom buttons, Fit, node details and Buy. They also cover distinct node states, exact 25/40-Roll purchase accounting, app-suspension gesture cleanup, restored pan/zoom, irrelevant-change debouncing, clipping-aware hit testing and hidden-overlay input. Seven major screen/detail routes each complete 20 touch-driven Close/Back cycles; the prior modal-stack regression matrix remains included in the full suite.

Layouts and captures were checked at **720×1280, 720×1560 and 800×1280**; previous safe-inset/aspect tests remain in the regression suite. Rendered HUD, Team, Collection, Items, Settings, Roll/Coin graphs and node details were inspected. Final console logs are checked for script errors in addition to assertion totals. Android pinch is exercised using Android touch-event types; a physical Android device and APK build have not been tested in this environment. Its existing certificate-store and missing Android build-tools diagnostics remain environmental.

Run the focused tests with:

```sh
godot --headless --path <project> -- --slimerot-test --slimerot-ui-only
```

Omit `--headless` and add `--slimerot-capture` to write local rendered captures under `.godot/`. Omit `--slimerot-ui-only` for the complete regression suite. Generated screenshots, logs, packs, saves and machine reports are excluded from publication and export.

## Changed files

- `project.godot`: central theme registration.
- `assets/ui/SlimerotTheme.tres`: shared styles, typography, sliders and visual states.
- `assets/ui/icons/Slimerot_*.svg` and nine corresponding `.svg.import` files: the nine icons listed above.
- `scripts/presentation/SlimerotAssets.gd`: icon lookup and compatibility aliases.
- New `scripts/presentation/SlimerotUITheme.gd` and `.gd.uid`: shared theme/touch/world-label helpers.
- `scripts/ui/SlimerotHUD.gd`: compact HUD, contextual tabs, clipped touch picking, modal lifecycle and refresh batching.
- `scripts/ui/SlimerotMenus.gd`: Team hub, Settings consolidation, details and visible-data refreshes.
- New `scripts/ui/SlimerotSkillTreeCanvas.gd` and `.gd.uid`: graph layout, connections and gestures.
- `scripts/world/SlimerotWorld.gd`, `SlimerotZone.gd`: centered captions and Team route from Sell Terminal.
- New `tests/SlimerotMobileUITests.gd` and `.gd.uid`; updated `SlimerotTests.gd` runner.
- Updated regression fixtures: `tests/SlimerotUXTests.gd`, `SlimerotStabilityInputTests.gd`, `SlimerotSavePerformanceTests.gd`, `SlimerotRollingTests.gd`, `SlimerotProgressionTests.gd`, `SlimerotSkillTreeTests.gd`.
- `tools/SlimerotExportAudit.gd`: validates exported icons and named Theme variations.
- `Slimerot-README.md`, `docs/Slimerot-Testing.md`, this report.
