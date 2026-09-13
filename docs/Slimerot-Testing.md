# Slimerot validation — prompts 1–7

Engine: official Godot 4.5.1 stable on Windows. The project runs headlessly and with the OpenGL compatibility renderer. Tests use isolated per-process files under `.godot/`, preserving player saves.

Result: **844 checks passed, 0 failures** in the combined rendered suite; the final headless pass uses the same assertions. No Slimerot script errors or leaked-object warnings remain.

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

Stage 5 adds every fixed HP/reward/damage row and level range, all kill/gate/boss requirements, physical Z1→Z2 interaction from fresh currencies and starter ownership, repeated fixed-reward farm kills/respawns, exact structure/gate costs, no duplicate kill credits, zero-balance return traversal, persistent global pool expansion, and boss-entry readiness without automatic victory. Every later scene loads independently with 11 correctly configured enemies. Grid paths verify both main routes and closed farming loops. Fixtures verify each gate's exact price, one-Coin-short rejection, current-zone death/respawn, and zero progression loss. Schema 5 round trips current Z8/gates/kills and migrates previous unlocks. Shooter retreat/approach, firing intervals and fixed projectile damage are checked. Wealth and luck do not alter enemy data.

The Z1 economy fixture uses seven actual rounded starter hits per 45-HP Chaser and 50 repeated kills for 250 Coins: 25 Shrine + 75 Sell Terminal + 150 gate. It advances respawn time directly, so this proves accounting/repeatability rather than a timed beginner playtest. The earlier live combat regression exercises real projectile cadence. Full 12-minute beginner onboarding and 3-hour campaign/Coins-per-minute pacing remain manual validation.

## Render inspection

Inspected fresh Bedroom, Collection, Team, Inventory, and Golden Brainrot Singularity jackpot captures. Collection cards wrap names, retain threshold labels, and display distinct silhouettes for undiscovered bases. HUD Lifetime Rolls was removed. The reveal layer keeps the joystick and ROLL control usable. Jackpot bounce is centered to preserve screen margins.

Stage 3 additionally inspects mainline, optional branches, and Roll Settings captures at the 720×1280 virtual resolution. Scrollable cards expose prerequisites, descriptions and purchase state; the high-luck wallet and Super counter fit. Breakthrough banners expire without pausing movement.

Stage 4 Coin Tree and five-copy Team captures were inspected. Per-hit damage, raw DPS, portraits, purchase state and prerequisite labels fit the portrait layout. The rendered projectile collision fixture explicitly synchronizes teleported physics bodies before querying, matching live physics behavior.

Stage 5 inspects themed campaign captures, the Backyard purchase gate, and a boss-locked exit. HUD zone names/level ranges/kill counts and contextual costs fit portrait controls. The obsolete later-zone Sell Terminal tutorial hint was removed. Reusable original procedural props distinguish trees, houses, pyramids, city buildings, Backrooms walls, Moon craters and dimensional crystals.

Audio playback is skipped in headless mode and stopped/released when reveals end or the scene exits. The rendered build uses a generated sound sting; no third-party media is required.

The sandbox emits an engine certificate-store diagnostic at startup and the editor reports unavailable Android build tools. Neither is a Slimerot script/parser failure. Test logs are redirected to the writable workspace. No APK build, physical Android test, or long-session economy timing is claimed.

## Manual acceptance checklist

1. Start with a fresh save. Walk and roll simultaneously using touch or WASD + Space. Confirm the first base is Tung Tung Tung Sahur, immediately equipped, and both currency counts increase by one. Check Lifetime Rolls in Stats.
2. Continue rolling at the 2.4-second cooldown. Confirm free rolls, normal threshold-labeled toasts, Z1's three possible bases, and no scene change.
3. Open Inventory and try DPS/rarity/name sorting. Use the paginated copy manager; favorite one copy, equip another, and verify both sale protections. Repair the Sell Terminal before trying sales.
4. Open Collection: exactly 24 base cards, correct discovery states and current best variant. Sell every unprotected copy of one base and verify its discovery remains.
5. Repair the Shrine, buy C01 for 100 Coins and Slot 2 for 350 Coins, own multiple copies, and use Auto Equip Strongest. Verify two strongest copies equip, including duplicate bases. Later slots require their listed Bond and boss gates.
6. Repair the Bedroom Shrine and open Skills. R01 costs 25 Rolls; follow R01/R02/R03 and enable Auto Roll while walking/fighting. Confirm purchases lower Rolls without lowering Lifetime Rolls. Optional branches must never block the mainline.
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
18. On a disposable fresh save, roll the guaranteed starter, enter Backyard, and farm the outer route. Return to the Bedroom Hub to repair both structures, reach at least 12 kills and save 150 Coins. Approach the far gate: confirm exact requirements, purchase and walk into Italian Village. Backtrack and return with zero Coins; no second payment occurs.
19. In Italian Village, reach 20 kills and 900 Coins without a boss flag. Its exit must remain locked and preserve Coins. Enter the Espresso Golem arena and defeat it. Only the real victory grants the flag/reward; the exit gate still costs 900 Coins.
20. Visit each fixture-unlocked zone: traverse both the main path and farming loop, observe its themed props, distinct Chaser/Shooter/Tank silhouettes and fixed levels, dodge Shooter shots, and repeat farm spawns. Check Z3/Z5/Z7 walls at 40/60/90 kills and 4,000/75,000/1,200,000 Coins.
21. Die in each zone and reload saves from later zones: current-zone entrance, full HP, gate flags, Coins, Rolls, equipment and pool unlocks remain correct. Confirm Z8 requires 100 kills plus its final boss and has no extra paid gate or Z9.

