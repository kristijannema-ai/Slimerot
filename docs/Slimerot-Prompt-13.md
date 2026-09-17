# Slimerot Prompt 13 — skill tree and progression

Prompt 13 builds on merged Prompt 12 (`d316b038398a0dd9fb4f4928c8944e06fbdccf7a`). Auto Roll unlocks after 65 total Rolls, Super Roll has three tiers, and six Coin nodes add permanent luck, damage, normal-enemy Coins and movement speed. There are **54 nodes: 27 Roll and 27 Coin**. Existing node IDs and all previous Coin nodes remain intact.

## Exact node delta

Costs below are the price of that node, not cumulative spend. `+` between prerequisites means all are required. Zone requirements mean the zone has been unlocked; the existing repaired-Shrine access gate remains.

| ID | Name | Previous prerequisite / cost | Prompt 13 prerequisite | Cost | Effect |
| --- | --- | --- | --- | ---: | --- |
| R01 | Quick Hands I | Root / 25 Rolls | Root | 25 Rolls | Unchanged: cooldown 2.40 → 2.20 s |
| R03 | Auto Roll | R02 / 75 Rolls | R01 | 40 Rolls | Unlock Auto Roll |
| R02 | Luck I | R01 / 40 Rolls | R03 | 75 Rolls | Luck ×1.10 |
| R04 | Quick Hands II | R03 / 125 Rolls | R02 | 125 Rolls | Unchanged: cooldown 2.20 → 1.90 s |
| RO5 | Super Roll I | R13 / 650 Rolls; named Super Roll | R08 | 650 Rolls | Every 100 rolls, ×5 luck |
| RO8 | Super Roll II | New | RO5 + R13 | 900 Rolls | Every 75 rolls, ×10 luck |
| RO9 | Super Roll III | New | RO8 + R18 | 1,500 Rolls | Every 50 rolls, ×20 luck |
| C20 | Fortune I | New | Z3 | 8,000 Coins | Permanent luck ×1.15 |
| C21 | Fortune II | New | C20 + Z5 | 80,000 Coins | Additional luck ×1.20 |
| C22 | Fortune III | New | C21 + Z7 | 600,000 Coins | Additional luck ×1.25 |
| C23 | Slime Bond VI | New | C16 + Z7 | 450,000 Coins | Additional team damage +50 percentage points |
| C24 | Coin Scavenger IV | New | C18 + Z7 | 500,000 Coins | Additional normal-enemy Coin bonus +100 percentage points |
| C25 | Fleet Feet III | New | CO2 + Z7 | 250,000 Coins | Additional movement speed +15 percentage points |

The mainline now begins **R01 → R03 → R02 → R04**. R04's prerequisite follows the reordered mainline so Luck I remains mandatory. Optional branches never become mainline prerequisites. The UI orders parents before children and groups all three Super Roll tiers together.

## Luck authority and preserved RNG

`RollManager.get_effective_luck(context)` is the central effective-luck API; the existing `effective_luck()` and `rolling_luck()` entry points delegate to it. `get_luck_breakdown(context)` supplies its six components and totals:

```text
minor_roll_tree_product
× breakthrough_product
× zone_luck_multiplier
× coin_tree_luck_product
× active_potion_multiplier
× super_roll_multiplier
= total
```

The Breakthrough component is exactly **20 / 400 / 8,000** after B1 / B1+B2 / all three. The unlocked-zone component is derived once, from Z1 ×1 through Z8 ×8, excluding the Hub. No luck product is persisted or compounded on load. The existing selected cap applies to persistent/potion luck before the temporary Super multiplier; `capped_total` reports that result separately.

Run a debug build with `--slimerot-playtest`, then open Roll Settings to see every next-roll component, **TOTAL**, and the result after the cap. Developer log snapshots record the same breakdown and Super tier/countdown. The pacing model uses the central function with explicit simulated context.

