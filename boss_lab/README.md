# Slimerot Boss Lab

A standalone Godot 4.x project for iterating on four experimental Slimerot encounters. Open **this directory's `project.godot`**, rather than the parent game's project, then press F5 or Run Project. Validated with Godot 4.5.1 and the GL Compatibility renderer.

The main game has no dependencies on this project. Its existing bosses, progression, saves, art and audio are unchanged. `.gdignore` prevents the parent Godot project from importing the Lab; the nested project can still import its own resources. Lab history uses a separate `SlimerotBossLab` user directory. These encounters have not been ported into Slimerot.

## Launch and controls

```powershell
godot --path boss_lab --editor
# Or launch directly from the repository root:
godot --path boss_lab
```

Select a boss, Normal Test Mode or Practice Mode, and a DPS preset; press Start. There are three representative slimes that attack automatically. The player has no gun or manual attack.

| Action | Desktop | Touch |
| --- | --- | --- |
| Move | WASD / arrow keys | Left joystick |
| Dash | Space / Q | Large right Dash button; second finger supported |
| Retry immediately | R | Retry on the result card, or Restart in Tools |
| Developer panel | F1 | Tools |
| Close top panel / return to selection | Escape | Close / Menu; Android Back follows the same one-level path |
| Statistics | Selection or result card | Stats |

Tools pauses the encounter. Normal shows read-only debug values and Restart. Practice additionally enables invulnerability, phase 1–4, named attack forcing, 0.5x speed, hitboxes, telegraph display and DPS changes. Returning to Normal clears the practice overrides. Retry has no intro, scene reload or enforced death delay.

## Directory and created files

```text
boss_lab/
  project.godot, export_presets.cfg, .gdignore, .gitignore
  assets/       local SVG art, icon and two short sounds
  core/         portable attack/controller/context/player/arena/pool resources
  data/         central balance and four encounter profile Resources
  attacks/      espresso/ (5), sand/ (6), janitor/ (6), admin/ (8)
  lab/          selection, session, HUD, touch joystick and local metrics
  tests/        runtime, pattern, UI, metrics and rendered capture runners
  README.md, FILES.md, VALIDATION.md, PORTING_TO_SLIMEROT.md
```

[FILES.md](FILES.md) is the complete source inventory, including Godot UID and import sidecars. Cache, builds, screenshots, logs and raw test reports are excluded. Player and boss SVGs and the two sounds are local copies of the repository's existing assets; originals are untouched. `assets/BossLab.svg` is a new original vector icon. No external asset packs were downloaded.

## Current balance and phases

| Shared setting | Value |
| --- | ---: |
| Player HP / movement | 100 / 180 px/s |
| Player body radius | 12 px, visibly outlined |
| Dash duration / cooldown / travel | 0.16 s / 1.00 s / 240 px |
| Post-hit grace | 0.35 s |
| Three-slime Low / Expected / High DPS | 100 / 150 / 225 |
| Projectile / hazard / FX capacity | 160 / 96 / 96 |

Dash is invulnerable while active and stops at walls. Freeze, gravity and wet floors retain steering; combined external force is capped at 100 px/s and speed reduction at 0.38x. Damage numbers are per hit, with grace preventing simultaneous full-health burst damage. Lingering hazards can hit again after grace if the player remains inside.

| Boss | HP | Phase boundaries | Measured Expected-DPS fight* | First-clear design target |
| --- | ---: | --- | ---: | --- |
| Espresso Golem | 18,000 | 70%, 35% | 122.40 s | 3–7 attempts |
| Sand Router | 19,500 | 70%, 35% | 132.40 s | 4–9 attempts |
| Backrooms Janitor | 19,500 | 70%, 35% | 132.40 s | 5–12 attempts |
| Singularity Admin | 22,500 | 70%, 40%, 15% | 153.28 s | 8–15 attempts |

*Actual HP-driven God-mode practice encounters at 60 Hz. These measure automatic slime DPS and phase transitions, not human victories. The extra time above HP/DPS comes from harmless phase transitions. Low/High presets deliberately bracket the target duration and need not both fall inside 90–180 seconds. Human first-clear targets remain unmeasured; attempts never alter damage, HP or eligibility to win.

## Exact move lists, damage and timings

The two linked encounter tables document **every move's warning, active duration, recovery, damage, geometry and valid response**, along with scheduler weights and resource override keys:

- [Espresso and Sand move tables](attacks/ESPRESSO_SAND.md)
- [Janitor and Admin move tables](attacks/JANITOR_ADMIN.md)

| Boss | Complete move list and default damage |
| --- | --- |
| Espresso | Slam 24 + expanding ring 18; Caffeine Charge 27; Shots 12 + warned puddle 10; Double Shot 22 each; Overcaffeinated reuses Charge/Slam/ring damage unchanged |
| Sand | Fan 12; Wall 23; Route Recalculation 20; Quicksand movement field 0 + fan 12; Mirage Routers fan 12; Collapse edges 30 + fan 12 |
| Janitor | Teleport arrival 0 + warned sweep 22; Mop Sweep 27; Cart 24 + bottles 12; Wet Floor 0; Wrong Door sweep 30; Lights Out marks 22 |
| Admin | Gravity field 0 + shots 10; Orbital shots 12; Singularity Dash 30 + gravity wake 0; Repulsion push 0 + edges 26; Delete 28; Freeze field 0 + shots 10; Event Horizon outside band 32 + shots 10; Collapse quadrants 32 + shots 10 |

