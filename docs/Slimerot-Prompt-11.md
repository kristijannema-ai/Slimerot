# Slimerot Prompt 11: stability and Android AFK

> **Historical record — Prompt 16:** Historical Prompt 11 report. Schema 9 is the migration stage introduced here, not the current format: schema 11 now includes multi-variants, pity, Shrine sets, Super scheduling and additive Dash. The old mutation and navigation terms below describe the pre-Prompt-12/14 implementation; those behaviors have been superseded. Its stability/AFK invariants remain required.

Slimerot retains its existing Godot autoload architecture, offline world, progression data and local `user://Slimerot-save.json` profile. This stage addresses input reliability, inventory scale and background Auto Roll; it adds no background combat or network dependency.

The initial `git status --short` was empty. Origin was verified as `https://github.com/kristijannema-ai/Slimerot.git`, latest main was fetched at `ae29c6e` (merged UI polish), and work is isolated on `slimerot/stage-11-stability`. No player save or user edit was reset.

## Reported issues and implementation

| Reported issue | Actual files | Class / scene | Root cause | Fix |
| --- | --- | --- | --- | --- |
| Stationary Bedroom exit tap unreliable | `scripts/world/SlimerotWorld.gd`, `scripts/world/SlimerotInteraction.gd`, `scripts/ui/SlimerotHUD.gd` | Slimerot world scene, `SlimerotInteraction`, `SlimerotHUD` | Interaction proximity was refreshed by world processing, and mobile input had a separate action path. The arrival gate was immediately within interaction range. | A button activation requests one validated interaction; proximity is refreshed at the request. Transition and interaction guards reject reentry. The destination arrival gate must be left before it can be activated. |
| Interact fires on press and release | `scripts/ui/SlimerotHUD.gd`, `scripts/world/SlimerotWorld.gd` | `SlimerotHUD`, Slimerot world scene | Touch handling and the native button could both call gameplay actions. | One authoritative button activation path; touch ownership and transition guards prevent duplicate actions. |
| Close buttons sometimes fail | `scripts/ui/SlimerotHUD.gd` | `SlimerotHUD` | State updates rebuilt the complete menu and could destroy the pressed Close control before release. Child menus did not share a central back stack. | Stable modal chrome, body-only data refresh, and `open_modal`, `close_top_modal`, `close_modal` share one stack. Close and Android Back use the same controller. |
| Player rotates as a whole | `scripts/world/SlimerotPlayer.gd` | `SlimerotPlayer` | Direction changes rotated the whole drawn character, even though the body itself was not intentionally turning. | World rotation stays zero; directional visual details convey facing. A debug assertion validates the transform. |
| Large inventory / Equip Best stalls | `scripts/managers/SlimerotInventoryManager.gd`, `scripts/ui/SlimerotMenus.gd` | `InventoryManager`, menu builder | Selection and copy views worked over physical-copy arrays; team changes could cause repeated screen rebuilds. | Bulk ownership uses compact serial ranges. Equip Best considers at most five identities per unique stack and commits one team transaction. Unchanged teams emit no notifications. Copy views page identities; mutation and sales operate on ranges. |
| Android Auto Roll stops off-screen | `scripts/managers/SlimerotSaveManager.gd`, `scripts/managers/SlimerotRollManager.gd`, `scripts/ui/SlimerotHUD.gd` | `SaveManager`, `RollManager`, `SlimerotHUD` | Only the live gameplay loop completed rolls; no elapsed-time reconciliation existed. | A durable background checkpoint drives data-only catch-up on resume or launch. Long batches yield between slices and show one AFK summary. |
| Future additions may damage existing saves | `scripts/data/SlimerotBalance.gd`, `scripts/managers/SlimerotGameState.gd`, `scripts/managers/SlimerotSaveManager.gd`, `scripts/managers/SlimerotInventoryManager.gd` | Existing data/state/save managers | The previous schema had no offline anchor or compact identity representation. | Schema 9 migrates older saves without inventing elapsed time. It validates compact ownership and protects unsupported future schemas and invalid migrations from overwrite. |

