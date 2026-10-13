# Boss Lab UI and local history

The interface builds its controls once. Session `updated` signals refresh values at 10 Hz; they never rebuild selection cards, joystick controls, or statistics screens. Fight controls occupy the HUD above y=220 and below y=980 in the 720×1280 portrait canvas.

## Controls

- Selection: four encounters, Normal/Practice, Low/Expected/High team DPS, statistics, Start.
- Fight: left touch joystick, large Dash button, Tools, Menu. Desktop movement, Dash, R, F1 and Escape are handled by `BLSession`.
- Result: immediate Retry, killing attack, elapsed survival, boss HP percentage, phase, hits, Dash count, statistics and boss selection.
- Tools: metrics remain visible in both modes. Practice enables God Mode, phase selection, attack forcing, 0.5× speed, hitboxes, telegraphs and team DPS. Normal disables these changes during attempts. Restart always works.
- Statistics: select the encounter and Normal/Practice history independently.

Tools and statistics pause the session through `session.ui_paused`. Their full-screen scrims consume input. Closing them resets the joystick before play resumes. Hidden screens do not intercept arena or touch-control input.

Dash handles screen touches directly, so the second finger can Dash while the first finger holds the joystick. It activates on press and cannot trigger an extra Dash on a late finger release.

## HUD integration API

`BLHUD.setup(session)` runs once after profiles and the selected profile exist. The session supplies the contract signals and `snapshot()` keys: `boss_hp`, `boss_max_hp`, `player_hp`, `player_max_hp`, `phase`, `attack`, `dash_cooldown`, `dps`, and `seed`. Elapsed time, attempt, hits, damage taken and Dash count come from the session's public counters.

- `refresh()` marks values dirty.
- `attempt_started()` clears result and modal overlays. Call this for keyboard retries as well as UI retries.
- `show_menu()` clears result and modal overlays when the session returns to selection.
- `toggle_debug()` opens/closes Tools.
- `close_top_modal() -> bool` closes one Tools/Statistics screen before Escape returns to selection.
- `is_modal_open() -> bool` reports either Tools or Statistics.

## Metrics API and storage

`BLMetrics` never references the main game. Storage defaults to `user://boss-lab-attempts.json` in Boss Lab's custom user directory. `--boss-lab-test` disables persistence by default. Tests may set `storage_path` to an isolated workspace path and explicitly enable persistence.

`record_attempt(record)` accepts `boss_id`, `boss_name`, `mode`, `attempt`, `duration`, `phase`, `boss_hp_remaining` (**percentage 0–100**), `hits`, `dash_count`, `damage_by_attack`, `death_attack`, `victory`, and `seed`. Missing counters use safe defaults. Only the four lab boss IDs are accepted.

`next_attempt_number(boss_id, mode="normal")` returns the next number in the separate encounter/mode sequence.

Restarting or leaving a live attempt counts that attempt. These explicitly interrupted records do not become killing attacks in the common-death statistic. The detailed record also preserves team DPS/preset, damage taken and timestamp for later balance comparisons.

`summary(boss_id, mode="normal")` returns:

| Key | Meaning |
| --- | --- |
| `attempts`, `wins` | All-time completed results for this encounter/mode |
| `average_survival_seconds` | Mean duration, including victories |
| `most_common_death_attack` | Most common failure attribution; deterministic alphabetical tie break |
| `best_hp_before_first_clear` | Lowest boss HP percentage on a failed attempt before the first victory |
| `first_clear_attempt` | First victorious attempt number, or 0 |
| `hits`, `dash_count` | Cumulative counters |
| `damage_by_attack` | Cumulative damage taken, by source |

Format version 2 retains at most 500 detailed records plus eight small all-time aggregates, one per encounter/mode. Each aggregate caps attack attribution maps at 64 entries. The cap cannot erase first-clear results or reset attempt numbers. Practice totals never affect Normal totals.

Saving writes a pending file, retains the previous complete file, then renames the pending file. Loading checks the primary history and falls back to a valid previous/pending file after an interrupted write. Storage failures are shown in statistics, without preventing Retry. There is no networking or cloud storage.

## Automated UI coverage

`tests/BossLabUITests.gd` uses viewport ScreenTouch events and Godot's primary-finger mouse emulation for ordinary buttons, not direct button signal emission. It tests 21 Tools Close/Back cycles, paused fight time, stable UI node count, practice phase/attack/slow/hitbox controls, Normal cheat restrictions, two simultaneous movement/Dash fingers, immediate death attribution, touch Retry, keyboard R, and 720×1280 / 720×1560 / 800×1280 containment.

`tests/BossLabMetricsTests.gd` tests separate normal/practice histories, durations, attribution, pre-clear best HP, first clears, 500-record truncation, persistent all-time aggregates and sequences, missing fields, save/load, and recovery from an interrupted primary file. All writes use an isolated `.godot` test file; the normal device history is untouched.
