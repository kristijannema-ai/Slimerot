# Slimerot validation — prompts 1–13

Engine: official Godot 4.5.1 stable on Windows. The project runs headlessly and with the OpenGL compatibility renderer. Tests use isolated per-process files under `.godot/`, preserving player saves.

Current Prompt 13 validation: **1,766 combined headless checks, zero failures**; **68 focused rendered progression/save checks**; **37 process-restart checks** (11 ordinary, 13 first offline reopen, 13 second reopen); **154 isolated exported-resource checks**; and a 120-frame packed main-scene smoke test. Final logs contain no Slimerot script errors. Early Auto, Super branch and tier-III Settings captures were inspected. See the [Prompt 13 report](Slimerot-Prompt-13.md) for the exact node delta, schema 11 compatibility and provisional balance.

Historical Prompt 12 validation: **1,662 combined headless checks, zero failures**, including Prompt 11 input/inventory/offline suites and the new RNG/migration suites. **161 focused rendered checks** passed with no Slimerot script errors. The actual process-kill save probe passed 11 checks; two independent reopened offline processes passed 11 each. The isolated exported-resource audit passed **152 checks**. Rendered combined-variant reveal and Variant Shrine captures were inspected. See the [Prompt 12 report](Slimerot-Prompt-12.md) for requirements and provisional constants. Screenshots, logs, packs and generated reports are local validation artifacts, excluded from publication.

Historical Prompt 11 validation: **1,505 headless checks passed, zero failures**; **1,504 rendered checks passed** before one additional fragmented-range assertion, followed by **118 focused rendered checks**. Two independent post-force-kill launches each passed **11 checks**, proving one offline batch is not claimed twice. Import validation is clean apart from existing machine certificate/Android SDK warnings. See the [Prompt 11 report](Slimerot-Prompt-11.md) for issue mapping, schema 9, measured inventory/save performance and the Android procedure. The following Prompt 10 results are retained as historical baseline evidence.

Historical Prompt 10 result: **1,383 checks passed, 0 failures** in both the final combined headless and rendered suites using the unchanged Prompt 9 balance tables. An actual forced-termination/reopen probe passed **11 additional checks** on the final source, with the writer killed after its durable save completed. An isolated exported-resource audit passed **148 checks** and the packed main scene launched successfully. No Slimerot script errors or leaked-object warnings remain in the final runs. The combined suite retains the 1,165-check merged Prompt 9 baseline and its earlier save/UI coverage.

## Prompt 10 final integration results

The final combined suite passes **1,383 checks** in both headless and rendered runs. New suites cover a continuous accelerated nine-location campaign with actual context interactions/manager signals, all structures and skills, completion and restored free roam; 5,000-copy save/equip/sale protection and HUD identity restoration; and bounded endurance. Fixtures fund progression and advance selected timers/resolve combat directly, so these are integration checks rather than a human campaign.

Endurance coverage exercises 1,800 projectile lifetimes, 45 zone loads, 20 arena resets, 3,600 automatic rolls (30 accelerated minutes), 84 menu cycles and 1,000 sound/track switches. Node counts, weak references, pending reveals and resource caches remain bounded after teardown. It does not establish real-device memory, battery or 30-minute wall-clock performance.

The 5,000-copy regression originally measured a 4,859.726 ms Auto Equip and 400.976/652.830/751.387 ms saves. The final headless result measured 9.155 ms Auto Equip, 100.049/146.057/136.282 ms saves, 68.560 ms load and 5.174 ms for a protected 4,998-copy duplicate sale. No hardware-specific timing assertion is used. Saves still run synchronously; target-device storage/frame pacing remains a manual check.

The separate forced-termination/reopen probe passes **11 checks**. The exported resource audit passes **148 checks**, and a packed main-scene launch completes 120 frames without Slimerot errors. The pack audit runs in an empty scratch project with no source assets/scripts, verifies all gameplay resources plus 80 art SVGs/app icon/10 WAVs and rejects included developer tools. It also checks every packed global-class path; this caught and led to removal of the excluded pacing model's global registration. The model remains explicitly preloaded by its estimator and tests.

