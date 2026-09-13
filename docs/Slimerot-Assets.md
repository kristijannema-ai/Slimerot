# Slimerot art and audio replacement

Prompt 7 includes original code-authored placeholders: 24 transparent 256×256 slime SVGs; one player; 24 enemies (three archetypes in eight themes); four 512×512 bosses; eight ground tiles; five structures and four gate/portal variants; and ten UI icons. Ten mono PCM WAVs provide exploration and boss loops plus roll, rare, jackpot, hit, enemy death, purchase, gate and Breakthrough cues.

Run `python tools/SlimerotGeneratePlaceholders.py` to regenerate the supplied assets. The generator uses only the Python standard library. All shapes and melodies are original; no third-party downloads or licenses are required for these placeholders.

## Replacement paths

Keep the existing `Slimerot_<id>` filename stem under `assets/art/<group>/`. `SlimerotAssets` resolves PNG, then WebP, then SVG, so adding a PNG or WebP overrides the supplied vector placeholder. Slime IDs come from `SlimerotRoster.gd`; enemies use `z1_chaser` through `z8_tank`; bosses use the IDs in `SlimerotEncounters.gd`. Import replacements in Godot and restart the scene. Caches intentionally include missing resources; `SlimerotAssets.clear_cache()` is available to editor/debug tooling after replacement.

Slime artwork should use a transparent 256×256 canvas, with the body centered around (128,143), preserving padding for auras and props. Bosses use a 512×512 canvas. Ground tiles repeat across existing zone geometry. Texture changes never alter collision, damage, rarity, movement, navigation, or save data.

Use `assets/audio/Slimerot_<cue>.ogg`, `.mp3`, or `.wav` (in that priority order). Exploration and boss tracks are configured to loop at runtime. WAV loop bounds derive from stream length and sample rate. Keep replacement track starts/ends seamless. Effects need no loop markers.

## Runtime behavior

`SlimerotAssets` caches textures, paths, and streams. Missing optional textures return null and world/portrait renderers draw their existing procedural fallback; missing sounds become silent cues. The audio autoload uses eight reusable effect players and one music player. Hit/death cues are rate limited. Master volume multiplies the independent music and effect controls; dragging previews the gain immediately and releasing saves the setting.

Idle bobs, four-direction player rotation/tilt, 0.12-second attack squash, existing projectiles, Shiny sparkles, Glitched offsets, Golden glow, boss hit flash and reveal particles are code-driven. Undiscovered Collection cards use flat silhouettes. Offscreen/clipped portraits stop animating. Reveal particles are bounded, and queued repeated results coalesce during longer reveals.

These remain replaceable placeholder assets. Physical midrange Android performance, speaker mix and device cutout behavior still require device testing.
