# Prompt 16 — complete integration requirement matrix

Scope: the supplied Prompt 12 attachment, Prompts 13–14 in the task, the supplied Prompt 15 and Prompt 16 attachments, and the seven Prompt 11 reported issues retained in `Slimerot-Prompt-11.md`. No separate original feedback document beyond those sources was available; the matrix does not invent unseen feedback. Each retained issue is audited explicitly, including already implemented behavior.

**Evidence state (2026-09-26):** the final desktop regression passed **2,158 checks, 0 failures**. The focused rendered integration passed **215 checks, 0 failures**, including the visible overflow summary and logger regressions. Within these overlapping suites, **164 save-migration checks** passed; the separately orchestrated eight actual Windows process-death/reopen cases passed **261 checks, 0 failures**. These counts must not be added as if they were distinct tests. Detailed evidence is recorded in [Testing](Slimerot-Testing.md), the [save report](Slimerot-Prompt-16-Saves.md) and the [Prompt 16 report](Slimerot-Prompt-16.md).

`AUTO` means the named desktop automated coverage passed in the regression or its separately identified probe. `REVIEW` identifies inspection/documentation evidence in addition to tests; it does not assert subjective visual or device acceptance. `PENDING` means final evidence or a deliverable remains outstanding. `MANUAL` means human/device acceptance remains outstanding even where automated or model evidence exists. Every physical Android field is **NOT RUN**: desktop touch dispatch and externally killed desktop processes do not count as Android execution. Overall acceptance remains pending the required device and human campaign validation.

File notation: runtime names expand under `scripts/`: `RollManager`, `InventoryManager`, `GameState`, `SaveManager`, `SkillTreeManager`, `WorldManager`, `CombatManager` = `managers/Slimerot<Name>.gd`; `Roster`, `Balance`, `Variants`, `Pity`, `Presentation`, `RollTree`, `CoinTree`, `Campaign`, `Encounters`, `SaveFormat`, `SuperRoll`, `SkillTreeValidator` = `data/Slimerot<Name>.gd`; `SlimeDatabase` = `managers/SlimerotSlimeDatabase.gd`; `HUD`, `Menus`, `Reveal`, `SkillTreeCanvas`, `Portrait`, `Joystick` = `ui/Slimerot<Name>.gd`; `World`, `Zone`, `Player`, `Enemy`, `Boss`, `BossArena`, `Projectile`, `Interaction` = `world/Slimerot<Name>.gd`; `RollRevealQueue`, `CombatFeedback`, `UITheme`, `Assets`, `Audio` = `presentation/Slimerot<Name>.gd`. Test abbreviations expand to `tests/Slimerot<Name>Tests.gd`, unless a full path is shown. `FinalRestartProbe` means `tests/SlimerotFinalRestartProbe.gd`/`.tscn`, orchestrated by `tools/SlimerotFinalRestartMatrix.py`; `FinalRng`, `FinalSave` and `FinalPacing` follow the normal test expansion. These are actual source paths, not proposed components.

## Prompt 11 stability, input and AFK feedback

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Stationary Bedroom exit responds to one tap | P11 reported issue 1 | World, Interaction, HUD | Yes | StabilityInput | NOT RUN | AUTO |
| No press/release double interaction or spam reentry | P11 reported issue 2 | HUD, World | Yes | StabilityInput | NOT RUN | AUTO |
| Stable Close over repeated cycles; modal Back removes one layer | P11 reported issue 3 | HUD | Yes | StabilityInput, MobileUI | NOT RUN | AUTO |
| Player body/world rotation stays zero | P11 reported issue 4 | Player | Yes | StabilityInput, Dash | NOT RUN | AUTO |
| Large inventory Equip Best does not expand physical copies or repeat unchanged-team work | P11 reported issue 5 | InventoryManager, Menus | Yes | InventoryStress, SavePerformance | NOT RUN | AUTO |
| Android background Auto Roll reconciles elapsed time on resume/relaunch | P11 reported issue 6 | SaveManager, RollManager, HUD | Yes | Offline; actual Android lifecycle pending | NOT RUN | MANUAL |
| Old saves migrate without resetting progression; invalid/future originals protected | P11 reported issue 7 | SaveManager, SaveFormat, InventoryManager | Yes | Persistence, Offline, RngSave, ProgressionSave | NOT RUN | AUTO |
| One background checkpoint shared by pause/focus latches; remainder retained | P11 save/AFK contract | SaveManager, GameState | Yes | Offline | NOT RUN | AUTO |
| Auto OFF earns no rolls; backward clock cannot duplicate interval | P11 save/AFK contract | SaveManager | Yes | Offline | NOT RUN | AUTO |
| Atomic rewards plus consumed timestamp; failed writes retry without resampling | P11 save/AFK contract | SaveManager, RollManager | Yes | Offline, Persistence | NOT RUN | AUTO |
| No offline combat/kills or active potion/playtime decay; compact AFK summary | P11 save/AFK contract | SaveManager, RollManager, HUD | Yes | Offline, Rng | NOT RUN | AUTO |
| Interrupted Reset hold cancels; future save reset requires durable marker | P11 retained safety | HUD, Menus, SaveManager | Yes | StabilityInput, Persistence | NOT RUN | AUTO |