To reproduce the pack audit after normal import, export a pack with the checked-in Android preset. Create an empty scratch project whose `project.godot` contains only `config_version=5`. Run the audit from that scratch directory, substituting absolute paths:

```sh
godot --headless --path <Slimerot project> --export-pack "Slimerot Android" <absolute Slimerot-final.pck>
godot --headless --path <scratch directory> --script <absolute Slimerot project>/tools/SlimerotExportAudit.gd -- --slimerot-export-audit --slimerot-export-pack=<absolute Slimerot-final.pck> --slimerot-export-audit-output=<absolute Slimerot-export-audit.json>
```

Seven source configuration assertions pass for app naming, portrait/stretch settings, offline permissions, haptics, release version and export exclusions. The unchanged twelve-seed pacing estimate was rerun. Manual review inspected rendered HUD, Settings and final-boss telegraph captures; physical touch and a manually played campaign were not performed. The existing Prompt 7 synthetic touch/Back/reveal/menu and Prompt 8 save/reset assertions remain passing. Full findings, files, limitations and device checklist are in the [final audit](Slimerot-Final-Audit.md).

## Automated coverage

The combined suites exercise real Godot nodes and input dispatch plus deterministic boundary tests:

- Original new-save, physics movement/collision, simultaneous joystick + ROLL, first ownership/equip, Bedroom-to-Backyard context travel, automatic combat, direct Coin rewards, and loss-free respawn.
- All 24 roster rows against the supplied damage/sell table, monotonic base damage by threshold, and all 24 entries eligible at every unlocked zone.
- Strict positive score sampler endpoints, highest threshold/equality/fallback logic, and interleaved thresholds across zones.
- First guaranteed base with all zones unlocked; 100 manual completions and 100 automatic completions each grant exactly 100 Rolls and Lifetime Rolls.
- Independent variant intervals and boundaries, all eight masks, exact marginal counts on a deterministic 64,000-point grid, +25% Variant Sense, and seeded independence from ordinary luck.
- Minor/checkpoint/potion luck multiplication, expiration, MAX/x20-era/x1 caps, cap locking, and combat independence.
- Quantity/discovery separation, exactly 24 actual Collection UI cards, per-copy favorites/equipment protection, all variant multipliers, strongest-team selection, same-base multi-equip, slot costs/prerequisites, and boss gating.
- Independent Coin Scavenger / Duplicate Dealer formulas, fixed first-boss bookkeeping, and permanent discovery after all copies are sold.
- Every reveal timing boundary, Skip Common, first-jackpot no-skip/no-replacement, queued feedback, repeat skipping, and no currency re-award from animation.
- Schema 3 round trips, schema 1/2 migration, backup recovery, duplicate-ID rejection, sole-source Rolls invariant and fractional-currency rejection.
- All 25 Roll node IDs, exact costs/currencies/prerequisites, mandatory spending blocks, insufficient funds, repeat-purchase rejection, and mainline completion without optional purchases.
- Every canonical cooldown including post-campaign 0.50s; each Breakthrough exactly x20; cumulative x30.36/x910.8/x28,462.5; stable derived values across node ordering and repeated save loads.
- Historical spend ledger, grandfathered legacy Auto Roll ancestors, unchanged wallets/Lifetime Rolls, and invalid canonical prerequisite-chain rejection.
- Super Roll at 100th-completion boundaries, rejected attempts, manual and automatic commit paths, cap-before-x5 behavior, and reload immediately before/after a Super completion.
- Variant Sense denominators 80/320/1,280; independent filter branches; discovered-only custom thresholds; Normal-only new-copy auto-sale; equality boundaries; group/copy favorites; equipment protection; real roll-to-sale Coin credit.
- Actual Auto Roll at 0.50s while physically moving beside active Backyard enemies and taking combat damage.
- All 21 Coin nodes: exact costs and node/zone/boss gates, Sell Terminal requirement, insufficient funding, duplicate-purchase protection and Final Bond's R18 gate.
- Additive 2.5x ordinary damage and 1.5x Boss Hunter, final rounding for all eight variant masks, 250 max HP, 216 px/s movement, and independent +100% Scavenger/+75% Dealer.
- Same-base physical-copy multi-equip, no sixth slot or duplicate-ID equip, immediate rounded Team DPS updates and strongest-copy ranking.
- Exact Coins Earned/Spent accounting, fixed one-time boss payouts, protected sales, schema 4 round trip and legacy-slot migration without wallet loss.
- 500 px/s non-instant slime projectiles, straight locked flight/guaranteed impact, dead-target cancellation, no double hits, per-slot nearest targeting and independent one-second timers.
- Swept enemy projectile collision and movement dodging; four-second regen delay, boundary-crossing healing, damage reset, pause, max-HP clamp, and 1.5-second full-HP respawn with no progression loss.
- Pause behavior, reset hold threshold, cancellation, and complete canonical reset.

