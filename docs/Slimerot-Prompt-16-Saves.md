# Prompt 16 — save migration and process-death acceptance

The final save schema remains **11**. Prompt 16 fixes historical purchase-price validation and the ancient missing-ledger fallback so the cheaper current prices do not invalidate old saves. It introduces no new save fields or schema. The JSON payload is stored inside the existing checksummed, generation-numbered envelope. The timestamp and offline rewards are committed in the same generation.

## Migration chain

| Source schema | Production migration path | Defaults / preservation |
|---|---|---|
| 1 | Legacy statistics/discoveries/favorites → legacy Roll aliases → Coin-slot aliases → pre-AFK normalization → RNG fields → Super schedule → Dash default | Reconstructs historical discoveries and supported purchase metadata; preserves currencies and owned copies. |
| 2 | Legacy Roll aliases → Coin-slot aliases → pre-AFK normalization → RNG fields → Super schedule → Dash default | Retains historical Roll spend, including inert unknown purchased IDs. |
| 3 | Coin-slot aliases → pre-AFK normalization → RNG fields → Super schedule → Dash default | Grandfathers required slot ancestors without charging currency. |
| 4–5 | Legacy gate/potion/completion defaults as applicable → pre-AFK normalization → RNG fields → Super schedule → Dash default | Reconstructs contiguous gates from highest unlocked zone where absent; initializes systems that did not exist. |
| 6–8 | Pre-AFK normalization → RNG fields → Super schedule → Dash default | Background timestamp and fractional roll remainder initialize to zero; no invented offline elapsed time. |
| 9 (Prompt 11) | Multi-variant/RNG migration → Super schedule → Dash default | Keeps compact identities and existing AFK anchor. Normal/Shiny/Glitched/Golden become masks 0/1/2/4; initializes pity misses to zero and each Shrine sacrifice set empty. Historical best comes from owned/discovered rarity. |
| 10 (Prompt 12) | Super schedule → Dash default | Keeps combined variants, pity, Shrine sets and AFK timing. Owned Super I derives its next future 100-roll boundary once. |
| 11 (Prompt 13 onward) | Validate authoritative data; additive Dash default only when missing | Preserves the exact saved future Super trigger. Missing Dash defaults to unlocked if Z2 was already reached, otherwise locked. Explicit saved Dash booleans remain authoritative. |

Derived total luck, team damage, slot count effects and potion multipliers are recalculated from their authoritative inputs. `highest_luck` is a historical statistic; it is not fed back into the current luck formula. Breakthrough ownership therefore never multiplies a previously accumulated saved total on load.

The old R01 + R02 save remains legal without R03 when the historical R02 ledger identifies its old price. It receives neither a refund nor a free Auto Roll purchase. New nodes remain unpurchased. Unknown nonempty purchased IDs are preserved with any valid historical spend and have no runtime effects.

The immutable historical Roll-price table is separate from the provisional current prices. Validation accepts recorded spend up to the highest published price for each known Roll node, while still enforcing nonnegative exact integers and the identity `Lifetime Rolls = spendable Rolls + recorded Roll spend`. For example, old R08/R13/RO5 payments of 900/1300/650 remain valid after their prices fall to 225/325/165; they are neither repriced nor refunded. Canonical pre-ledger schema-2 purchases reconstruct the historical prices, including the old R02=40 and R03=75 ordering. Existing Coin wallets and recorded Coin spend also remain unchanged when Fortune costs fall.

Original legacy bytes stay unchanged during a successful read; migration is persisted only through a validated save. Invalid candidates cannot overwrite the previous checkpoint. Backup/recovery/reset/future-schema protection continues through the existing save implementation.

## Automated migration acceptance

`tests/SlimerotFinalSaveTests.gd` runs **164 checks** through actual JSON/envelope writes, production migration, production validation, load and another current-schema save/load. It tests every source schema 1–11 and the early Z1 Dash default. Each schema verifies Coins, spendable Rolls, Lifetime Rolls, historical skills/spend, unknown IDs, boss flags, contiguous gates/zones, physical copy identity, quantities, team order, favorites, single-variant flags, Shrine defaults, AFK defaults/preservation, unpurchased new skills, source-byte preservation and noncompounding luck.

