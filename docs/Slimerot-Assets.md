# Slimerot art and audio replacement

Prompt 7 includes original code-authored placeholders: 24 transparent 256×256 slime SVGs; one player; 24 enemies (three archetypes in eight themes); four 512×512 bosses; eight ground tiles; five structures and four gate/portal variants; and ten UI icons. Eight mono PCM WAVs provide roll, rare, jackpot, hit, enemy death, purchase, gate and Breakthrough cues. The [Slimerot soundtrack](Slimerot-Soundtrack.md) replaces the two short music placeholders with eleven original stereo Ogg compositions: nine world themes and two battle themes.

Run `python tools/SlimerotGeneratePlaceholders.py` to regenerate the supplied placeholder artwork and eight effects. That generator uses only the Python standard library and never overwrites world music. The separate soundtrack renderer and scored arrangements are documented in the soundtrack guide. No third-party recordings, samples or game melodies are included.

## Replacement paths

Keep the existing `Slimerot_<id>` filename stem under `assets/art/<group>/`. `SlimerotAssets` resolves PNG, then WebP, then SVG, so adding a PNG or WebP overrides the supplied vector placeholder. Slime IDs come from `SlimerotRoster.gd`; enemies use `z1_chaser` through `z8_tank`; bosses use the IDs in `SlimerotEncounters.gd`. Import replacements in Godot and restart the scene. Caches intentionally include missing resources; `SlimerotAssets.clear_cache()` is available to editor/debug tooling after replacement.

Slime artwork should use a transparent 256×256 canvas, with the body centered around (128,143), preserving padding for auras and props. Bosses use a 512×512 canvas. Ground tiles repeat across existing zone geometry. Texture changes never alter collision, damage, rarity, movement, navigation, or save data.

For effects, use `assets/audio/Slimerot_<cue>.ogg`, `.mp3`, or `.wav` (in that priority order). Music uses `assets/audio/music/Slimerot_<track>.ogg`, with exact IDs in `scripts/data/SlimerotMusicLibrary.gd`. Enable Loop in each Ogg import, retain the filename and reimport. Keep replacement track starts/ends seamless. Effects need no loop markers.

## Runtime behavior

`SlimerotAssets` caches textures, paths, and streams. Missing optional textures return null and world/portrait renderers draw their existing procedural fallback; missing effects become silent cues. Missing music falls back to the Bedroom theme, then silence if that is also absent. The audio autoload uses eight reusable effect players and two music players for 0.9-second crossfades. Only the current theme plays once a transition settles. Hit/death cues are rate limited. Master volume multiplies the independent music and effect controls, including both sides of a fade; dragging previews the gain immediately and releasing saves the setting.

Idle bobs, fixed-world-rotation directional player visuals, 0.12-second attack squash, existing projectiles, Shiny sparkles, Glitched offsets, Golden glow, boss hit flash and reveal particles are code-driven. Undiscovered Collection cards use flat silhouettes. Offscreen/clipped portraits stop animating. Reveal particles are bounded, and queued repeated results coalesce during longer reveals.

These remain replaceable placeholder assets. Physical midrange Android performance, speaker mix and device cutout behavior still require device testing.