The test runner prints a single final check/failure count and exits nonzero on assertion failures. Save reset tests only delete the suite's isolated files.

Stage 5 adds every fixed HP/reward/damage row and level range, all kill/gate/boss requirements, physical Z1→Z2 interaction from fresh currencies and starter ownership, repeated fixed-reward farm kills/respawns, exact structure/gate costs, no duplicate kill credits, zero-balance return traversal, persistent global pool expansion, and boss-entry readiness without automatic victory. Every later scene loads independently with 11 correctly configured enemies. Grid paths verify both main routes and closed farming loops. Fixtures verify each gate's exact price, one-Coin-short rejection, current-zone death/respawn, and zero progression loss. Schema 5 round trips current Z8/gates/kills and migrates previous unlocks. Shooter retreat/approach, firing intervals and fixed projectile damage are checked. Wealth and luck do not alter enemy data.

The current Z1 economy fixture uses seven actual rounded starter hits per 45-HP Chaser and 220 repeated kills for 1,100 Coins: 25 Shrine + 75 Sell Terminal + 1,000 gate. It advances respawn time directly, so this proves accounting/repeatability rather than a timed beginner playtest. The earlier live combat regression exercises real projectile cadence. Full 12-minute beginner onboarding and 3-hour campaign/Coins-per-minute pacing remain manual validation; Prompt 9's estimates are reported separately below.

## Render inspection

Inspected fresh Bedroom, Collection, Team, Inventory, and Golden Brainrot Singularity jackpot captures. Collection cards wrap names, retain threshold labels, and display distinct silhouettes for undiscovered bases. HUD Lifetime Rolls was removed. The reveal layer keeps the joystick and ROLL control usable. Jackpot bounce is centered to preserve screen margins.

Stage 3 additionally inspects mainline, optional branches, and Roll Settings captures at the 720×1280 virtual resolution. Scrollable cards expose prerequisites, descriptions and purchase state; the high-luck wallet and Super counter fit. Breakthrough banners expire without pausing movement.

Stage 4 Coin Tree and five-copy Team captures were inspected. Per-hit damage, raw DPS, portraits, purchase state and prerequisite labels fit the portrait layout. The rendered projectile collision fixture explicitly synchronizes teleported physics bodies before querying, matching live physics behavior.

Stage 5 inspects themed campaign captures, the Backyard purchase gate, and a boss-locked exit. HUD zone names/level ranges/kill counts and contextual costs fit portrait controls. The obsolete later-zone Sell Terminal tutorial hint was removed. Reusable original procedural props distinguish trees, houses, pyramids, city buildings, Backrooms walls, Moon craters and dimensional crystals.

Audio playback is skipped in headless mode and stopped/released when reveals end or the scene exits. The rendered build uses a generated sound sting; no third-party media is required.