Espresso teaches locked charge lanes and radial gaps. Phase 2 adds Double Shot and puddles; phase 3 adds returning charges, two-ring Slams, larger fans and the 8.4 s Overcaffeinated rhythm. Sand teaches routes: phase 2 introduces a moving single wall gap, changing safe routes and rune-marked Mirages; phase 3 adds staged edge Collapse. Janitor teaches arrival cues and directional sweeps, then wet-floor combinations and door memory, finally bounded darkness. Admin teaches bounded gravity, sequential launch locks and Dash wakes; phase 2 adds push/edge danger, Delete and Freeze; phase 3 adds a moving safe annulus and Collapse; final 15% insets arena edges by 24 px and accelerates authored combinations.

Only six external combinations exist: light Shots + single Charge; Wall + light Fan; Wet Floor + Teleport; Lights Out + Wet Floor; Gravity Well + Orbital; final-phase Delete + Singularity Dash. At most two attack modules run together. Major Event Horizon, Collapse and Overcaffeinated use their own authored lighter pressure and receive no extra scheduler partner. Weighted selection avoids consecutive repeats; phase recovery is typically 0.16–0.45 s, with 0.9 s harmless phase transitions.

All four arenas use the portrait playable bounds with different cafe/desert/Backrooms/cosmic presentation. Dangerous drawing and collision share the same geometry. Red/orange indicates damage, yellow moving attacks, purple control mechanics and blue safe/neutral routes. Arena clipping prevents warnings and shots from obscuring the HUD. Fixed pools, short impact particles, hit flashes, bounded camera shake and local hit/victory sounds provide feedback.

## Remaining tuning questions

The mechanics were iterated using actual runtime movement, damage, geometry probes and rendered captures. Thirty-six Normal-mode stationary/circle/circle-with-cooldown-Dash bot attempts produced no victories. This challenges obvious movement exploits; it does not establish human fun, reaction fairness or the intended boss difficulty ranking.

Prioritize human touch testing of Overcaffeinated ring/charge timing, the moving Sand gap, readability of Wrong Door on a phone and Admin's annular positioning under light projectile pressure. Sand Wall is easier if already aligned, the Mirage rune may become trivial once learned, Cart can be avoided by staying on the far side, and staying outside Mop melee range can reduce pressure. Janitor allowed the longest circle-with-Dash survival (118.3 s), so its pressure distribution needs particular review. The Lab is ready for that iteration; figures remain provisional.

## Performance and validation

[VALIDATION.md](VALIDATION.md) contains the 22-criterion matrix, test methods, measured durations, allocation results and limits. Both headless and rendered suites pass 1,398 checks with zero failures while exercising the actual backend. Expected-DPS fights and 100 final-phase Admin retries retain exactly 152 scene nodes; individual projectiles and FX create no nodes. Largest observed full-fight pool peaks are 12 hazards, 21 projectiles and 36 effects. Desktop accelerated simulation timings are not Android FPS measurements.

```powershell
godot --headless --path boss_lab --quit-after 1800 -- --boss-lab-test
# Run the same checks with a rendered viewport:
godot --path boss_lab --quit-after 1800 -- --boss-lab-test
```

Tests use isolated history and do not overwrite device attempts. The Android preset is provided without Internet permissions. SDK/signing, APK installation and physical Android performance remain untested.

## Tweak numbers and port later

Edit `data/Balance.tres` for movement, Dash, HP, test-team DPS and pool caps. Edit each boss `.tres` for HP, phase boundaries, recovery and `attack_overrides`. Espresso/Sand's documented override keys cover all meaningful damage/timing/geometry values. Janitor/Admin also expose move `params`, weights and combos in their small `*Profile.gd` definitions; remaining constants are at the top of the individual move modules. Rerun runtime tests after tuning, then compare repeated human Normal attempts at the same recorded DPS preset and seed.

Local statistics keep Normal/Practice histories separate, with attempts, wins, mean survival, killing attack, pre-first-clear best HP and detailed per-attempt damage/Dash data. Up to 500 detail records are retained alongside bounded all-time aggregates; retries never reset attempt numbers. See [UI and metrics contract](lab/UI_AND_METRICS.md).

[PORTING_TO_SLIMEROT.md](PORTING_TO_SLIMEROT.md) maps all 25 move modules and identifies the adapters for the real movement/Dash, boss damage, slime-team DPS, coordinate system, rewards and progression. Eventually move the approved encounter core, Resources and attack modules; keep the Lab UI, test DPS, history and practice cheats here. Human keyboard/touch feedback should determine which versions are approved before any port.