Prompt 12's canonical roster, variant bitmask data, independent variant draws, combined rarity/damage, pity history and Shrine sets retain their data model. Progression enters through luck modifiers and the existing single resolve/commit path. Every manual, Auto or offline Super completion grants exactly **+1 Rolls and +1 Lifetime Rolls**; reveal playback grants nothing.

## Super Roll schedule

The existing RO5 ID becomes tier I. On its first purchase, the next trigger is the strictly future multiple of 100 Lifetime Rolls, preserving the old cadence. Buying at Lifetime 20,045 therefore schedules 20,100; buying exactly at 20,100 schedules 20,200.

Schema 11 persists `super_roll_next_trigger`. Each successful Super commit schedules the following trigger by adding the current interval. Upgrading keeps an earlier future trigger and caps the remaining wait at the new interval. The pending trigger uses the new tier's multiplier. Normal operation does not test Lifetime Rolls modulo the current interval.

Example: after the 20,100 tier-I result, purchasing tier II at 20,110 moves the next trigger from 20,200 to 20,185. Subsequent triggers are 20,260 and 20,335. Purchasing tier III at 20,320 keeps 20,335, then schedules 20,385 and 20,435. Spending currency, reloading, Auto Roll and offline catch-up preserve this phase. Duplicate commit attempts are rejected. At the exact-integer save limit, zero represents that no further trigger fits; it does not invent or replay one.

## Save compatibility

- Schema **11** adds only the persisted Super trigger to the Prompt 12 progression state. Schemas 1–10 migrate through the existing checksummed recovery pipeline; schema 10 keeps its variants, copies/favorites/equipment, pity, Shrine progress and offline timestamp/remainder unchanged.
- A historical R01+R02 save retains Luck I without being granted Auto Roll. R03 can subsequently be purchased for 40 Rolls. Saves owning both retain both; there are no automatic refunds or retroactive charges.
- The Roll spend ledger preserves historical R02 prices up to 40 and R03 prices up to 75, including older migrated prices. The missing-R03 exception requires R01 and historical R02 spend; a new 75-Roll R02 entry cannot bypass the prerequisite.
- Old RO5 ownership derives the next future 100th Lifetime Roll once during migration. New-format saves preserve arbitrary valid future phases for tiers II and III. Stale, out-of-range or inconsistent triggers fail validation.
- Unknown nonempty purchased IDs remain stored but have no runtime effects. Valid recorded Roll spend for a retired ID still contributes to the wallet/Lifetime invariant. Duplicate or malformed IDs/ledger entries are rejected safely. No unknown-ID lookup crashes loading.
- Derived slots remain capped at **five**. Existing checksum, backup, future-schema protection, reset, autosave and offline transaction behavior remain in place. Original save generations are protected until a validated migration commit succeeds.

## Provisional balance

These are the requested baseline numbers, validated arithmetically; a new human campaign timing pass has not been performed.

| Measure | Prompt 13 value |
| --- | --- |
| Total Roll spend to unlock Auto Roll | 65, previously 140 |
| Mandatory spending blocks / total | 1,965 / 3,150 / 4,500; total 9,615 Rolls, unchanged |
| Super branch total | 3,050 Rolls for all three tiers |
| Fortune cumulative luck | ×1.15 / ×1.38 / ×1.725 |
| Fortune total price | 688,000 Coins |
| All team Bonds including Final Bond and C23 | +200%, or ×3.00 team damage |
| All normal-enemy Scavenger bonuses | +200%, or ×3.00 Coins; bosses remain fixed |
| All Fleet Feet bonuses | +35%, or 243 px/s from base 180 |
| All permanent Roll/Coin luck before zones | ×49,097.8125 |
| Above at Z8, without a potion or Super | ×392,782.5 |
| Above with ×3 potion and Super III, uncapped | ×23,566,950 |
| Maximum equipped slots | 5 |