## Save and catch-up contract

Schema **9** adds `last_background_timestamp` and `offline_roll_remainder`. Missing fields in schema 8 or older initialize to zero while preserving currency, purchases, exact equipped IDs, favorites, discoveries, gates, bosses and completion. Derived luck, damage, slots, HP and movement remain derived from saved purchases and potion state.

Inventory stacks retain compatible explicit `copy_ids` / `favorite_copy_ids` and can additionally contain inclusive `copy_ranges` / `favorite_copy_ranges`. IDs remain stable; a range is an identity encoding, not a new variant or inventory limit. Validation checks quantities, identity overlap, favorites, equipped ownership and capacity without expanding a range into individual objects.

Validated legacy stacks and ongoing foreground rolls compact large ID arrays automatically. This avoids a growing synchronous save cost after Equip Best. Selection reads a bounded set of identities even if ownership ranges are fragmented. The existing developer observer also recognizes compact ownership without changing gameplay.

Every durable foreground save includes the latest wall-clock anchor and partial roll cycle. The first pause/focus-out transition saves the current state; overlapping Android lifecycle notifications share that checkpoint. Resume waits until both pause and focus-loss latches clear. A backward clock correction never moves the saved anchor backward.

If Auto Roll was enabled and unlocked, completed elapsed cooldown cycles go through `RollManager.process_offline_rolls(count)`. It uses the ordinary eligible pool, two independent RNG streams, first-roll guarantee, variants, Super Roll, Luck Cap and auto-sale rules. Each completed cycle grants exactly one Rolls and one Lifetime Rolls. A disabled Auto Roll earns no offline rolls. The fractional cycle is retained.

Sampling occurs without per-roll scenes, reveal queues or inventory signals. Rewards and the consumed timestamp are then saved in the same checksummed temporary-file replacement transaction. A failed write keeps gameplay suspended and retries the already sampled state; it never resamples the batch. A process killed before that commit reopens the previous checkpoint. A process killed after it restores the committed rewards and cannot claim the same interval twice.

Active-play time, luck-potion duration and Boss Brew duration do not tick offline. There are no offline enemies, kills or combat Coin rewards. Existing unlocked duplicate auto-sale can still pay Coins for simulated roll duplicates. The AFK summary reports time away, completed rolls, Rolls earned, discoveries and best drop.

## Automated coverage

Final validation with Godot 4.5.1 on Windows:

- Full headless suite: **1,505 checks, 0 failures**. This includes the final fragmented-range regression.
- Full rendered suite: **1,504 checks, 0 failures** before the additional fragmented-range check; final focused rendered suite: **118 checks, 0 failures**. Rendered AFK summary reviewed for layout/readability.
- Actual forced process termination followed by two launches: **11 checks per launch, 0 failures**; the first claimed 100 offline rolls and the second claimed zero previously consumed rolls.
- Final editor/import validation and `git diff --check`: no Slimerot parser/runtime errors or whitespace errors. The host reports its existing certificate-store warning and missing Android build-tools; neither is a gameplay network dependency.
- Equip Best: 100 runs over 96 stacks / 9,600,288 copies completed in about 0.27 seconds; legacy 100,003-copy arrays also remained below the two-second regression ceiling. No repeated team notifications, saves, menu rebuilds or node growth occurred on unchanged selections.
- The 5,000-copy save fixture measured approximately **12–16 ms per save**, **6 ms load**, and **0.35 ms Equip Best** after compaction. Measurements are desktop observations, not Android timing guarantees.

Earlier campaign, skill, boss, mutation, collection, UI, save/recovery and endurance suites remain integrated. No Android APK or physical-device/manual campaign run is claimed.

Run the ordinary isolated test profile:

