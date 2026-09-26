# Slimerot local persistence — through Prompt 16

Slimerot writes one logical save under `user://Slimerot-save.json`. All runtime assets and progression are local. No account, network service or remote clock is required. Prompt 11 reconciles local wall-clock time for Auto Roll on launch/resume.

## Authority and schema

Schema 11 persists wallets and Coin statistics, Lifetime Rolls, historical Roll spending, active playtime, current/highest zone, kills, gates, boss/structure flags, permanent `dash_unlocked`, completion, purchased node IDs, inventory pair quantities and stable copy IDs, group/per-copy favorites, ordered equipment, discovery history, potion bottles and active seconds, audio/accessibility settings, Auto Roll, sale filters, Luck Cap, remaining roll cooldown and the next Super Roll Lifetime trigger.

`first_roll_completed` must agree with `lifetime_rolls > 0`; Lifetime Rolls remains the runtime authority. `equipped_slot_count` is a validated compatibility field derived from purchases. Luck, potion multipliers, maximum HP, speed, damage, slots and cooldown limits are rebuilt from canonical recipes/nodes, never reapplied to previous values. Potion type and remaining seconds are authoritative; the obsolete saved potion multiplier is ignored during migration. Boss Brew has its own active timer. Loading returns to the saved zone entrance at full derived HP and clears transient attacks, reveal playback and encounter state; it never reruns rewards or roll transactions.

The legacy formats from schemas 1–10 migrate in memory before validation. Prompt 7 used schema 6. Historical Roll spend and grandfathered prerequisites remain preserved. Unknown future schemas disable saving and preserve files. Invalid saves do not silently become a new save; Settings exposes the failure and the existing hold-to-reset remains available.

## Commit and recovery

`SlimerotSaveFormat` wraps a serialized JSON payload with the Slimerot format name, monotonically increasing generation and SHA-256 of the format/generation/exact payload string. This detects accidental modification and incomplete writes; it is not an anti-cheat system.

1. Validate the entire snapshot before opening a file.
2. Write and flush `.tmp`, close it, then read it back and verify checksum/schema/invariants.
3. Rotate only a validated main to `.bak`; a corrupt main never replaces a good backup.
4. Rename the verified temporary file to the main path and report success only after replacement succeeds.

Loading checks the main, `.tmp`, `.bak`, `.recover` and any committed `.reset` marker, choosing the highest valid generation. A complete newer temporary transaction takes precedence over an older main. Stale temporary files cannot rewind progression. Recovery stages a copy in `.recover` before replacing the main, preserving its source if replacement fails. Read/write/recovery failures remain visible through the existing Settings save status.

The three-second, cancellable reset first commits a canonical fresh `.reset` marker. Only then does it clear old generations and install fresh main/backup files. A crash during reset cannot resurrect the old campaign, including when resetting a protected future-version file. An ordinary lower-version save cannot override a future save; that exception requires a verified newer reset marker from the explicit reset action.

