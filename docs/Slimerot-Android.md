# Slimerot Android readiness and offline verification

This is the current device checklist through Prompt 16. The Android preset uses the Slimerot package name `com.slimerot.game`, version code `10`, version name `0.3.0`, and writes `build/Slimerot.apk`. Runtime saves belong in Godot's app-private `user://` directory. Replacing an installed build with the same package and signing identity preserves that directory; uninstalling the app or clearing its storage removes it. No physical Android run is claimed by the desktop validation reports.

## Repository configuration

- Portrait virtual resolution is 720×1280 with an expanding canvas. The shared theme and safe-area layout support a 90 px joystick radius, simultaneous movement/ROLL/Dash input, pannable/pinchable skill graphs and one-top-modal Android Back navigation.
- Rendering uses GL Compatibility on desktop and mobile. The export targets ARM64; 32-bit-only devices are outside this preset.
- `permissions/internet=false` and `permissions/access_network_state=false`. There are no network permissions or custom Android plugins enabled by this preset.
- `permissions/vibrate=true` enables the existing vibration setting on Android. It does not add network access.
- `user_data_backup/allow=false` keeps progression local instead of relying on Android backup restoration. No login, network clock, online account, remote configuration, advertisements, analytics or asset download is needed by gameplay.
- Scenes, balance data, art and audio resolve from bundled `res://` resources. Missing optional presentation files fall back safely; they never initiate a download.
- The repository excludes tests, documentation, developer instrumentation and standalone tools from exports. The APK uses the regular main scene and gameplay managers. Resource-pack checks run from an empty scratch project so missing files cannot resolve from source; current counts are recorded in [Testing](Slimerot-Testing.md). SDK/signing and actual APK/device validation remain external steps.

The source audit scanned `scripts/`, `scenes/`, `project.godot` and `export_presets.cfg` for HTTP clients, WebSocket/TCP/UDP/multiplayer APIs, platform bridges, process launch calls and remote resource URLs. No runtime network access was found. This is source and configuration evidence; it is not a claim that an APK or a physical phone was tested.

## Build verification

Use matching Godot export templates and a configured Android SDK/JDK. Keep release signing keys and passwords outside the repository. Export an ARM64 Slimerot APK with the checked-in preset and the intended signing identity; do not enable remote debugging or add Internet permission for the offline test artifact.

Inspect the exported manifest to confirm the Slimerot package/version, portrait orientation and absence of Internet/network-state permissions. Install it on a physical ARM64 Android device. Check a phone with a cutout and gesture navigation, and one with navigation buttons when available. APK export, signing, device performance and physical safe-area checks still require this device pass.

## Device acceptance checklist

Use a disposable test save when testing Reset. Do not uninstall or clear storage during the persistence checks.