The sandbox emits an engine certificate-store diagnostic at startup and the editor reports unavailable Android build tools. Neither is a Slimerot script/parser failure. Test logs are redirected to the writable workspace. No APK build, physical Android test, or long-session economy timing is claimed.

## Manual acceptance checklist

1. Start with a fresh save. Walk and roll simultaneously using touch or WASD + Space. Confirm the first base is Tung Tung Tung Sahur, immediately equipped, and both currency counts increase by one. Check Lifetime Rolls in Stats.
2. Continue rolling at the 2.4-second cooldown. Confirm free rolls, normal threshold-labeled toasts, all 24 bases available from Z1, and no scene change.
3. Open Inventory and try DPS/rarity/name sorting. Use the paginated copy manager; favorite one copy, equip another, and verify both sale protections. Repair the Sell Terminal before trying sales.
4. Open Collection: exactly 24 base cards, correct discovery states and current best variant. Sell every unprotected copy of one base and verify its discovery remains.
5. Repair the Shrine, buy C01 for 100 Coins and Slot 2 for 350 Coins, own multiple copies, and use Auto Equip Strongest. Verify two strongest copies equip, including duplicate bases. Later slots require their listed Bond and boss gates.
6. Repair the Bedroom Shrine and open Skills. R01 costs 25 Rolls; buy R03 for 40 Rolls immediately after R01, enable Auto Roll, then buy R02 for 75 Rolls while walking/fighting. Confirm purchases lower Rolls without lowering Lifetime Rolls. Optional branches must never block the mainline.
7. Inspect Shiny outline/sparkles, Glitched jitter/chromatic offset, Golden aura, each reveal tier, and sound/shake settings. A first jackpot cannot be skipped; repeats can. Continue holding movement and rolling during feedback.
8. Pause, background/resume, and restart. Verify enabled Auto Roll catches up exactly once, disabled Auto Roll earns nothing, and active timers remain frozen; balances, favorites, discovery, equipment, selected cap and statistics restore. A stage-one save should migrate without resetting the starter or currencies.
9. Hold Reset for less than three seconds and release: nothing changes. On a disposable save, hold for the full duration: all currencies, inventory/discovery, upgrades, caps and location reset.
10. On Android hardware: verify simultaneous touch, portrait fit, gesture insets, audio, background/OS-kill save recovery and offline use. SDK/export-template installation and signing are required for this pass.
11. In a disposable progressed save, purchase R08/R13/R18: each banner and uncapped Luck value jumps exactly x20. R08 defaults to MAX. Test x20-era/x1 caps and unchanged Team DPS; Super Roll applies its current tier’s ×5/×10/×20 after the selected cap.
12. Unlock RO2 and enable auto-sale. Roll Normal duplicates below the selected threshold: only the newly rolled copy sells. Keep favorite/equipped copies and every non-Normal variant. Test RO3 choices and RO4 discovered-only thresholds. Disable auto-sale and verify inventory resumes growing.
13. With RO5, stop one roll before the saved trigger, restart, and complete one manual/automatic roll. Confirm a single ×5 result and one currency grant. Upgrade mid-cycle to RO8 then RO9: retain an earlier trigger, cap remaining waits at 75/50 and confirm ×10/×20 results. Restart and offline catch-up must preserve the phase without replay. Verify RO7's 0.50s cooldown and RO1's short common toast.
14. Fight Laglings while walking and rolling: each equipped slime orbits in slot order and shoots from its own position. Watch projectiles travel instead of causing instant damage; slimes ignore terrain and never take damage. Move away to dodge contact attacks.
15. Take damage, then stay clear: HP remains unchanged for four seconds, then regenerates at 5% max HP/sec. Pause freezes regeneration. Die on a disposable save: observe the 1.5s fade and full-HP entrance respawn, with wallets, equipment and inventory preserved.
16. In a progressed fixture, purchase Bonds, Boss Hunter, Toughness and Fleet Feet. Verify ordinary per-hit damage is rounded after 2.5x at Final Bond and 3x with C23, boss damage gets a further 1.5x, raw Team DPS excludes the conditional boss bonus, HP reaches 250 and move speed reaches 243 px/s with C25. Check Scavenger affects only normal kills and Dealer only sales.
17. Reload a stage-three save with old slot upgrades: team capacity, wallets and historical Coin accounting survive migration. New Coin nodes show exact canonical costs and world prerequisites.
18. On a disposable fresh save, roll the guaranteed starter, enter Backyard, and farm the outer route. Return to the Bedroom Hub to repair both structures, reach at least 12 kills and save 1,000 Coins. Approach the far gate: confirm exact requirements, purchase and walk into Italian Village. Backtrack and return with zero Coins; no second payment occurs.
19. In Italian Village, reach 20 kills and 4,000 Coins without a boss flag. Its exit must remain locked and preserve Coins. Enter the Espresso Golem arena and defeat it. Only the real victory grants the flag/reward; the exit gate still costs 4,000 Coins.
20. Visit each fixture-unlocked zone: traverse both the main path and farming loop, observe its themed props, distinct Chaser/Shooter/Tank silhouettes and fixed levels, dodge Shooter shots, and repeat farm spawns. Check Z3/Z5/Z7 walls at 40/60/90 kills and 30,000/200,000/5,000,000 Coins. The complete Z1–Z8 gate-price sequence is 1,000/4,000/30,000/18,000/200,000/1,000,000/5,000,000/0 Coins.
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
28. Repair the Z6 Variant Shrine for 250,000. Offer one unprotected variant copy to one active category. Confirm no Coin fee, one consumed physical copy and one unique-base increase. Duplicate base/category offerings and equipped/favorite copies must consume nothing. A combined copy must increase only the chosen category; Normal copies have no offering action.
29. Defeat Singularity Admin, enter the completion portal, and restart. The victory, 6,000,000-Coin first payout, portal and completion state persist. Continuing exploration does not grant another payout or start prestige.
## Prompt 7 mobile interaction validation