## Prompt 12 RNG, variants, Shrine and reveal feedback

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Exactly +1 spendable Rolls and +1 Lifetime per completed manual/Auto/offline roll; free press | P12 A; L1 | RollManager, GameState | Yes | Rng, Rolling, Offline | NOT RUN | AUTO |
| Separate resolve → one commit → presentation-only queue; duplicate/stale commits rejected | P12 A; L19 | RollManager, RollRevealQueue | Yes | Rng, RngSave | NOT RUN | AUTO |
| All 24 bases rollable from start; zone origin only metadata | P12 B; L2 | SlimeDatabase, Roster, RollManager | Yes | Rng, Campaign | NOT RUN | AUTO |
| Zone factor counts only unlocked gameplay zones; Z1 ×1 and Z8 ×8 | P12 C; L3–4 | RollManager | Yes | Rng, Progression | NOT RUN | AUTO |
| Zone luck not doubled after reload; one central six-component effective luck | P12 C; L5 | RollManager, SaveManager | Yes | Rng, ProgressionSave | NOT RUN | AUTO |
| Three independently sampled flags and all eight combinations | P12 D; L6 | Variants, RollManager | Yes | Rng | NOT RUN | AUTO |
| Base Shiny 1/100, Glitched 1/400, Golden 1/1600 | P12 D; L7–8 | Variants | Yes | Rng | NOT RUN | AUTO |
| Canonical effective rarity multiplies base threshold by all active denominators | P12 E; L9 | SlimeDatabase, Variants | Yes | Rng | NOT RUN | AUTO |
| Raw damage round(6 × rarity^0.32), then team/boss effects | P12 E; L10 | SlimeDatabase, InventoryManager, CombatManager | Yes | Rng, Combat | NOT RUN | AUTO |
| Shiny threshold-2 has rarity 200 and the same raw power as Normal threshold-200 | P12 E; L9–10 | SlimeDatabase, Roster | Yes | Rng | NOT RUN | AUTO |
| All inventory/team/Equip Best/combat/UI use central rarity/damage helpers | P12 E | SlimeDatabase, InventoryManager, Menus, CombatManager | Yes | Rng, InventoryStress, Combat | NOT RUN | AUTO |
| Legacy single variants map to flags 0/1/2/4; quantities/favorites/equipment preserved | P12 F; L11 | SaveManager, InventoryManager | Yes | RngSave, Persistence | NOT RUN | AUTO |
| Unique base/mask stack key; malformed migration preserves original bytes | P12 F | SaveManager, SaveFormat | Yes | RngSave | NOT RUN | AUTO |
| Disable five-Normals-plus-Coins recipe; reuse mutation_lab only as persistent ID | P12 G | InventoryManager, Menus, World, Encounters | Yes | Rng, Encounter | NOT RUN | AUTO |
| Unique sacrificed base IDs per category; duplicate cannot consume another copy | P12 G; L12 | InventoryManager, GameState | Yes | Rng | NOT RUN | AUTO |
| Shrine multiplier 1.05^count; three unique Shiny offerings yield 1.05^3 | P12 G; L13 | Variants, InventoryManager | Yes | Rng | NOT RUN | AUTO |
| One multivariant copy → one chosen active category; no Coin charge | P12 G proposed behavior | InventoryManager, Menus | Yes | Rng | NOT RUN | AUTO |
| Equipped/group-favorite/individual-favorite copies protected from sacrifice | P12 G | InventoryManager | Yes | Rng, InventoryStress | NOT RUN | AUTO |
| Shrine changes sampling chances, never canonical rarity/damage | P12 E/G | Variants, SlimeDatabase, RollManager | Yes | Rng | NOT RUN | AUTO |
| Persist best-ever rarity and misses; sale/sacrifice cannot reset history | P12 H; L16 | GameState, RollManager, InventoryManager, SaveManager | Yes | Rng, RngSave | NOT RUN | AUTO |
| Hidden P_better spans current base-plus-mask distribution; no HUD meter | P12 H | Pity, RollManager, HUD | Yes | Rng; source review confirms no player-facing pity meter | NOT RUN | AUTO |
| Disable pity at P_better ≤0; seeded deterministic valid stronger replacements | P12 H; L14 | Pity, RollManager | Yes | Rng | NOT RUN | AUTO |
| Hard pity deadline ceil(3 × expected); no second reward-granting roll | P12 H; L15 | Pity, RollManager | Yes | Rng | NOT RUN | AUTO |
| Soft ramp starts 1× expected, ends 3×, max 25% | P12 H proposed constants | Pity | Yes | Rng | NOT RUN | AUTO |
| Reveals do not block roll cooldown, Auto Roll, movement or combat | P12 I/K; L17 | RollManager, RollRevealQueue, Reveal | Yes | Rng, CombatPresentation | NOT RUN | AUTO |
| At least five seconds between major sequences, even after skip | P12 I; L18 | RollRevealQueue, Presentation | Yes | Rng | NOT RUN | AUTO |
| Adaptive relevance/surprise/discovery/variant/best-ever tiers replace weak high-luck spam | P12 J; L20 | Presentation, RollManager | Yes | Rng | NOT RUN | AUTO |
| Team improvement meaningful; slightly worse ≥85% weakest also meaningful | P12 J | Presentation | Yes | Rng | NOT RUN | AUTO |
| Distinct Shiny sparkle, Glitched split/jitter and Golden rays; combined layers coexist | P12 K | Portrait, Reveal | Yes | Rng, UX; rendered review | NOT RUN | REVIEW |
| Rare darkness/shake/card/HUD dim outside bosses; respects shake setting | P12 K; P15 E supersedes during bosses | Reveal, HUD, Player | Yes | Rng, CombatPresentation | NOT RUN | REVIEW |
| Offline uses same resolve/commit; no individual cinematics, combined-drop AFK summary | P12 handoff safety | RollManager, SaveManager, HUD | Yes | Rng, Offline | NOT RUN | AUTO |
| Preserve P11 backups/input/modal/fixed rotation/compact inventory | P12 handoff safety | SaveManager, HUD, World, Player, InventoryManager | Yes | Persistence, StabilityInput, InventoryStress | NOT RUN | AUTO |