**PASS — 164 checks, 0 failures** in the integrated final acceptance run. This includes full historical-price fixtures for schemas 9–11, a schema-2 profile without a spend ledger, repeated resaves without repricing, rejection of spend above every published node price, and rejection of negative unknown-node spend. Existing RNG and progression save suites separately retain coverage of all eight variant masks, compact favorite ranges, sold-best pity history, Shrine persistence, malformed migration preservation, upgraded Super schedules and the exact-integer boundary.

## Force-close matrix

These are **real Windows process-termination/reopen tests**, using Godot 4.5.1. They are desktop analogs of the requested Android cases. The writer prints READY only after the tested transaction has returned and a newer durable generation exists. The external runner then uses Python `Popen.kill()` (`TerminateProcess` on Windows), so no graceful quit or `_exit_tree` save can rescue the result. Cases 3–8 do **not** call an extra save after the action; they test each action's immediate production save hook.

All profiles are isolated under `res://.godot/Slimerot-final-restart-*.json`. The runner requires `--slimerot-test`, and does not read or write player saves. The AFK clock is injected as method input to the private profile; the system clock is unchanged. In the rare-roll case the issued RNG result is given a deterministic triple-variant outcome before passing through the normal one-result commit guard.

| Case | Desktop test and observed result | Checks | Desktop | Manual Android |
|---|---|---:|---|---|
| 1 | Auto Roll ON → background → same-process resume grants 100 rolls/copies once. Duplicate resume and a later killed/reopened process grant zero additional rewards. | 32 | PASS | NOT RUN |
| 2 | Background checkpoint → external kill → first reopen grants 100 rolls/copies. Kill that claim process too → second reopen grants zero, proving the consumed timestamp survived process death. | 59 | PASS | NOT RUN |
| 3 | Issued all-three-variant rare roll → immediate external kill → exact copy, mask, discovery, best rarity and +1/+1 currency persist. The issued result rejects a second commit. | 29 | PASS | NOT RUN |
| 4 | Triple-variant copy sacrificed to Shiny → kill → removed copy stays absent; unique sacrifice and ×1.05 multiplier persist; replay is rejected. | 29 | PASS | NOT RUN |
| 5 | R01 purchase → kill → ownership and exact historical spend persist; a second purchase is rejected. | 28 | PASS | NOT RUN |
| 6 | Breakthrough I purchase → kill → effective luck is identical; component remains exactly ×20; duplicate purchase is rejected. | 28 | PASS | NOT RUN |
| 7 | Z6 boss reward → kill → boss flag/Coins persist; CombinedBossGate reports the exit role; a second boss reward is rejected. | 28 | PASS | NOT RUN |
| 8 | Free Dash unlock → kill → `dash_unlocked` remains true; repeated unlock is rejected. | 28 | PASS | NOT RUN |
| **Total** | **Eight cases, 17 separate Godot processes, nine externally killed writers/claimers.** | **261** | **PASS** | **NOT RUN** |

Every reopened case also compares all currencies, inventory, copy serial, team, favorites, skills, Shrine sets, boss flags, current/highest zone, gates, effective luck, best-ever rarity, pity misses, next Super trigger, AFK timestamp/remainder and settings with the pre-kill snapshot. AFK cases verify active-play and potion timers did not run while backgrounded.

Reproduce from the repository root:

```text
python tools/SlimerotFinalRestartMatrix.py --godot /absolute/path/to/Godot_v4.5.1-stable_win64_console.exe
```

By default logs and `results.json` go to `.godot/Slimerot-final-restart-results/`; use `--output` for another local test-artifact directory. The final development run on 2026-09-25 used `work/Slimerot-p16-restart-final-results/` outside the repository. Logs, expected-state sidecars and test profiles are generated QA artifacts and are not published as game assets.

## Android acceptance status

**NOT RUN — no physical Android result is claimed.** `adb` was unavailable on PATH and at the configured/common Android SDK platform-tools locations in this workspace environment. No Android device lifecycle, Settings → Force stop, OS storage behavior, airplane-mode boot, or device resume was exercised. The shared save/offline backend and real desktop process-death durability passed, but the eight Android lifecycle cases remain an explicit device acceptance requirement.