The Prompt 6 baseline passed 644 checks before implementation. Prompt 7 adds 200 assertions, including safe-inset coordinate scaling, actual touch scrolling from buttons, simultaneous joystick/ROLL, contextual interaction, Android Back notification routing, gated menus, reset cancellation, all reveal deadlines/skips/queues, all three Breakthrough purchases, media loading and volume settings. See [Slimerot-Prompt-7.md](Slimerot-Prompt-7.md) for the complete implementation and manual device checklist.

Rendered layouts were inspected at 720×1280, 720×1440 and 800×1280. Physical Android hardware, APK export, cutouts and audio mixing still require device testing. In headless mode the presentation service validates resources and settings without starting a speaker playback; rendered tests exercise the real audio players. Windows host certificate-store and restricted shader-cache warnings are external to the game scripts.

## Prompt 8 save hardening validation

The baseline from merged Prompt 7 passed all 844 checks before changes. The final combined suite retains that coverage and adds 102 persistence checks: real 100-roll and skill-spend accounting; B1 repeated load; ordered physical copies, favorites and sold-out collection history; potion channels and settings; plain JSON schema 1–6 imports; invalid/future schemas; checksum damage; newer/stale temporary generations; reset recovery including a protected future version; write failure; notification overlap; ten-second autosave; structure/gate/boss/mutation/rare-roll/completion writes.

A separate SlimerotRestartProbe process created a progressed B1 save, printed readiness, and was forcibly terminated via Stop-Process -Force. A new Godot process passed 11 assertions for currencies, team order/quantities/favorites, collection, derived luck, exact potion/active-play timers, cooldown, zone/gates/kills and final completion. This validates reopening after a real desktop process kill rather than only calling load inside the same process.

Prompt 7 Settings and portrait HUD captures were inspected; existing multi-touch, scrolling, menu actions, Back handling, reveal queue, audio and reset cancellation assertions passed. Source/export audits found no runtime network APIs or URLs, with Android Internet/network-state permissions disabled. Tests ran in the network-restricted workspace. Physical Android airplane-mode launch-to-final-boss and 1h/2h/3h pacing still require a device/long-session playtest; those are not claimed here.

