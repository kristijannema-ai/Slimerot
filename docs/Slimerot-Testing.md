# Slimerot stage-one validation

Engine: official Godot 4.5.1 stable, Windows. Date: 2026-09-11.

## Automated and rendered checks performed

33 integration assertions passed in a headless run and in a real OpenGL rendered run. The tests exercise actual Godot nodes, physics frames, input dispatch, managers, and filesystem operations. Bedroom, first-roll, and Backyard screenshots were inspected; world labels overlapping the HUD were removed and HUD contrast improved afterward.

Covered: fresh wallets and stats; Bedroom spawn beside exit; 180 px/s desktop movement; first roll during movement; exact +1 Rolls and Lifetime Roll; starter ownership and auto-equip; cooldown rejection; continued movement during reveal; wall collision; real context transition; four Backyard Laglings; touch capture; second-finger roll without stealing joystick input; touch release; automatic attacks and direct Coin rewards; current-zone death respawn without losses; 25-Coin Shrine repair and repeat-purchase prevention; Auto Roll purchase/completion; favorite/equipment selling protection; complete schema; temporary writes, generation rotation, round-trip load, corrupted-main recovery, and duplicate-copy rejection.

The Windows sandbox cannot access the operating-system certificate store; the official engine prints a certificate-store diagnostic at startup. Slimerot itself has no network calls. Tests use a writable log path and isolated test saves under `.godot/` because this environment also restricted creation of the normal AppData save directory. Save logic itself is tested using actual files, including rename and backup recovery.

## Manual acceptance checklist

These are instructions for a human/device pass, not a claim that physical-device testing was performed.

1. Use a fresh save directory or back up and move your existing `Slimerot-save.json` and recovery files. Launch the game. Confirm Bedroom, 0/0/0 wallets, x1.00 luck, 100 HP, Auto Roll locked, and one slot.
2. Drag the joystick continuously. Tap ROLL with a second finger. Confirm Tung Tung Tung Sahur, Rolls 1, Lifetime 1, Team DPS 10, and an equipped follower. Movement continues through the reveal.
3. Repeatedly tap during the 2.4-second cooldown; counts must stay unchanged until another roll completes. Repeat with WASD + Space on desktop.
4. Move to the green Bedroom exit and use Enter Backyard / E. Confirm a real grass area and visible Level 1 Laglings. Walk into furniture/fences and verify collision.
5. Approach a Lagling within 180 px, keep moving, and watch automatic attacks. A kill adds five Coins directly. Allow enemies to defeat you; confirm respawn at the Backyard entrance with all currencies/copies preserved.
6. After five kills, repair the Shrine for 25 Coins. Buy available early Roll nodes; Auto Roll works while moving when unlocked and enabled.
7. Repair the Sell Terminal for 75 Coins. Favorite your starter group, try selling, and verify protection. Unfavorite and sell duplicates; the equipped copy remains.
8. Background the app, wait, and resume. Confirm there are no offline rolls or active-play gains. Quit/relaunch after a roll and after a purchase; confirm restored balances, copies, equipment, settings, and cooldown.
9. On a physical Android phone, check portrait layout, simultaneous touch, system navigation/gesture insets, background/foreground lifecycle, local saves after OS process termination, and APK permissions in airplane mode.

Android build/signing, physical multitouch, long-session economy pacing, and Italian Village progression remain unverified or outside prompt-one scope.