## Stage 6 acceptance and validation

The combined suite adds all five exact structure locations/costs and one-time repair flags; crafting location/recipe gates; bottle inventory; stronger-soda protection without consumption; simultaneous 300s luck/Brew channels; pause/expiry; Boss Hunter ×1.25 Brew stacking; protected five-copy mutation and atomic fee failure; locked/invalid Fast Travel targets and current entrance destinations. Boss tests cover exact HP/contact/rewards, closed arenas, no Fast Travel/gate escape, reset boundaries, restored boss HP, every pattern's timing/damage, the 40% Admin phase, one-time soda/Coin rewards, death reset, portal completion and schema 6 persistence. Arena draw order is explicitly checked after rendered inspection caught and fixed an obscured player.

Rendered Espresso slam, Sand Router fan, Janitor burst, Admin shrinking circle, Potions, Map, Mutation and Completion captures were inspected. Boss combat art and telegraphs use original procedural placeholders. Deterministic encounter tests advance pattern timers and apply defeat damage directly; they do not establish campaign-length pacing or real-device performance.

22. In a fresh Hub, confirm Skills is unavailable until the 25-Coin Shrine repair. Confirm the Sell Terminal is also in the Hub and costs 75. Reopen an existing save and verify already repaired flags remain set.
23. At each qualified boss entrance, enter and observe closed arena bounds. Move across the gold reset line: no wallet, inventory or HP loss; re-enter for full boss HP. Die in the arena and verify ordinary 1.5s current-zone respawn. Fast Travel stays disabled during fights.
24. Dodge Espresso's 0.8s slam warning after 3s chase; Router's five-wave 4s fan; Janitor's 6s teleport and two aimed three-shot bursts; Admin's alternating patterns and shrinking warning circles below 40% HP. Keep Auto Roll running while moving and attacking through slimes.
25. Verify each boss pays its exact first-kill Coins once, with Lucky/Hyper Soda bottles for Z2/Z4. Confirm repeat entry or reload cannot farm the reward and that Coin Scavenger never increases it.
26. Repair the Z2 Bench for 900. Craft/drink Lucky Soda, unlock Hyper with Z4 and Brew with Z6. Pause, background and restart: only active time counts. A weaker soda must not consume its bottle while Hyper is active; Brew coexists and affects bosses only.
27. Repair the Z4 Pillar for 15,000. Map lists Hub and all zones, disabling locked destinations. Select an unlocked zone and confirm its entrance arrival without changing unlocks or wallet.
28. Repair the Z6 Lab for 250,000. With seven identical Normal copies, equip one and favorite one; mutate the other five for the exact fee. Confirm one Shiny appears and protected copies remain. Insufficient funds or copies must consume nothing.
29. Defeat Singularity Admin, enter the completion portal, and restart. The victory, 6,000,000-Coin first payout, portal and completion state persist. Continuing exploration does not grant another payout or start prestige.
## Prompt 7 mobile interaction validation

The Prompt 6 baseline passed 644 checks before implementation. Prompt 7 adds 200 assertions, including safe-inset coordinate scaling, actual touch scrolling from buttons, simultaneous joystick/ROLL, contextual interaction, Android Back notification routing, gated menus, reset cancellation, all reveal deadlines/skips/queues, all three Breakthrough purchases, media loading and volume settings. See [Slimerot-Prompt-7.md](Slimerot-Prompt-7.md) for the complete implementation and manual device checklist.

Rendered layouts were inspected at 720×1280, 720×1440 and 800×1280. Physical Android hardware, APK export, cutouts and audio mixing still require device testing. In headless mode the presentation service validates resources and settings without starting a speaker playback; rendered tests exercise the real audio players. Windows host certificate-store and restricted shader-cache warnings are external to the game scripts.