Save implementation and recovery limits: [Slimerot-Saves.md](Slimerot-Saves.md). Device checklist: [Slimerot-Android.md](Slimerot-Android.md). Test files are isolated under .godot and excluded from Android exports. Import and test commands used an explicit workspace --log-file to avoid this sandbox's user-log-directory restriction. The certificate-store startup warning and missing Android build-tools warning are environmental; final runs contain no Slimerot parser/runtime failures.

## Prompt 9 integration and pacing validation

The final combined headless and rendered suites each pass **1,165 checks**. Prompt 9 includes **87 developer-logger checks** covering explicit debug opt-in, absence on ordinary launches, required snapshot fields, strongest currently owned/equipped copies, active-time sampling, bounded event/sample buffers, timestamped milestones, JSON/text export and visible write failures. The observer leaves saves, progression and both rolling RNG streams unchanged. Save-load tests cover identical, forward and backward clocks, import baselines without invented milestones, load during a boss fight, and clean disconnection. Overlay checks cover safe-area layout and simultaneous touch controls. The rendered overlay and existing HUD/Settings captures were inspected.

Balance tests use actual CombatManager projectiles stepped at 60 Hz against stationary targets. Appropriately equipped Normal teams kill Chasers in all eight zones within 2.5–12.5 seconds and defeat all four boss fixtures within 50–240 seconds. These fixtures exercise hit cadence, projectile flight and exact reward accounting, but freeze enemy AI for controlled timing. A separate normal-speed fight exercises moving input, live enemy AI, Auto Roll completions, projectile kills, Coin rewards and the ordinary active clock together.

Historical-price tests load Prompt 8 saves with R08/R13 ledger entries of 800/1,000 Rolls after the new 900/1,300 prices take effect. Wallets, Lifetime Rolls, unlocked gates and exactly-once derived x20 multipliers survive two save generations without retroactive charges or refunds. The final separate process-kill/reopen probe also passes all **11 checks** with the updated purchase fixture.

Estimator tests verify reproducible seeded reports, agreement with live ordinary/variant samplers and derived Roll/Coin effects, unchanged live save fields/RNG, null results for unreached milestones, and the uninterrupted mandatory Breakthrough clocks. The final 12-seed continuous-Auto-Roll estimate reaches Breakthroughs at approximately 56.30, 115.97 and 172.80 active minutes, then the final boss at a median **210.57 minutes** (207.40–213.87 range). The model assumes 70% combat/boss utilisation, two seconds of target travel, frequent strongest-team selection and periodic sales; it does not simulate dodging, deaths or full world movement. The 90% rolling sensitivity reaches a 226.97-minute median, while buying every pre-completion optional Roll branch reaches 243.64 minutes. These are estimates, not human playthrough results.

The requested same-team >=3x Coins/minute increase between adjacent zones remains unmet. The final modeled ratios for entering Z2–Z8 are 1.73/1.66/1.50/1.35/2.51/1.97/2.43. Every newer zone is more profitable with the same team, but this does not satisfy the literal target. Ten-minute post-Breakthrough strongest-copy improvements are also probabilistic, so a lucky pre-owned copy can make the immediate improvement smaller. Full targets, every tuned constant and the distinction between simulated and physical checks are recorded in [Slimerot-Prompt-9.md](Slimerot-Prompt-9.md).

For a real debug-build playtest, run from the project directory:

```sh
godot --path . -- --slimerot-playtest
```

F8 / **Hide log** toggles details; F9 / **Export log** writes JSON and text to `user://Slimerot-playtests`. Add `--slimerot-playtest-output=<absolute directory>` after `--` to select an external output directory. The observer records timestamps and a source fingerprint while leaving normal saves enabled for the playthrough. Use a disposable game save when testing reset or migration.