The earlier Auto Roll, B1-gated Super I and Z3 Fortune I support early/mid progression; later tiers and Coin bonuses supply the late increases. No XP, currencies, prestige or online systems are added. Earlier campaign estimates remain historical and do not establish Prompt 13 pacing.

## Validator and test results

`SkillTreeManager.validate_tree()` validates original definitions before dictionary indexing could hide duplicates. It checks unique node/persistent IDs, existing prerequisites, cycles, valid Rolls/Coins currency, costs/effect values, slot effects within five and exact ×20 Breakthroughs; disconnected nodes produce an orphan warning. The canonical **54-node** graph has **zero errors and zero warnings**. Fault-injection tests confirm each required diagnostic.

| Validation | Result |
| --- | --- |
| Full headless suite, including all previous regressions | **1,766 checks passed; 0 failures** |
| Focused rendered progression/save suite | **68 checks passed; 0 failures** |
| Actual force-stop and separate save reader | **11 checks passed** |
| Two separate offline readers with pending Super III | **13 + 13 checks passed**; no repeated claim |
| Exported pack audit in an empty scratch project | **154 checks passed**; source fallback disabled |
| Exported main scene | **120 frames completed**, no Slimerot script errors |

All 15 requested checks are covered: early Auto availability and exact prices/prerequisites; historical R01+R02 loading; exact B1/load/B3 luck; one zone factor; central Fortune; all Super tiers; one currency commit; five slots; and graph integrity. Additional checks exercise upgrade phase retention, save validation, unknown IDs, integer limits, actual Coin purchases/rewards and 220-roll Auto/offline outcome, RNG, pity, currency and schedule parity.

Rendered early Auto, Super branch and tier-III Settings captures were inspected. Final logs were checked for script errors as well as result counts. The host's pre-existing certificate-store diagnostic is environmental. No physical Android/APK or human campaign timing is claimed. Screenshots, packs, logs, save fixtures and generated machine reports remain local and are excluded from this change.

Focused command (add an absolute `--log-file` where needed):

```sh
godot --headless --path <project> -- --slimerot-test --slimerot-progression-only
```

Omit `--headless` and add `--slimerot-capture` for rendered captures. Omit `--slimerot-progression-only` for the combined suite. See [testing](Slimerot-Testing.md) and [save architecture](Slimerot-Saves.md) for pack and restart procedures.

## Changed files

| Area | Files |
| --- | --- |
| Definitions and pure helpers | `scripts/data/SlimerotBalance.gd`, `SlimerotRollTree.gd`, `SlimerotCoinTree.gd`; new `SlimerotSuperRoll.gd` and `SlimerotSkillTreeValidator.gd` with their `.gd.uid` files |
| Runtime and saves | `scripts/managers/SlimerotGameState.gd`, `SlimerotSkillTreeManager.gd`, `SlimerotRollManager.gd`, `SlimerotSaveManager.gd` |
| Presentation | `scripts/ui/SlimerotHUD.gd`, `SlimerotMenus.gd`, `SlimerotReveal.gd` |
| Developer tools | `dev/SlimerotPlaytestLogger.gd`, `tools/SlimerotPacingModel.gd` |
| New tests | `tests/SlimerotProgressionTests.gd`, `SlimerotProgressionSaveTests.gd` and their `.gd.uid` files |
| Updated regression fixtures | `tests/SlimerotTests.gd`, `SlimerotBalanceTests.gd`, `SlimerotCombatTests.gd`, `SlimerotFinalIntegrationTests.gd`, `SlimerotOfflineRestartProbe.gd`, `SlimerotOfflineTests.gd`, `SlimerotPersistenceTests.gd`, `SlimerotRestartProbe.gd`, `SlimerotRngSaveTests.gd`, `SlimerotRngTests.gd`, `SlimerotRollingTests.gd`, `SlimerotSkillTreeTests.gd` |
| Documentation | `Slimerot-README.md`, `docs/Slimerot-Saves.md`, `docs/Slimerot-Testing.md`, this report |