## Prompt 13 progression feedback

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| R01 cost 25 and unchanged cooldown effect | P13 A; G1 | RollTree | Yes | Progression | NOT RUN | AUTO |
| R03 Auto follows R01, costs 40; fresh R01 next valid mainline node | P13 A; G1–2 | RollTree, SkillTreeManager | Yes | Progression | NOT RUN | AUTO |
| R02 requires R03, costs 75, luck ×1.10; Auto visually precedes it | P13 A; G3 | RollTree, SkillTreeCanvas | Yes | Progression, MobileUI | NOT RUN | AUTO |
| Historical R01+R02 loads without R03; allow later Auto; no mass refund | P13 A; G4 | SaveManager, SkillTreeManager | Yes | ProgressionSave | NOT RUN | AUTO |
| Central luck exposes all six components and TOTAL for developers | P13 B | RollManager, Menus, dev/SlimerotPlaytestLogger.gd | Yes | Progression, Playtest | NOT RUN | AUTO |
| B1 exactly ×20; repeated load no multiplier replay | P13 B; G5–6 | SkillTreeManager, RollManager, SaveManager | Yes | Progression, ProgressionSave | NOT RUN | AUTO |
| B1+B2 = ×400, all three = ×8000 | P13 B; G7 | RollManager, RollTree | Yes | Progression | NOT RUN | AUTO |
| Zone multiplier exactly once and Fortune through central function | P13 B/D; G8–9 | RollManager, CoinTree | Yes | Progression | NOT RUN | AUTO |
| RO5 requires R08, costs 650, interval 100/luck×5 (P13 proposed price; P16 current price in provisional table) | P13 C; G10 | RollTree, SuperRoll | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| RO8 requires RO5+R13, costs 900, interval 75/luck×10 (P13 proposed price; P16 current price in provisional table) | P13 C; G11 | RollTree, SuperRoll | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| RO9 requires RO8+R18, costs 1,500, interval 50/luck×20 (P13 proposed price; P16 current price in provisional table) | P13 C; G12 | RollTree, SuperRoll | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| Persistent next trigger handles mid-cycle purchase/upgrade/reload/offline | P13 C | SuperRoll, GameState, RollManager, SaveManager | Yes | Progression, ProgressionSave | NOT RUN | AUTO |
| Super still commits only normal +1/+1 currency | P13 C; G13 | RollManager | Yes | Progression | NOT RUN | AUTO |
| Preserve all prior Coin nodes and persistent IDs | P13 D | CoinTree, SaveManager | Yes | Progression, ProgressionSave | NOT RUN | AUTO |
| C20 Fortune I: Z3, 8,000 Coins,×1.15 (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| C21 Fortune II: C20+Z5, 80,000 Coins,×1.20 (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| C22 Fortune III: C21+Z7, 600,000 Coins,×1.25 (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| C23 Bond VI: C16+Z7, 450,000 Coins,+50 percentage points team damage (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| C24 Scavenger IV: C18+Z7, 500,000 Coins,+100 percentage points normal Coins (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| C25 Fleet III: CO2+Z7, 250,000 Coins,+15 percentage points speed (P13 proposed price; P16 current price in provisional table) | P13 D | CoinTree | Yes; cost tuned under P16 F | Progression | NOT RUN | AUTO |
| Hard equipped cap five; no XP/currencies/prestige/online systems | P13 D/F; G14 | Balance, SkillTreeManager, GameState | Yes | Progression, SkillTree; source audit | NOT RUN | AUTO |
| Validator unique/persistent IDs, existing prerequisites and no cycles | P13 E; G15 | SkillTreeValidator, SkillTreeManager | Yes | Progression | NOT RUN | AUTO |
| Validator valid currencies/costs, slot≤5, every Breakthrough×20, orphan warning | P13 E | SkillTreeValidator | Yes | Progression | NOT RUN | AUTO |
| Unknown purchased IDs retained safely without effects or load crash | P13 E | SaveManager, SkillTreeManager | Yes | ProgressionSave | NOT RUN | AUTO |
| Faster early/mid/late cadence evaluated without changing Prompt12 RNG model | P13 F; P16 E/F | Campaign, RollTree, CoinTree, tools/SlimerotPacingModel.gd | Yes; provisional tuning | Ready-autoload model: all 36 seeded runs completed; final-boss medians 40.58/43.81/44.66 min; human campaign NOT RUN | NOT RUN | MANUAL |

## Prompt 14 UI feedback

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Compact top HP/zone/Coins/Rolls/Luck/Settings; joystick bottom-left; ROLL/Auto bottom-right | P14 A; K1 | HUD, UITheme | Yes | MobileUI, UX; rendered inspection | NOT RUN | REVIEW |
| One Team utility entry, no redundant Inventory or Potions HUD button | P14 A/B; K2–3 | HUD | Yes | MobileUI | NOT RUN | AUTO |
| Skill Tree utility gated by repaired Shrine | P14 A; K7 | HUD, WorldManager | Yes | MobileUI | NOT RUN | AUTO |
| Map utility gated by repaired Fast Travel Pillar | P14 A | HUD, WorldManager | Yes | MobileUI | NOT RUN | AUTO |
| Team shows 1–5 slots, owned stacks, quantities, damage, flags, Team DPS | P14 B | Menus, InventoryManager | Yes | MobileUI, InventoryStress | NOT RUN | AUTO |
| Team sort/favorite/equip/unequip/Equip Best remain functional | P14 B | Menus, InventoryManager | Yes | MobileUI, UX, InventoryStress | NOT RUN | AUTO |
| Team → Collection works; removed from old Info navigation | P14 B/D; K4 | HUD, Menus | Yes | MobileUI | NOT RUN | AUTO |
| Team → Items/Potions works; bench opens same destination | P14 B; K5 | HUD, Menus, World | Yes | MobileUI, Encounter | NOT RUN | AUTO |
| Settings GENERAL music/SFX/shake/vibration | P14 C | Menus, Audio | Yes | MobileUI, UX | NOT RUN | AUTO |
| Settings ROLLING Auto/Sell/filters/Luck Cap/reveal controls | P14 C; K6 | Menus, HUD | Yes | MobileUI, Rolling | NOT RUN | AUTO |
| Settings SAVE/SYSTEM status/protected reset; Stats/About child replaces redundant Info | P14 C/D | Menus, HUD, SaveManager | Yes | MobileUI, StabilityInput, Persistence | NOT RUN | AUTO |
| One shared Godot Theme, chunky contrast/font hierarchy/finger targets | P14 E | assets/ui/SlimerotTheme.tres, project.godot, UITheme | Yes | MobileUI, tools/SlimerotExportAudit.gd; rendered review | NOT RUN | REVIEW |
| All eleven named reusable button/panel/card/chip/node variations | P14 E | assets/ui/SlimerotTheme.tres | Yes | MobileUI, tools/SlimerotExportAudit.gd | NOT RUN | AUTO |
| Shrine/Sell and similar world labels centered by anchors/containers | P14 F; K14 | UITheme, World, Zone | Yes | MobileUI | NOT RUN | AUTO |
| Real 2D skill coordinates and visible prerequisite lines | P14 G; K12 | SkillTreeCanvas | Yes | MobileUI | NOT RUN | AUTO |
| Main trunk, optional, Super and Coin branches; Auto before Luck | P14 G | SkillTreeCanvas, RollTree, CoinTree | Yes | MobileUI, Progression | NOT RUN | AUTO |
| One-finger drag pan | P14 G; K8 | SkillTreeCanvas, HUD | Yes | MobileUI (touch event dispatch) | NOT RUN | AUTO |
| Android two-contact pinch zoom; proposed .55–1.8 bounds | P14 G; K9 | SkillTreeCanvas, HUD | Yes | MobileUI (simulated Android event types) | NOT RUN | MANUAL |
| Plus/minus fallback and Fit both work | P14 G; K10–11 | SkillTreeCanvas, Menus | Yes | MobileUI | NOT RUN | AUTO |
| No giant vertical-scroll dependency; preserve pan/zoom through node purchase | P14 G; K13 | SkillTreeCanvas, Menus, HUD | Yes | MobileUI | NOT RUN | AUTO |
| Node detail name/effect/cost/currency/prerequisites/current→new/Buy | P14 G | Menus, SkillTreeManager, RollManager | Yes | MobileUI, Progression | NOT RUN | AUTO |
| Purchased/available/locked/Breakthrough visually distinct | P14 G | SkillTreeCanvas, assets/ui/SlimerotTheme.tres | Yes | MobileUI; rendered inspection | NOT RUN | REVIEW |
| UI calls backend progression APIs, no duplicate formulas | P14 source-of-truth rule | Menus, SkillTreeManager, RollManager | Yes | MobileUI, Progression; source inspection | NOT RUN | REVIEW |
| One Close/Back path; all screens survive 20 cycles | P14 H; K15 | HUD | Yes | MobileUI, StabilityInput | NOT RUN | AUTO |
| Android Back closes only top modal | P14 H; K16 | HUD | Yes | MobileUI, StabilityInput; hardware pending | NOT RUN | AUTO |
| Hidden/disposed/clipped controls cannot block joystick/ROLL | P14 H; K19 | HUD, SkillTreeCanvas | Yes | MobileUI, StabilityInput | NOT RUN | AUTO |
| Original nine local SVG icons; no slime-art overwrite or downloaded pack | P14 I | assets/ui/icons/Slimerot_*.svg, Assets | Yes | tools/SlimerotExportAudit.gd; asset manifest | NOT RUN | REVIEW |
| One card per unique stack, xN; debounce relevant visible-data refresh | P14 J | Menus, HUD | Yes | MobileUI, InventoryStress | NOT RUN | AUTO |
| 100 genuine Auto Rolls with Team closed leave zero rebuild/node growth | P14 J; K20 | HUD, Menus, RollManager | Yes | MobileUI | NOT RUN | AUTO |
| 720×1280 has no critical clipping | P14 K17 | HUD, Menus, SkillTreeCanvas | Yes | MobileUI, UX; rendered captures | NOT RUN | REVIEW |
| 720×1560 and 800×1280 have no critical clipping; safe insets retained | P14 K18 | HUD, Menus, SkillTreeCanvas | Yes | MobileUI, UX; rendered captures | NOT RUN | REVIEW |

## Prompt 15 combat, Dash, gates and assets feedback

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Central lightweight player/enemy/death/boss/Dash feedback hooks reuse bounded records | P15 A | CombatFeedback, CombatManager, Enemy, Boss, Player | Yes | CombatPresentation, Dash | NOT RUN | AUTO |
| One accepted player hit → one camera event/short flash, no long lock | P15 A; J1 | CombatManager, CombatFeedback, Player | Yes | CombatPresentation | NOT RUN | AUTO |
| Enemy hits particles/flash/squash; death stronger burst without growing scene nodes | P15 A; J2 | Enemy, CombatFeedback | Yes | CombatPresentation | NOT RUN | AUTO |
| Readable projectile core/trail/spawn/impact and zone styles; retained swept collision | P15 B | Projectile, CombatManager | Yes | CombatPresentation; rendered review | NOT RUN | REVIEW |
| 1000 projectile lifetimes and saturated pool have bounded nodes | P15 B; J3 | CombatManager, Projectile | Yes | CombatPresentation | NOT RUN | AUTO |
| Normal Shooter friendly fire hits other normal enemies | P15 C; J4 | Enemy, Projectile | Yes | CombatPresentation | NOT RUN | AUTO |
| Friendly-fire damage round(target.max_hp×0.20) | P15 C; J5 | Projectile | Yes | CombatPresentation | NOT RUN | AUTO |
| Shooter source excluded from its own ray | P15 C; J6 | Projectile | Yes | CombatPresentation | NOT RUN | AUTO |
| Boss FF disabled; layers world1/player2/normal4/boss8 and masks7/3 | P15 C; J7 | Enemy, Boss, Player, Projectile | Yes | CombatPresentation | NOT RUN | AUTO |
| Duplicate hit/death cannot grant repeated Coins or kills | P15 C | Enemy, WorldManager | Yes | CombatPresentation, Encounter | NOT RUN | AUTO |
| Free permanent Dash before Espresso at Z2 gate/tutorial | P15 D | GameState, World, WorldManager | Yes | Dash, CombatPresentation | NOT RUN | AUTO |
| Persist dash_unlocked; legacy valid default | P15 D | SaveManager, GameState | Yes | Dash | NOT RUN | AUTO |
| Separate mobile Dash avoids joystick/ROLL; desktop dash action Q | P15 D | HUD, Player, project.godot | Yes | Dash, CombatPresentation | NOT RUN | AUTO |
| Dash .16s,240px within proposed220–260px,1s cooldown | P15 D; J9 | Player | Yes | Dash | NOT RUN | AUTO |
| Velocity burst sweeps walls, no teleport clipping | P15 D; J8 | Player | Yes | Dash | NOT RUN | AUTO |
| I-frames only during active burst; trails/afterimages bounded | P15 D; J10 | Player, CombatManager, CombatFeedback | Yes | Dash | NOT RUN | AUTO |
| Four existing bosses/identities/reward flags remain; later P16 HP tuning is listed separately; open arena space and reset | P15 E; J14–15 | Encounters, Boss, BossArena, WorldManager | Yes | BossPresentation, Encounter | NOT RUN | AUTO |
| Serious attacks warned; hitboxes match visual geometry; slow frame cannot skip warning | P15 E; J11/13 | Boss | Yes | BossPresentation | NOT RUN | AUTO |
| Espresso chase/two separately warned slams/charge/recovery and Dash tutorial | P15 E | Boss, World | Yes | BossPresentation, CombatPresentation | NOT RUN | AUTO |
| Router warned fans/beam/perpendicular sweep with intentional gaps | P15 E | Boss | Yes | BossPresentation | NOT RUN | AUTO |
| Janitor distortion/fade-out/marker/fade-in/windup then bursts and safe columns | P15 E; J12 | Boss | Yes | BossPresentation | NOT RUN | AUTO |
| Admin fans/teleport/beams;40% final phase circles separated from critical patterns | P15 E | Boss | Yes | BossPresentation | NOT RUN | AUTO |
| Auto Roll continues through battle | P15 E; J21 | RollManager, Boss, HUD | Yes | CombatPresentation | NOT RUN | AUTO |
| Rare reveal compact during boss fight; no full dim or reveal shake hides telegraphs | P15 E; J22 | Reveal, Player, HUD | Yes | CombatPresentation | NOT RUN | AUTO |
| One physical progression gate starts boss before first kill | P15 F; J16 | World, WorldManager, Zone | Yes | CombatPresentation | NOT RUN | AUTO |
| Same gate becomes onward travel/completion after kill | P15 F; J17 | World, WorldManager, Zone | Yes | CombatPresentation, FinalIntegration | NOT RUN | AUTO |
| Gate role uses saved boss flag across reload; no separate boss entrance | P15 F; J18 | WorldManager, SaveManager, World | Yes | CombatPresentation, FinalRestartProbe (desktop process restart) | NOT RUN | AUTO |
| First zone unlock name/luck/camera/gate animation/SFX event once | P15 G; J20 | WorldManager, World, HUD, CombatFeedback, Audio | Yes | CombatPresentation | NOT RUN | AUTO |
| Zone unlock beat never writes accumulated luck; revisits silent | P15 G; J19 | WorldManager, RollManager | Yes | CombatPresentation | NOT RUN | AUTO |
| All eight zone obstacle/rock/prop/border art improved; structures/gates original local SVG | P15 H | assets/environment/, Assets, World, Zone | Yes | tools/SlimerotExportAudit.gd; Prompt15 asset manifest | NOT RUN | REVIEW |
| User slime art untouched; exact 41-asset manifest | P15 H | docs/Slimerot-Prompt-15-Assets.md | Yes | Export audit plus diff/manifest inspection | NOT RUN | REVIEW |
| Optional behavior_modifier extends existing archetype safely without new system | P15 I | Campaign, scripts/data/SlimerotData.gd, Enemy | Yes | CombatPresentation, Campaign | NOT RUN | AUTO |

## Prompt 16 final invariants, power and balance

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| No new feature categories; existing P11–15 systems remain authority | P16 scope | Existing manager/data/presentation files | Yes | Full regression and diff review | NOT RUN | REVIEW |
| Complete individually sourced requirement matrix, including prior issues | P16 A/P1 | docs/Slimerot-Prompt-16-Matrix.md | Yes | Documentation review | NOT RUN | REVIEW |
| Every completed roll exactly +1/+1; skill purchases spend only spendable Rolls | P16 B | RollManager, SkillTreeManager, GameState | Yes | Rolling, Rng, Progression | NOT RUN | AUTO |
| One Auto loop; offline same commit; delayed/skipped reveals never grant rewards | P16 B | RollManager, RollRevealQueue, SaveManager | Yes | Rolling, Rng, Offline | NOT RUN | AUTO |
| Super affects only its logical result; pity cannot create second committed reward | P16 B | RollManager, SuperRoll, Pity | Yes | Rng, Progression | NOT RUN | AUTO |
| Final six-component luck, B1×20/B2×400/B3×8000, Z1×1 through Z8×8 | P16 C | RollManager, RollTree, CoinTree | Yes | Progression, Rng | NOT RUN | AUTO |
| No accumulated derived luck persisted/reapplied on load | P16 C | SaveManager, SkillTreeManager | Yes | ProgressionSave, Persistence | NOT RUN | AUTO |
| Exactly 24 bases, all available from start, origin metadata only | P16 D | Roster, SlimeDatabase | Yes | Rng | NOT RUN | AUTO |
| All 8 masks and independent100/400/1600 odds; canonical rarity/damage formulas | P16 D | Variants, SlimeDatabase | Yes | Rng | NOT RUN | AUTO |
| Generate complete 24×8 debug power table and assert global rarity→damage monotonicity | P16 D | SlimeDatabase; docs/Slimerot-Prompt-16-Power-Table.md | Yes | FinalRng: 26-check final RNG suite; exhaustive 192-row formula/monotonicity assertions | NOT RUN | AUTO |
| Shiny 1/2 and Normal 1/200 same rarity-power class | P16 D | SlimeDatabase, Roster | Yes | Rng, FinalRng | NOT RUN | AUTO |
| Timestamp Auto unlock, zones, each Breakthrough/Super/team slot/Fortune/Shrine/boss/final boss | P16 E | dev/SlimerotPlaytestLogger.gd | Yes | Playtest, FinalPacing: timestamped finite milestone index checked in final regression | NOT RUN | AUTO |
| Timestamp first multi-variant and every new all-time-best, independent of current ownership | P16 E | dev/SlimerotPlaytestLogger.gd, RollManager | Yes | FinalPacing: historical discovery baseline survives consumed copies and load; best-ever milestone coverage | NOT RUN | AUTO |
| Track DPS, current Chaser TTK, Coins/min, Rolls/min, luck, best rarity/damage, last-unlock age | P16 E | dev/SlimerotPlaytestLogger.gd | Yes | FinalPacing: exact 30-second Coin/Roll throughput and last-unlock age; canonical rarity/damage and Chaser TTK | NOT RUN | AUTO |
| Current-zone Chaser proposed 2–10 s; sustained 15–20 s is too spongey | P16 E QA target | Campaign, tools/SlimerotPacingModel.gd | Tuned; human acceptance pending | Corrected live-luck model: policy medians 3.06–3.51 s, p90 5.88–6.52 s; 0/14,054 samples exceed15 s; not a physics or device playthrough | NOT RUN | MANUAL |
| Ready boss proposed 45–180 s; weaker players may overgear | P16 E QA target | Encounters, InventoryManager, Boss | Tuned; human acceptance pending | Corrected model: all observed boss fights 22.31–121.64 s; some overgeared kills below45 s; no simulated boss exceeded180 s | NOT RUN | MANUAL |
| New all-time rarest entering top 5 produces visible DPS jump | P16 E/O | InventoryManager, SlimeDatabase | Canonical rarity-power progression; subjective acceptance pending | Corrected model auto-equips new best: median DPS +30.1% to+33.9%; smallest +2.1%; not every new record proves a large visible jump | NOT RUN | MANUAL |
| Avoid long idle walls; frequent skills/zones/power/features across campaign | P16 E/O | Campaign, RollTree, CoinTree, tools/SlimerotPacingModel.gd | Tuned; human acceptance pending | Corrected model: maximum sampled meaningful-unlock gap4.63 min; 36/36 campaigns complete; final boss precedes B3 in every sample | NOT RUN | MANUAL |
| Tune too-fast in HP→boss HP→gates→new Coin costs→Super→soft pity→base thresholds order | P16 F | Canonical data; final tuning report | Yes; final candidate addresses slow purchase clocks and measured encounter tails | Data diff: lower HP/gates, higher income and lower prices; no nerf to Breakthroughs, variants, pity or base rarity thresholds | NOT RUN | REVIEW |
| Tune too-slow in HP/gates→Coin income→new skill costs→RNG order; preserve×20/variant damage | P16 F | Canonical data; final tuning report | Yes; provisional tuning | Canonical data and balance report list HP/gate reductions, Z3–Z7 income increase and cheaper skills; RNG power formula unchanged | NOT RUN | REVIEW |
| Old mutator inactive; unique category sets/protection/1.05^count and no old recipe UI | P16 G | InventoryManager, Menus, Variants | Yes | Rng; UI string audit | NOT RUN | AUTO |
| No redundant Potions/Inventory/Skill Tree peers/Roll Settings/scroll skill list/misaligned labels | P16 H | HUD, Menus, SkillTreeCanvas, UITheme | Yes | MobileUI; rendered audit | NOT RUN | REVIEW |
| Team→Collection/Items; Settings→Rolling; pan/zoom; Close and top-modal Back | P16 H | HUD, Menus, SkillTreeCanvas | Yes | MobileUI, StabilityInput | NOT RUN | AUTO |
| Fixed rotation/hitFX/projectiles/FF/Dash/telegraphs/teleport/beams/gates/unlock event | P16 I | Player, CombatManager, Boss, WorldManager, World | Yes | Dash, BossPresentation, CombatPresentation | NOT RUN | AUTO |
| Rare reveals keep critical boss gameplay visible | P16 I | Reveal, HUD, Player | Yes | CombatPresentation | NOT RUN | AUTO |

## Prompt 16 stress, saves, Android and offline acceptance

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Synthetic inventory covers 24 bases×8 masks with large quantities | P16 J | InventoryManager; tests/SlimerotFinalPacingTests.gd | Yes | FinalPacing: 192 stacks × 1,000,000 copies = 192 million compact identities | NOT RUN | AUTO |
| Equip Best 1,000 times: runtime, memory trend, scene count; no unbounded growth | P16 J | InventoryManager; tests/SlimerotFinalPacingTests.gd | Yes | FinalPacing: 1,000 calls; 2,304.9 ms in final full run; zero node growth; sampled retained-memory delta +5,636 bytes | NOT RUN | AUTO |
| Fastest 0.50 s Auto for ≥15 min equivalent; no linear scene leak per roll | P16 J | RollManager, HUD; tests/SlimerotFinalPacingTests.gd | Yes | FinalPacing: 900 accelerated seconds, 1,800 genuine commits, exact +1/+1; zero scene-node/UI rebuild growth | NOT RUN | AUTO |
| Rare queue overflow preserves rewards and movement/roll progress | P16 J | RollRevealQueue, RollManager | Yes | FinalRng and FinalPacing: 100-record overload represented; queue≤32; 1,800 backend commits continue without pause or UI rebuild | NOT RUN | AUTO |
| New all-time best never silently loses presentation; summarize overflow at minimum | P16 J | RollRevealQueue, Reveal | Yes | FinalRng: 100 power records represented; rendered 68-record summary and strongest slime fit both normal and boss HUD | NOT RUN | AUTO |
| Stress pooled projectiles/effects/boss cycles without unbounded records/nodes | P16 J | CombatManager, CombatFeedback, Boss | Yes | CombatPresentation: 1,000 projectile lifetimes reuse a slot; overload capped at128; BossPresentation/CombatFeedback bounded-state assertions | NOT RUN | AUTO |
| Legacy single-variant→multi-mask migration end-to-end | P16 K | SaveManager, InventoryManager | Yes | RngSave, FinalSave: 164 migration checks passed, including historical Roll price preservation | NOT RUN | AUTO |
| Pre-AFK timestamps initialize without fabricated catch-up | P16 K | SaveManager | Yes | Offline, FinalSave: schemas 1–11 defaults checked | NOT RUN | AUTO |
| Pre-Shrine categories initialize as empty unique sets | P16 K | SaveManager | Yes | RngSave, FinalSave: 164 migration checks passed | NOT RUN | AUTO |
| Pre-Dash valid default; pre-new-skills leave new IDs unpurchased | P16 K | SaveManager | Yes | Dash, ProgressionSave, FinalSave | NOT RUN | AUTO |
| Preserve Coins/Rolls/Lifetime/bosses/zones/team/inventory/favorites/skills together | P16 K | SaveManager, InventoryManager, GameState | Yes | FinalSave: currencies/flags/copies/team/favorites/skills compared through all schemas 1–11 | NOT RUN | AUTO |
| Android 1 Auto ON→background→resume, offline rewards once | P16 L1 | SaveManager, RollManager | Yes | Offline, FinalRestartProbe: duplicate resume/reopen desktop PASS; hardware not executed | NOT RUN | MANUAL |
| Android 2 Auto ON→background→force-stop→reopen, offline rewards once | P16 L2 | SaveManager, RollManager | Yes | FinalRestartProbe: actual first/second reopened processes PASS; hardware not executed | NOT RUN | MANUAL |
| Android 3 rare multi-mask commit→immediate force-stop→reopen persists once | P16 L3 | RollManager, SaveManager | Yes | FinalRestartProbe: actual killed/reopened Windows process PASS; hardware not executed | NOT RUN | MANUAL |
| Android 4 Shrine offering→force-stop→reopen multiplier persists once | P16 L4 | InventoryManager, SaveManager | Yes | FinalRestartProbe: actual killed/reopened Windows process PASS; hardware not executed | NOT RUN | MANUAL |
| Android 5 skill buy→force-stop→reopen persists once | P16 L5 | SkillTreeManager, SaveManager | Yes | FinalRestartProbe: actual killed/reopened Windows process PASS; hardware not executed | NOT RUN | MANUAL |
| Android 6 Breakthrough→force-stop→reopen identical luck | P16 L6 | RollManager, SaveManager | Yes | FinalRestartProbe, ProgressionSave: desktop PASS; hardware not executed | NOT RUN | MANUAL |
| Android 7 boss defeat→force-stop→reopen combined gate onward state | P16 L7 | WorldManager, SaveManager | Yes | FinalRestartProbe: actual killed/reopened Windows process PASS; hardware not executed | NOT RUN | MANUAL |
| Android 8 Dash unlock→force-stop→reopen remains unlocked | P16 L8 | GameState, SaveManager | Yes | FinalRestartProbe: actual killed/reopened Windows process PASS; hardware not executed | NOT RUN | MANUAL |
| Runtime HTTP/HTTPRequest/WebSocket/network/login/cloud/remote asset audit | P16 M | scripts/, scenes/, project.godot, export_presets.cfg | Yes | Source search repeated during final review: no runtime network client/API/URL found | NOT RUN | AUTO |
| No accounts/cloud/leaderboards/ads/online telemetry/multiplayer; local bundled assets | P16 M | project.godot, export_presets.cfg, Assets, Audio | Yes | Source audit and isolated resource-pack audit | NOT RUN | REVIEW |
| Airplane-mode full campaign works without login/download | P16 M/O | Bundled runtime and export preset | Yes | Source/export evidence only; device airplane mode NOT RUN | NOT RUN | MANUAL |
| AFK catch-up requires no Android background game loop | P16 M/O | SaveManager, RollManager | Yes | Offline, OfflineRestartProbe; hardware NOT RUN | NOT RUN | MANUAL |
| Current docs remove exclusive variants, obsolete odds, flat damage, old recipe, zone RNG gate, old ordering and skill-list claims | P16 N | Slimerot-README.md, docs/Slimerot-Android.md, docs/Slimerot-Saves.md; historical banners | Yes | Documentation audit | NOT RUN | REVIEW |
| All provisional/adopted-but-unverified numbers sourced and listed | P16 N/P13 | docs/Slimerot-Prompt-16-Provisional.md | Yes | Data/documentation inventory review | NOT RUN | REVIEW |
| No known Equip Best crash; one-tap/no-double interaction and stable Close | P16 O Stability | InventoryManager, HUD, World | Yes | InventoryStress, StabilityInput, MobileUI, FinalPacing: final regression passed | NOT RUN | AUTO |
| Legacy migration/force-close accounting/multi-variant persistence | P16 O Save | SaveManager, RollManager, InventoryManager | Yes | Persistence, RngSave, Offline; hardware matrix remains not run | NOT RUN | AUTO |
| Exact +1/+1, all-base chase, zone luck, pity max, masks and rarity damage | P16 O RNG | RollManager, Pity, Variants, SlimeDatabase | Yes | Rng, Progression | NOT RUN | AUTO |
| Earlier Auto, Super branch, Fortune/damage/speed/Coins, exact Breakthrough | P16 O Progression | RollTree, CoinTree, SkillTreeManager | Yes | Progression, ProgressionSave | NOT RUN | AUTO |
| Reorganized Team/Settings, pan/zoom, no clutter regressions | P16 O UI | HUD, Menus, SkillTreeCanvas | Yes | MobileUI; rendered/device status reported separately | NOT RUN | REVIEW |
| Feedback/projectiles/Dash/boss warnings/CombinedBossGate | P16 O Combat | CombatFeedback, Projectile, Player, Boss, WorldManager | Yes | CombatPresentation, Dash, BossPresentation | NOT RUN | AUTO |
| All huge-inventory/Auto/projectile/reveal stress has bounded growth | P16 O Performance | InventoryManager, RollManager, CombatManager, RollRevealQueue | Yes | FinalPacing/FinalRng/CombatPresentation: compact 192-million-copy inventory; 1,800 commits; bounded queue/pool; zero scene-node growth | NOT RUN | AUTO |
| No obvious new soft-locks; rarest power spikes; no progressive idle endgame | P16 O Balance | Canonical data and progression managers | No automated/model soft-lock found; human acceptance pending | All 36 corrected campaigns complete; maximum modeled gap4.63 min; B3 and SuperII/III remain later chase, not observed campaign unlocks | NOT RUN | MANUAL |
| Final PASS only when evidence meets each acceptance item; do not imply Android PASS | P16 O/P | docs/Slimerot-Prompt-16.md, Slimerot-Testing.md | Yes; desktop evidence passed, overall acceptance pending | Required hardware cases and human campaign remain NOT RUN; no overall PASS claim | NOT RUN | MANUAL |

## Prompt 16 required deliverables

| Requirement | Source feedback | Actual file(s) | Implemented? | Automated test? | Manual Android test? | Status |
|---|---|---|---|---|---|---|
| Complete requirement matrix | P16 P1 | docs/Slimerot-Prompt-16-Matrix.md | Yes | This document | NOT RUN | REVIEW |
| Exact Prompt16 changed files | P16 P2 | docs/Slimerot-Prompt-16.md; final git diff | Yes | Exact 49-file inventory verified against final git diff | NOT RUN | REVIEW |
| Save versions and migration chain | P16 P3 | docs/Slimerot-Saves.md, SaveManager, Balance | Yes | Migration suites | NOT RUN | AUTO |
| Final RNG/luck formula | P16 P4 | RollManager; docs/Slimerot-Prompt-16.md | Yes | Rng, Progression | NOT RUN | AUTO |
| Final variant formula | P16 P5 | Variants; docs/Slimerot-Prompt-16.md | Yes | Rng | NOT RUN | AUTO |
| Final damage formula | P16 P6 | SlimeDatabase, Roster; docs/Slimerot-Prompt-16.md | Yes | Rng, FinalRng | NOT RUN | AUTO |
| Final exact skill delta | P16 P7 | docs/Slimerot-Prompt-16-Balance.md | Yes | All current/old node costs and unchanged effects compared against baseline | NOT RUN | REVIEW |
| Final UI navigation map | P16 P8 | docs/Slimerot-Prompt-14.md; docs/Slimerot-Prompt-16.md | Yes | MobileUI | NOT RUN | AUTO |
| Boss summary | P16 P9 | docs/Slimerot-Prompt-15.md; docs/Slimerot-Prompt-16.md | Yes | BossPresentation | NOT RUN | AUTO |
| Measured performance benchmark | P16 P10 | docs/Slimerot-Prompt-16.md; final local benchmark output | Yes | FinalPacing: full-run and focused-rendered timing/memory/node samples; see Prompt16 report | NOT RUN | AUTO |
| Android force-close results explicitly separate from desktop probes | P16 P11 | docs/Slimerot-Android.md; docs/Slimerot-Prompt-16.md | Yes | All eight Android cases NOT RUN | NOT RUN | MANUAL |
| Remaining non-blocking issues and any acceptance blockers stated | P16 P12 | docs/Slimerot-Prompt-16.md | Yes | Final report separates non-blocking limits from required device/human acceptance | NOT RUN | REVIEW |
| Every proposed/provisional non-feedback number enumerated without invented provenance | P16 P13 | docs/Slimerot-Prompt-16-Provisional.md | Yes | Canonical data inventory | NOT RUN | REVIEW |

## Offline-only audit detail

Read-only search covered `scripts/`, `scenes/`, `project.godot` and `export_presets.cfg` for HTTP/HTTPRequest, WebSocket, network APIs, TCP/UDP/ENet/multiplayer, login/cloud, remote URLs, OS process launch and browser/platform bridges. Matches were only the inert-JSON/no-network comment in `scripts/data/SlimerotSaveFormat.gd` and `permissions/access_network_state=false` in the export preset. `permissions/internet=false`, `permissions/access_network_state=false`, `user_data_backup/allow=false` are explicit. No custom Android plugin or remote asset source is configured. Repository/docs GitHub/Godot URLs and local `res://`/`user://` paths are contextual references and local resources, not runtime requests. This audit does not claim a radio-disabled Android session was run.

## Manual device evidence boundary

No Android device/APK execution evidence has been supplied. Therefore physical touch/pinch, Android Back, OS force-stop cases 1–8, airplane mode, target-device memory/FPS/thermal/battery behavior and human campaign difficulty remain **NOT RUN**, regardless of desktop checks. The required procedures and expected outcomes are listed individually in [Android verification](Slimerot-Android.md).