To repeat the independent model without loading or writing a player save:

```sh
godot --headless --path . --script res://tools/SlimerotPacingEstimator.gd -- --slimerot-estimate --slimerot-estimate-seeds=12 --slimerot-estimate-output=<absolute filename stem>
```

The estimator requires its explicit flag and a debug build. Keep generated reports and screenshots outside version control. `tests/*`, `docs/*`, `dev/*` and `tools/*` are excluded from Android exports.

30. Record a complete fresh-save campaign with the developer logger. Measure active-time Z2 entry, B1/B2/B3 purchases, Z5/Z7 entry, final-boss defeat and completion; export at each major checkpoint and at the end. Pause/background time must not advance the active clock.
31. After each x20 purchase, keep rolling and compare the strongest owned/equipped copy, Team DPS, farm time and zones cleared over the next 10–20 active minutes. Record periods spent waiting for a useful roll and distinguish them from gate-Coin farming.
32. Compare equal-duration farming samples in adjacent zones with exactly the same team, Coin upgrades and sale policy. Record kills, Coins earned and travel/death time separately; do not treat a changed loadout as evidence for the >=3x target.
33. Repeat with optional Roll purchases, delayed manual sales/equipment, and ordinary mobile interruptions. Confirm optional branches never become mandatory prerequisites, then measure the timing cost of choosing them.
34. On physical Android hardware, complete a long offline session with simultaneous movement/Auto Roll, menu use, boss dodging, pause/background and OS-kill recovery. APK export, battery/performance, touch/audio and a real 3–3.5-hour campaign remain outstanding acceptance work.

## Prompt 12 focused command

Run `godot --headless --path <project> -- --slimerot-test --slimerot-rng-only` for the 161-check RNG/save group. Omit `--headless` and add `--slimerot-capture` to inspect the combined reveal and Shrine captures in `.godot/`. The combined `--slimerot-test` run includes this group and the complete Prompt 11 regressions. Review both the result count and console for `SCRIPT ERROR`; an engine script abort can otherwise leave a misleading partial count.

Legacy pure threshold-duration helpers remain for authored aura metadata/compatibility tests. Runtime queue tests assert the new adaptive durations, team relevance, five-second gap, skip behavior and unchanged currency. Historical Prompt 9 pacing reports describe the old RNG. The developer estimator now models zone luck, independent variants, canonical damage and hidden pity, but those historical campaign timings are not evidence for Prompt 12 balance.

## Prompt 13 focused command and coverage

Run `godot --headless --path <project> -- --slimerot-test --slimerot-progression-only` for the **68-check** progression/save group. Omit `--headless` and add `--slimerot-capture` to render the early Auto, Super branch and Super Settings views. The complete `--slimerot-test` run includes this group. Always inspect console output for script errors as well as the result count.

Coverage includes all 15 requested requirements, real purchases of all new Coin nodes, exact normal-enemy versus boss rewards, old purchase ledgers and unknown IDs, all six central luck components, cap-before-Super behavior, tier changes without schedule resets, repeated commit rejection, saturation limits, and 220 Auto/offline rolls with matching outcomes, RNG, pity, currency and Super phase. Fault injection checks duplicates, persistent-ID collisions, missing prerequisites, cycles, invalid currency, oversized slot effects, non-×20 Breakthroughs and orphan warnings; the canonical 54-node graph has no errors or warnings.

The offline restart probe uses its existing write/read/second-read flags with tier III already owned and a pending trigger 17 rolls away. The write process is force-stopped only after durable readiness; the first read claims 100 offline rolls and the second read verifies no repeated claim. Each reader now passes **13 checks**. The separate ordinary restart probe remains **11 checks**. Generated probe saves, console logs, packs and screenshots are local and excluded from export/publication.

The pacing model now uses the central luck function, Fortune nodes and persistent Super phases. Previous campaign-time reports remain historical; Prompt 13 has not been measured in a new full human campaign or on Android hardware.
