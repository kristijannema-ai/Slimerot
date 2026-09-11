# Slimerot validation — prompts 1–4

Engine: official Godot 4.5.1 stable on Windows. The project runs headlessly and with the OpenGL compatibility renderer. Tests use isolated per-process files under `.godot/`, preserving player saves.

Result: **336 checks passed, 0 failures** in the combined rendered suite; the final headless pass uses the same assertions. No Slimerot script errors or leaked-object warnings remain.

## Automated coverage

The combined suites exercise real Godot nodes and input dispatch plus deterministic boundary tests:

- Original new-save, physics movement/collision, simultaneous joystick + ROLL, first ownership/equip, Bedroom-to-Backyard context travel, automatic combat, direct Coin rewards, and loss-free respawn.
- All 24 roster rows against the supplied damage/sell table, monotonic base damage by threshold, and exactly three added entries per unlocked zone.
- Strict positive score sampler endpoints, highest eligible threshold/equality/fallback logic, and interleaved thresholds across zones.
- First guaranteed base with all zones unlocked; 100 manual completions and 100 automatic completions each grant exactly 100 Rolls and Lifetime Rolls.
- Exclusive variant intervals and boundaries, exact marginal masses on a deterministic 40,000-point grid, +25% Variant Sense, and seeded independence from ordinary luck.
- Minor/checkpoint/potion luck multiplication, expiration, MAX/x20-era/x1 caps, cap locking, and combat independence.
- Quantity/discovery separation, exactly 24 actual Collection UI cards, per-copy favorites/equipment protection, all variant multipliers, strongest-team selection, same-base multi-equip, slot costs/prerequisites, and boss gating.
- Independent Coin Scavenger / Duplicate Dealer formulas, fixed first-boss bookkeeping, and permanent discovery after all copies are sold.
- Every reveal timing boundary, Skip Common, first-jackpot no-skip/no-replacement, queued feedback, repeat skipping, and no currency re-award from animation.
- Schema 3 round trips, schema 1/2 migration, backup recovery, duplicate-ID rejection, sole-source Rolls invariant and fractional-currency rejection.
- All 25 Roll node IDs, exact costs/currencies/prerequisites, mandatory spending blocks, insufficient funds, repeat-purchase rejection, and mainline completion without optional purchases.
- Every canonical cooldown including post-campaign 0.50s; each Breakthrough exactly x20; cumulative x30.36/x910.8/x28,462.5; stable derived values across node ordering and repeated save loads.
- Historical spend ledger, grandfathered legacy Auto Roll ancestors, unchanged wallets/Lifetime Rolls, and invalid canonical prerequisite-chain rejection.
- Super Roll at 100th-completion boundaries, rejected attempts, manual and automatic commit paths, cap-before-x5 behavior, and reload immediately before/after a Super completion.
- Variant Sense denominators 80/800/8,000; independent filter branches; discovered-only custom thresholds; Normal-only new-copy auto-sale; equality boundaries; group/copy favorites; equipment protection; real roll-to-sale Coin credit.
- Actual Auto Roll at 0.50s while physically moving beside active Backyard enemies and taking combat damage.
- All 21 Coin nodes: exact costs and node/zone/boss gates, Sell Terminal requirement, insufficient funding, duplicate-purchase protection and Final Bond's R18 gate.
- Additive 2.5x ordinary damage and 1.5x Boss Hunter, final rounding for all four variants, 250 max HP, 216 px/s movement, and independent +100% Scavenger/+75% Dealer.
- Same-base physical-copy multi-equip, no sixth slot or duplicate-ID equip, immediate rounded Team DPS updates and strongest-copy ranking.
- Exact Coins Earned/Spent accounting, fixed one-time boss payouts, protected sales, schema 4 round trip and legacy-slot migration without wallet loss.
- 500 px/s non-instant slime projectiles, straight locked flight/guaranteed impact, dead-target cancellation, no double hits, per-slot nearest targeting and independent one-second timers.
- Swept enemy projectile collision and movement dodging; four-second regen delay, boundary-crossing healing, damage reset, pause, max-HP clamp, and 1.5-second full-HP respawn with no progression loss.
- Pause behavior, reset hold threshold, cancellation, and complete canonical reset.

The test runner prints a single final check/failure count and exits nonzero on assertion failures. Save reset tests only delete the suite's isolated files.

## Render inspection

Inspected fresh Bedroom, Collection, Team, Inventory, and Golden Brainrot Singularity jackpot captures. Collection cards wrap names, retain threshold labels, and display distinct silhouettes for undiscovered bases. HUD Lifetime Rolls was removed. The reveal layer keeps the joystick and ROLL control usable. Jackpot bounce is centered to preserve screen margins.

