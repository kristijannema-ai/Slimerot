# Slimerot UI polish

> **Historical record — Prompt 16:** Historical pre-Prompt-11 UI polish report. Prompt 14 supersedes the navigation, theme and skill-list layout: Team → Team/Collection/Items, Settings → Rolling and a pannable 2D SkillTreeCanvas are the current UI. Prompt 15 adds Dash and compact combat reveals. Old mutation/card/navigation references below are historical only.

This visual pass starts from merged Prompt 10 (`6b1b273`) on `slimerot/ui-polish`.

- A shared navy, cream and lime palette gives the HUD, menus and roll cards a consistent appearance.
- The HUD groups touch controls into a bottom dock, frames the equipped team, labels health/wallet sections, and gives ROLL clear normal, pressed and cooldown states.
- Menus have a fixed title, clear selected navigation, larger framed slime previews, variant-colored card accents, and consistent spacing and text contrast. Potion and mutation actions are grouped into cards.
- Owned skills, selected sorting, favorites and Luck Cap choices have visible active states. Breakthroughs retain gold accents.
- The joystick has directional ticks, thumb depth and an active-direction highlight. Its 90 px acquisition radius and input routing are unchanged.
- Roll cards separate the slime name from variant/threshold details and use softer shadows and sparkle shapes. Reveal timing, skip rules and reward commits are unchanged.
- Reveal cards recompute their intended size after text wrapping settles, fixing oversized common toasts and jackpot cards on first display.
- Settings sliders have visible tracks and larger generated handles; these require no new downloaded assets.

Changed production files: `scripts/data/SlimerotPresentation.gd`, `scripts/ui/SlimerotHUD.gd`, `scripts/ui/SlimerotMenus.gd`, `scripts/ui/SlimerotJoystick.gd`, and `scripts/ui/SlimerotReveal.gd`.

Validation uses the existing combined Godot suite and rendered captures. It covers safe-area layouts at 720×1280, 720×1440 and 800×1280, simultaneous movement/ROLL, touch scrolling, Android Back dispatch, Settings controls, all gameplay/save integrations and bounded presentation resources. Physical Android touch, cutouts and frame pacing still need device testing. Screenshots are local test artifacts under ignored `.godot/`; the game requires no external UI assets or network access.

Godot 4.5.1 editor import passed. The final rendered combined suite passed **1,385 checks, zero failures**, including two new cold-start reveal sizing assertions in `tests/SlimerotUXTests.gd`. Rendered HUD, Inventory, Team, Settings and jackpot captures were inspected; the slider tracks and oversized reveal were corrected during that review. No gameplay balance, save schema or progression data changed.