Flush and rename follow [Godot FileAccess](https://docs.godotengine.org/en/4.5/classes/class_fileaccess.html) and [DirAccess](https://docs.godotengine.org/en/4.5/classes/class_diraccess.html). Godot does not expose portable filesystem directory-fsync guarantees. Recovery protects the application-level write boundaries, but hardware/storage failure can still destroy all copies.

## Lifecycle and timing

Autosave runs every ten active seconds. Existing synchronous critical signals commit skill purchases, structure/gate purchases, boss defeat, Variant Shrine sacrifice, power-improving/variant rolls, threshold ≥10,000 rolls, first roll, Super Roll/auto-sale, equipment/favorites/sales, settings, zone travel, potion use/crafting and completion. No result/reveal skip path grants currency twice.

App pause/focus-out suspends active time before saving and releases movement input. Independent application-pause and focus-loss latches prevent one resume notification from clearing the other suspension. Settings keeps its explicit pause after app resume; other menus retain Prompt 7's live-world behavior. Pause/closed time never consumes active-play potion timers. Prompt 11 resumes Auto Roll using completed elapsed cooldown cycles and preserves the fractional remainder. Window close and tree exit save as well, but Android process termination is not assumed to deliver an exit callback.

An unannounced kill can lose ordinary progress since the last periodic save (up to ten active seconds). Consequential transactions are committed synchronously. No implementation can guarantee an event that has not finished writing when a process or storage device is terminated.

## Validation and manual checks

`SlimerotPersistenceTests.gd` exercises real 100-roll/skill transactions, repeated B1 loads, exact equipment/protection/discovery, potion timing, serialized legacy imports, malformed inputs, checksum damage, interrupted generations, reset markers, future-schema protection, write failure, active timers and all consequential campaign events. Existing Prompt 1–7 suites remain integrated, including real multi-touch/UI dispatch and rendered captures.

`SlimerotRestartProbe.tscn` verifies a committed progressed state in two separate processes. Launch with `--slimerot-restart-probe --slimerot-restart-write`, wait for `Slimerot RESTART READY`, terminate that specific process forcibly, then reopen the same scene with only `--slimerot-restart-probe`. The read process checks 11 conditions and exits nonzero on failure. Probe files use `.godot/Slimerot-restart.json`; ordinary tests use per-process `.godot/` paths. Neither touches player data. Test scenes/scripts are excluded from Android exports, and test bootstrap paths require a debug build.

For manual acceptance: resume an existing Prompt 7 save; change equipment/favorites/settings; buy B1; use both potion channels; background and force-stop; reopen and verify exact state with no extra x20 or consumed potion seconds. Auto Roll catch-up must grant each elapsed completed cycle once. Complete a Shrine sacrifice, boss and final portal and repeat the restart. Cancel Reset before three seconds, then confirm it on a disposable save and verify the guaranteed first roll. Device airplane-mode and touch/pause steps are in [Slimerot Android readiness](Slimerot-Android.md).

## Prompt 11 offline transaction

Schema 9 adds last_background_timestamp and offline_roll_remainder, defaulting to zero for older saves. Inventory supports compact inclusive identity ranges alongside legacy copy arrays. Background catch-up freezes input, samples in short data-only slices, and commits rewards plus the consumed timestamp as one existing checksummed save transaction. Failed writes retry the same sampled state. Unsupported clocks/counts leave the prior save protected. The [Prompt 11 report](Slimerot-Prompt-11.md) documents behavior, stress tests and force-stop procedure.

## Prompt 12 variant and pity migration

Schema 10 adds `variant_flags` (0–7) to each compact stack, `best_ever_effective_rarity`, `rolls_since_last_power_improvement` and `shrine_sacrifices` (Shiny/Glitched/Golden arrays of unique base IDs). Canonical stack tokens (`normal`, `shiny`, `glitched`, `shiny+glitched`, `golden`, `shiny+golden`, `glitched+golden`, `shiny+glitched+golden`) are a one-to-one encoding of the mask, preserving existing single-variant keys. Validation requires key, token and mask to agree.

Schema 9 migration preserves compact identities, quantities, favorites, ordered equipment and offline timestamps/remainders; older migrations run before this conversion. Historical discovery and ownership establish the initial best-ever floor, including sold-out discoveries. Unknown historical misses cannot be reconstructed, so the initial counter is zero. Future, malformed or conflicting saves remain protected; original bytes are retained until a validated schema 10 commit, then retained as backup. Unique Shrine sets and best-ever/counter bounds are validated before any write.

Every offline result calls the same `resolve_roll` / `commit_roll` backend as live rolls. During yielded slices, those commits accumulate in isolated counters/discoveries/compact stack counts. Only a complete batch materializes inventory and counters; the existing Prompt 11 consumed timestamp and checksum transaction then commits them durably. The same one-counter-update site handles all roll modes. Failed durable writes retry the same completed batch; no per-roll reveals are enqueued. Seeded online/offline parity tests compare outcomes, currencies, both RNG streams and pity history.

## Prompt 13 progression migration

Schema 11 adds `super_roll_next_trigger` without changing the Prompt 12 variant/pity/Shrine model. An old RO5 owner receives the next strictly future multiple of 100 Lifetime Rolls during migration. A save without Super Roll has zero. Current saves preserve their exact future trigger; validation requires an integer greater than Lifetime Rolls and no more than the current tier interval away. Zero is valid for an enabled tier only when no complete interval fits within the exact-integer save limit.

Buying RO5 schedules the initial trigger before the purchase save. Upgrading to RO8/RO9 keeps an earlier pending trigger, otherwise shortens the wait to 75/50 rolls. That pending trigger receives the new ×10/×20 multiplier. After a Super result, the one roll-commit site advances the target by the tier interval together with the ordinary +1/+1 currencies. Offline staging carries this same field into the existing atomic catch-up transaction. Reloading does not calculate a new phase from a modulo check.

Historical R01+R02 ownership remains valid without R03: Luck I stays active and Auto Roll can be bought later for 40 Rolls. Owning both preserves both. The historical ledger permits old R02 spend up to 40 and R03 spend up to 75, including earlier migration prices; new R02 purchases cost 75 and require R03. No refunds, free Auto Roll or retroactive charges occur.

Unknown nonempty purchased IDs are retained and ignored by derived effects. Any valid recorded Roll spend for an unknown ID still counts toward `Lifetime Rolls = Rolls + recorded spend`. Duplicate IDs, malformed entries and invalid ledgers fail safely; unknown IDs alone do not crash or block a compatible load. All known slot effects still derive a maximum of five.

`SlimerotProgressionSaveTests.gd` covers both old purchase orders, later Auto purchase, repeated Breakthrough loads, unknown retired IDs, arbitrary tier-II phases, invalid triggers, integer limits and complete Prompt 12 state preservation. The actual offline restart probe now persists a tier-III trigger 17 rolls away, verifies 100 offline completions and the resulting trigger, then checks a second independent reopen for no replay: **13 checks per reader**. The ordinary save restart reader remains **11 checks**. See [the Prompt 13 report](Slimerot-Prompt-13.md) for the node table and final results.

## Prompts 14–16 compatibility

The UI reorganization does not change saved progression. Prompt 15 adds `dash_unlocked` within schema 11: a missing flag derives true for legacy saves that already reached Z2, and false for earlier saves; an explicit boolean is preserved. Invalid non-booleans fail validation. Unlocking at the Z2 boss gate emits an immediate durable checkpoint. Dash movement/cooldown, projectile pools, combat feedback and reveal playback are transient.

Combined gates derive their role from the existing first-kill boss flags; no replacement gate-save format or second boss reward is introduced. The one-time zone-unlock presentation follows an increase of the saved highest zone and never writes accumulated luck. New Coin/Super nodes remain unpurchased in an old save unless their actual persistent IDs were already present. Existing IDs, exact equipment/copy identities, favorites and historical spends survive migration.

Migration chain: schemas 1–8 legacy structure/skill/persistence migration → schema 9 offline timestamp/remainder defaults plus compact identities → schema 10 independent variant masks, historical-best pity and empty Shrine sets → schema 11 persisted Super trigger → additive Dash default within schema 11. Each stage validates before replacing an original generation. See the [Prompt 16 requirement matrix](Slimerot-Prompt-16-Matrix.md) for end-to-end acceptance and [Android](Slimerot-Android.md) for the eight device force-close cases. Current automated totals are in [Testing](Slimerot-Testing.md); historical probe counts above describe those stages only.
