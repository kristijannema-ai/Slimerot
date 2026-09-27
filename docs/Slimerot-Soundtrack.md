# Slimerot world soundtrack

The soundtrack replaces the short exploration/boss placeholders with eleven original melodic chiptune compositions. Warm keys, chip leads, soft flute/reed voices, bells, bass and synthesized percussion give each location its own character. The aesthetic draws on expressive retro RPG music; no Undertale melody, recording or sample is reused.

Each arrangement has 32 bars: an eight-bar theme, a developed repeat, a contrasting bridge, and a fuller return. Circular reverb/delay preserves loop tails. All tracks are stereo 32 kHz Ogg Vorbis, bundled locally; no downloads, audio-generation service or Python runtime is used by the game.

| Location / encounter | Track | Character | Loop |
|---|---|---|---|
| Bedroom Hub | A Little Light Left On | Cozy electric keys | 80.0s |
| Backyard | Pocketful of Sunshine | Playful chip melody and bouncing bass | 65.1s |
| Italian Village | Cups Along the Canal | Reed-led canal waltz in 3/4 | 51.4s |
| Cursed Forest | Where the Lanterns Wait | Melancholic flute and soft arpeggios | 89.3s |
| Sahara | A Map Drawn in Sand | Plucked bells and hand-drum rhythm | 71.1s |
| Brainrot City | Neon Crosswalk Shuffle | Syncopated chip funk | 60.0s |
| Backrooms | The Hallway Remembers | Sparse, uneasy keys | 87.3s |
| Moon | Postcards from the Quiet Sky | Floating bells and warm harmony | 85.3s |
| Brainrot Dimension | Every Door Was a Beginning | Grand, wistful chip theme | 68.6s |
| Z2/Z4/Z6 bosses | Small Team, Big Trouble | Fast driving battle melody | 51.2s |
| Singularity Admin | One More Impossible Tomorrow | Urgent theme and heroic bridge | 49.2s |

## Integration

`SlimerotMusicLibrary.gd` maps the Hub and zones 1–8 to exact track IDs and selects the two boss themes. The existing `SlimerotSound` autoload follows real world/boss state; walking through a gate, Fast Travel, boss retreat and victory all update the theme. Boss defeat returns to the current world's music, including final free-roam.

Two fixed `AudioStreamPlayer` instances crossfade over 0.9 seconds. Repeated requests and same-zone respawns preserve playback position. Returning during a fade reverses the two existing channels; rapid third-track changes reuse the quieter channel. The eight effect voices remain separate. Gain stays bounded, both players obey Settings, and Android suspension freezes both playback and fade progress. Missing music falls back safely. No save fields, progression values, currencies, combat logic or balance have changed.

## Editing and regeneration

The authored score is `tools/SlimerotMusicScore.json`. Each entry contains eight bars of melody/chords/bass roots and a separate eight-bar bridge. Note durations are beats, `-` is a rest, and pitches use scientific notation. The renderer validates every bar before synthesis.

```sh
python -m pip install -r tools/SlimerotMusicRequirements.txt
python tools/SlimerotComposeSoundtrack.py --report /tmp/Slimerot-soundtrack-metrics.json --preview /tmp/Slimerot-soundtrack-preview.wav
godot --headless --editor --path . --import --quit
```

Python 3.12 and the pinned NumPy/SciPy/SoundFile packages are development-only. Ogg encoding uses bounded blocks to avoid large-buffer failures in the Windows Vorbis encoder. Use `--track backyard` to render a single track. Existing `.ogg.import` files must retain `loop=true`. Export excludes the composition tools and tests and includes all eleven imported streams.

## Validation and listening checklist

```sh
godot --headless --path . -- --slimerot-test --slimerot-music-only
godot --path . -- --slimerot-test --slimerot-music-only
godot --headless --path . -- --slimerot-test
```

Tests use isolated profiles. The music suite covers all nine real world transitions, four boss encounters, final victory, Fast Travel, same-track continuity, interrupted fades, both-channel mute/background behavior, missing assets and 1,000 rapid switches with bounded node/cache counts. The export audit loads every music stream from an isolated resource pack.

Validated on Godot 4.5.1, Windows:

- Editor import/parser validation completed without script errors.
- Full headless regression suite: **2,240 checks, zero failures**.
- Focused soundtrack: **84 headless / 87 rendered checks, zero failures**. The rendered lifecycle test starts all ten audio players, allows the existing mixer buffer to drain, then verifies paused playback positions remain stationary.
- Isolated Android-preset resource-pack audit: **235 checks, zero failures**, including all eleven Ogg loops and eight effects. The rendered packed main scene completed 120 frames without source-resource fallback.
- All eleven scores passed pitch/meter validation; decoded audio is finite stereo 32 kHz, 49.2–89.3 seconds, with RMS levels between −19.68 and −19.63 dBFS and peaks below −5.7 dBFS. Measured first/last-sample discontinuities are below 0.006. Compressed soundtrack size is approximately 6.57 MiB.

The existing host certificate-store warning and missing Android SDK build-tools are external setup limitations. No APK/device result or subjective listening approval is claimed.

For listening QA, walk from Bedroom to Backyard, travel through all unlocked worlds, start/retreat from a boss and defeat the final boss. Listen through each loop boundary, adjust master/music/SFX during a fade, then background and resume. Confirm the lead remains audible above combat sounds on phone speakers and headphones. Physical Android listening, audio-focus behavior and subjective mix approval still require a device/player check; automated waveform and playback checks do not establish musical preference.