```powershell
godot --headless --path . --max-fps 60 --quit-after 7200 -- --slimerot-test
```

The test runner includes `SlimerotStabilityInputTests.gd`, `SlimerotInventoryStressTests.gd` and `SlimerotOfflineTests.gd` alongside previous regression suites. These cover stationary tap / release / spam input, repeated modal closure, fixed player rotation, millions of compact copies, mathematical top-five selection, live/offline 100-roll parity, sliced 20,000-roll catch-up, lifecycle overlap, Auto Roll OFF, fractional cycles, schema migration, compact favorites, future-save protection and failed-write retry.

Tests only use isolated files under `res://.godot`; they never read or replace the normal `user://` profile. Provide an absolute writable `--log-file` path when running Godot in a restricted sandbox.

For a real process-termination check, run the following scene in writer mode, wait for `Slimerot OFFLINE RESTART READY`, and terminate that process externally:

```powershell
godot --headless --path . res://tests/SlimerotOfflineRestartProbe.tscn -- --slimerot-offline-restart-probe --slimerot-offline-restart-write
```

Reopen once to commit exactly 100 catch-up rolls, then reopen again to prove no duplicate rewards:

```powershell
godot --headless --path . res://tests/SlimerotOfflineRestartProbe.tscn -- --slimerot-offline-restart-probe
godot --headless --path . res://tests/SlimerotOfflineRestartProbe.tscn -- --slimerot-offline-restart-probe --slimerot-offline-restart-verify
```

The probe uses `.godot/Slimerot-offline-restart.json`, an injected fixed wall clock, and exits with a failing status if accounting or restoration differs. The normal save remains untouched.

## Manual Android force-close procedure

1. Use a backed-up device profile or a separate test installation. Enable Auto Roll through the actual Roll tree; record Rolls, Lifetime Rolls, cooldown, equipped IDs, favorites and remaining potion time.
2. Press Android Home, wait for a measured absence longer than several cooldowns, then reopen. Verify one compact summary and approximately `floor((elapsed + saved partial cycle) / cooldown)` completed rolls. Both roll counters must increase by that exact count. Verify no combat kills/Coins and unchanged potion remaining time.
3. Immediately background and force-stop Slimerot from Android App Info, then reopen. Previously committed rewards must remain; only the newly elapsed interval may earn more. Repeated foreground/focus notifications must not repeat the previous batch.
4. Turn Auto Roll off, background for at least a minute, force-stop and reopen. Offline rolls must be zero; all progression and protections must remain.
5. Repeat with airplane mode enabled. Tap the Bedroom exit while stationary, hold/release once, and spam 20 taps. Verify only one transition and that returning requires leaving/reentering the arrival gate range.
6. Open and close each menu 20 times, including a child copy/sale view. Use Android Back with stacked menus, then with none open. Drag the joystick with one finger while tapping ROLL with another; the player body and camera must not rotate.
7. If testing a long absence, background again while catch-up is running and relaunch. Verify no partial currency grants or duplicate batches. Keep any failed-save profile for inspection instead of resetting it.

Device-specific lifecycle timing, touch behavior and Android force-stop checks still require an Android build and physical-device testing. This stage does not introduce a foreground service or try to keep Godot running indefinitely in the background.

## Changed files

Created: this report; `tests/SlimerotStabilityInputTests.gd`, `SlimerotInventoryStressTests.gd`, `SlimerotOfflineTests.gd`, `SlimerotOfflineRestartProbe.gd` and their UID files; `SlimerotOfflineRestartProbe.tscn`.

Modified: `Slimerot-README.md`; Android/save/testing documentation; `SlimerotBalance.gd`; existing GameState, InventoryManager, RollManager and SaveManager scripts; HUD/Menus; World/Interaction/Player; the developer playtest logger; the main test runner and existing persistence/playtest suites. There are no new gameplay managers, external dependencies or art requirements.