Stage 3 additionally inspects mainline, optional branches, and Roll Settings captures at the 720×1280 virtual resolution. Scrollable cards expose prerequisites, descriptions and purchase state; the high-luck wallet and Super counter fit. Breakthrough banners expire without pausing movement.

Stage 4 Coin Tree and five-copy Team captures were inspected. Per-hit damage, raw DPS, portraits, purchase state and prerequisite labels fit the portrait layout. The rendered projectile collision fixture explicitly synchronizes teleported physics bodies before querying, matching live physics behavior.

Audio playback is skipped in headless mode and stopped/released when reveals end or the scene exits. The rendered build uses a generated sound sting; no third-party media is required.

The sandbox emits an engine certificate-store diagnostic at startup and the editor reports unavailable Android build tools. Neither is a Slimerot script/parser failure. Test logs are redirected to the writable workspace. No APK build, physical Android test, or long-session economy timing is claimed.

## Manual acceptance checklist

1. Start with a fresh save. Walk and roll simultaneously using touch or WASD + Space. Confirm the first base is Tung Tung Tung Sahur, immediately equipped, and both currency counts increase by one. Check Lifetime Rolls in Stats.
2. Continue rolling at the 2.4-second cooldown. Confirm free rolls, normal threshold-labeled toasts, Z1's three possible bases, and no scene change.
3. Open Inventory and try DPS/rarity/name sorting. Use the paginated copy manager; favorite one copy, equip another, and verify both sale protections. Repair the Sell Terminal before trying sales.
4. Open Collection: exactly 24 base cards, correct discovery states and current best variant. Sell every unprotected copy of one base and verify its discovery remains.
5. Repair the Shrine, buy C01 for 100 Coins and Slot 2 for 350 Coins, own multiple copies, and use Auto Equip Strongest. Verify two strongest copies equip, including duplicate bases. Later slots require their listed Bond and boss gates.
6. Open Skills immediately from a new save. R01 costs 25 Rolls; follow R01/R02/R03 and enable Auto Roll while walking/fighting. Confirm purchases lower Rolls without lowering Lifetime Rolls. Optional branches must never block the mainline.
7. Inspect Shiny outline/sparkles, Glitched jitter/chromatic offset, Golden aura, each reveal tier, and sound/shake settings. A first jackpot cannot be skipped; repeats can. Continue holding movement and rolling during feedback.
8. Pause, background/resume, and restart. Verify no offline progress; balances, favorites, discovery, equipment, selected cap and statistics restore. A stage-one save should migrate without resetting the starter or currencies.
9. Hold Reset for less than three seconds and release: nothing changes. On a disposable save, hold for the full duration: all currencies, inventory/discovery, upgrades, caps and location reset.
10. On Android hardware: verify simultaneous touch, portrait fit, gesture insets, audio, background/OS-kill save recovery and offline use. SDK/export-template installation and signing are required for this pass.
11. In a disposable progressed save, purchase R08/R13/R18: each banner and uncapped Luck value jumps exactly x20. R08 defaults to MAX. Test x20-era/x1 caps and unchanged Team DPS; Super Roll applies x5 after the selected cap.
12. Unlock RO2 and enable auto-sale. Roll Normal duplicates below the selected threshold: only the newly rolled copy sells. Keep favorite/equipped copies and every non-Normal variant. Test RO3 choices and RO4 discovered-only thresholds. Disable auto-sale and verify inventory resumes growing.
13. With RO5, stop at Lifetime Rolls ending in 99, restart, and complete one manual/automatic roll. Confirm a single x5 result and one currency grant; restarting afterwards must not replay it. Verify RO7's 0.50s cooldown and RO1's short common toast.
14. Fight Laglings while walking and rolling: each equipped slime orbits in slot order and shoots from its own position. Watch projectiles travel instead of causing instant damage; slimes ignore terrain and never take damage. Move away to dodge contact attacks.
15. Take damage, then stay clear: HP remains unchanged for four seconds, then regenerates at 5% max HP/sec. Pause freezes regeneration. Die on a disposable save: observe the 1.5s fade and full-HP entrance respawn, with wallets, equipment and inventory preserved.
16. In a progressed fixture, purchase Bonds, Boss Hunter, Toughness and Fleet Feet. Verify ordinary per-hit damage is rounded after 2.5x at Final Bond, boss damage gets a further 1.5x, raw Team DPS excludes the conditional boss bonus, HP reaches 250 and move speed 216 px/s. Check Scavenger affects only normal kills and Dealer only sales.
17. Reload a stage-three save with old slot upgrades: team capacity, wallets and historical Coin accounting survive migration. New Coin nodes show exact canonical costs and world prerequisites.
