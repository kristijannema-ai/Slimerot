# Slimerot Prompt 12 — RNG and presentation

> **Historical record — Prompt 16:** Historical Prompt 12 report. Schema 10 is the migration stage introduced here; current saves are schema 11 plus additive Dash. Prompt 13 extends the tree through clean luck/Super hooks, Prompt 14 consolidates navigation, and Prompt 15 makes rare reveals compact during boss combat. The RNG/variant/damage/Shrine invariants below remain authoritative; later final results and any provisional tuning are in Prompt 16.

Implemented on `slimerot/stage-12-rng`, based on merged Prompt 11 `97093cd` (PR #13). Origin was verified as `https://github.com/kristijannema-ai/Slimerot.git` and main was fetched before branching. Prompt 13 and campaign price/HP retuning are outside this change.

## Gameplay and architecture

- `resolve_roll()` returns one pending `SlimerotRollResult`; `commit_roll()` accepts that issued object once, checking lifetime sequence and reset generation. Manual, Auto and offline rolls share the sole +1 Rolls / +1 Lifetime operation. Playback starts after commit and never awards progression.
- All 24 bases are available at Z1. Origin metadata remains for collection/world content. Effective luck derives tree/Breakthrough/Coin × unlocked gameplay zones × potion × one-roll Super. Hub is excluded and load cannot compound zone luck. Existing cap-before-Super behavior remains.
- Shiny/Glitched/Golden are flags 1/2/4, sampled independently. All eight masks are valid. Central helpers compute effective rarity and rounded raw damage; inventory ranking, Equip Best, team/combat and UI use them. Boss/team modifiers apply after raw rounding.
- Hidden pity sums the current base winner distribution and independent mask masses. The base sampler uses `(randi+1)/2^32`; the variant sampler uses `randi/2^32`, including their discrete boundary probabilities. Stronger replacements are sampled from valid outcomes conditioned on effective rarity exceeding the historical best. The hard deadline is recalculated for current luck, Super, Shrine odds and target. At maximum possible power, pity disables itself.
- The Variant Shrine reuses `mutation_lab` and its existing repair cost/location. One unprotected physical copy increases one chosen active category. Duplicate base/category offerings consume nothing. The former five-Normals recipe is disabled. Sacrifice, sale and unequip never erase best-ever history.
- The reveal queue runs independently of roll cooldown/Auto Roll. Adaptive tiers consider surprise, weakest equipped damage, available slots, discoveries, flags and historical improvement. Major effects dim the HUD, darken the screen and add optional camera shake. Combined variants retain all three visual layers. Pending feedback is bounded/coalesced; dropping visual feedback cannot lose or duplicate committed rewards.
- Offline rolls use the same resolution/commit path, staged in compact counters and stacks until the entire batch succeeds. Prompt 11 checksum/backups, timestamp/remainder transaction, write retries, frozen active timers and AFK summary remain. The summary reports combined effective rarity, mask, base damage and new base/variant discoveries, with no per-roll cinematics.

## Schema 10

New stack field: `variant_flags` (0–7), checked against its canonical string/key. Added state: `best_ever_effective_rarity`, `rolls_since_last_power_improvement`, and three unique-base arrays in `shrine_sacrifices`.

Schemas 1–9 migrate in memory before validation. Old Normal/Shiny/Glitched/Golden become 0/1/2/4. Quantities, compact identity ranges, equipment, group/individual favorites, wallets and Prompt 11 offline timing survive unchanged. Legacy discoveries/ownership establish the best-ever target; unrecoverable historical miss count starts at zero. Original bytes are preserved on failed migration and as the backup after the first successful schema 10 commit. Repeated loading derives zone luck once.

## Provisional constants

| Setting | Value |
| --- | --- |
| Base independent flag chances | Shiny 1/100; Glitched 1/400; Golden 1/1,600 |
| Existing Variant Sense | ×1.25 on each flag probability |
| Shrine category multiplier | `1.05^unique_count`, each probability capped at 1 |
| Canonical rarity multipliers | 100 / 400 / 1,600, multiplied for combinations |
| Raw damage | `round(6 * effective_rarity^0.32)` |
| Pity start / force / maximum soft chance | 1× / 3× expected / 25%; smoothstep ramp |
| Surprise thresholds | 25 medium; 100 rare; 1,000 jackpot |
| Slightly worse team relevance | ≥85% of weakest equipped damage |
| Tier durations | 0.50 / 1.40 / 3 / 4 / 5 seconds |
| Skip Common toast | 0.20 seconds |
| Major breathing gap | At least 5 seconds after finish or skip |
| Variant tier floors | Shiny 1; Glitched 2; Golden 3; all three 4 |
| Camera shake | Up to 5 px, decays over 0.75 seconds; respects setting |
| Pending presentation limit | 32; repeat coalescing, minor feedback discarded first |
| Sale values | Existing Shiny/Glitched/Golden ×2/×5/×10, multiplied for combinations |

## Validation

- Untouched Prompt 11 baseline: 1,505 headless checks, zero failures.
- Final combined Godot 4.5.1 headless suite: **1,662 checks, zero failures**. Existing tests were updated only where Prompt 12 intentionally changes pools, odds, zone luck, damage, Shrine behavior or reveal timings.
- New RNG/save suites rendered with OpenGL compatibility: **161 checks, zero failures**. Combined-variant jackpot and Shrine screenshots were visually inspected. Live physics verifies movement and at least two Auto completions while a five-second major reveal stays active.
- Parser/import validation: no Slimerot errors. Final logs have no `SCRIPT ERROR` or leaked-object reports. This Windows environment emits an existing root certificate-store error unrelated to offline gameplay; deliberate malformed-save probes emit expected preservation warnings.
- Actual writer process force-kill/reopen: **11 save checks**; offline first reopen **11 checks** and second independent reopen **11 checks**. No duplicate AFK claim, potion-time loss or equipment/favorite loss.
- Android preset resource pack: **152 isolated export checks**, zero failures, without source fallback; the packed main scene also ran 120 frames without Slimerot errors. New runtime classes are included; developer tools/tests/docs remain excluded.
- Stress coverage retains compact identities, fragmented favorites, Equip Best, 20,000-roll sliced offline catch-up and save/transaction failure tests. The expanded inventory fixture covers 192 base/mask stacks and 19,200,576 copies without per-copy expansion.
- `git diff --check` passes. Generated screenshots, logs, save profiles, packs and helper scripts are outside the published source changes.

The twenty requested checks are covered by `SlimerotRngTests.gd`, with real JSON/checksum/migration protection in `SlimerotRngSaveTests.gd`; Prompt 11 stability suites remain part of the combined run. Physical Android touch/force-stop, device frame pacing and a human full-campaign playthrough remain manual acceptance work. Historical Prompt 9 pacing results do not establish Prompt 12 balance; the estimator now uses the new RNG/damage rules without changing campaign tables.

## Changed files

Runtime additions: `SlimerotVariants.gd`, `SlimerotPity.gd`, `SlimerotRollResult.gd`, `SlimerotRollRevealQueue.gd` and their UID files. Runtime edits: Balance/Presentation data; GameState, SlimeDatabase, InventoryManager, RollManager and SaveManager; Audio; HUD, Menus, Portrait and Reveal; World interaction labels.

Tests: two new RNG/save suites and runner integration; Rolling, SkillTree, Combat, Campaign, Encounter, Persistence, RestartProbe, UX, Balance, FinalIntegration, Endurance and InventoryStress expectations adapted to the requested mechanics. Developer estimator: `tools/SlimerotPacingModel.gd`. Documentation: this report, README, Saves and Testing.