1. Enable airplane mode before launching Slimerot, with Wi-Fi and mobile data off. Fresh launch must reach the Bedroom Hub without a permission, login or download gate. Move, roll, verify exactly one Rolls and Lifetime Roll, first Tung Tung ownership/equip, then enter Backyard and see an automatic attack.
2. Hold the joystick and tap ROLL and unlocked Dash with another finger. Repeat with Auto Roll during normal combat. Browse Team → Team/Collection/Items, both skill canvases and node details. Pan with one finger, pinch with two, and use +/−/Fit. Live Team/Skills menus preserve normal gameplay; Settings → Rolling pauses movement, combat, Auto Roll and active-play potion timers. Close every screen 20 times and verify Android Back closes only the top modal.
3. Open Settings, start the reset hold, then release early, drag away, press Android Back or background the app. Each interruption must cancel the hold. Resume must not continue a stale hold, movement direction, slider drag or held touch. A complete three-second hold must restore canonical new-save balances, inventory, unlocks, potion state and first-roll guarantee.
4. With Auto Roll and a potion active, record potion seconds and playtime. Press Home, wait at least one minute, then return. Repeat with screen lock and the app switcher. The inactive minute must not count as playtime or potion time. Enabled Auto Roll must catch up completed cooldown cycles once, show one compact AFK summary, and preserve its fractional cycle. Disabled Auto Roll must earn nothing. A previously open Settings menu must remain paused after the AFK summary closes; catch-up cannot duplicate on repeated focus/resume callbacks. Check music also suspends in the background.
5. Purchase a skill and check its immediate save status. Force-stop Slimerot from Android app settings, then reopen without clearing storage. Verify the spent wallet balance, unchanged Lifetime Rolls, purchased node and derived effects. Specifically save/load Breakthrough I more than once: the resulting luck stays the same after each load and never gains another ×20.
6. Repeat force-stop/reopen after a gate repair, structure repair, boss reward, Dash unlock and Variant Shrine sacrifice. Confirm gate costs are not charged again, boss rewards cannot repeat, and the same boss gate offers onward travel after a clear. A Shrine offering consumes exactly one unprotected variant copy for one chosen active category, persists the unique base ID, and leaves its `1.05^count` category multiplier unchanged on reopen. Check equipped copy order, per-copy favorites, quantities, all eight masks and Collection discoveries. The former five-Normals recipe is disabled.
7. Save with Lucky/Hyper Soda and Boss Brew active, record their remaining seconds, force-stop and leave the app closed for a minute. Reopen: remaining active-play time is restored without subtracting the closed minute. Verify stronger luck potion selection, Auto Roll, filters, Luck Cap, audio levels, vibration and screen-shake settings remain selected.
8. Also force-stop between ordinary autosaves. A process kill cannot deliver a pause/quit callback; the expected recovery point is the last completed save. Ordinary unsaved activity is bounded by the ten-active-second autosave interval. Consequential events must already have their immediate checkpoint. Confirm no partial wallet/inventory transaction appears after recovery.
9. Keep airplane mode enabled through the campaign, all five structures, all four bosses, Fast Travel and Variant Shrine. Defeat Singularity Admin, save and reopen. The completion portal and first-kill flag must persist, and completion must allow continued free roam with unlocked systems. No network connection may be needed at any step.
10. Check sustained combat/Auto Roll and a boss fight for frame pacing, responsive input, sound, low-memory recovery and battery behavior on the target device. Repeat background/force-stop near the start and end of a rare reveal; committed rewards must neither disappear from the checkpoint nor duplicate when reopening.

The automated desktop suite covers state restoration, recovery, timers, progression and dispatched UI input. It cannot establish physical airplane-mode operation, Android process-kill delivery, release signing, real cutout bounds or full-campaign pacing. Record device model, Android version, APK version, pass/fail and reproduction steps when completing this checklist.

## Required Android force-close matrix

Use the same installed test APK and signing identity throughout. Record the displayed successful save status before deliberate termination, unless specifically testing interruption during a write. Never clear app data. Desktop save/restart probes are separate evidence, not a substitute for these OS/device cases.

| Case | Device procedure and expected result | Physical Android result |
|---|---|---|
| 1 | Auto Roll ON → Home/background → resume: completed elapsed cooldowns credited once, partial cycle preserved, one AFK summary | **NOT RUN** |
| 2 | Auto Roll ON → background → Android App Info force-stop → reopen twice: only unconsumed elapsed time earns rewards | **NOT RUN** |
| 3 | Commit a rare multi-variant result → immediate force-stop → reopen: one copy/result and exactly one +1/+1 commit persist | **NOT RUN** |
| 4 | Sacrifice one valid Variant Shrine copy → force-stop → reopen: one copy removed, one unique base/category entry, identical multiplier | **NOT RUN** |
| 5 | Buy a skill → force-stop → reopen: one purchase and one wallet debit; Lifetime unchanged | **NOT RUN** |
| 6 | Buy a Breakthrough → force-stop → reopen twice: identical derived luck, no repeated ×20 | **NOT RUN** |
| 7 | Defeat a boss → force-stop → reopen: reward once and CombinedBossGate remains onward/completion state | **NOT RUN** |
| 8 | Unlock Dash at the Z2 gate before Espresso → force-stop → reopen: Dash still unlocked with no currency debit | **NOT RUN** |

Physical airplane-mode operation, cutout/gesture layout, touchscreen pinch, sustained frame pacing, thermal/battery behavior and human campaign difficulty are also **NOT RUN**. Prompt 16 final acceptance must retain that distinction even when all automated checks pass.
