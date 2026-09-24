# Prompt 15 original environment assets

All 41 SVG files below are original local vector drawings authored for SLIMEROT. No downloaded packs, external images, fonts, or user slime artwork were used. Existing `assets/art/slimes` and existing environment source files are preserved.

The shared palette uses a deep plum outline, cream highlights, and restrained zone colors. Solid obstacles have a readable filled silhouette; decorative details stay inside their original collision footprint. All resources use the normal cached Godot texture loader.

## Zone assets

Each zone has three distinct obstacle silhouettes and a matching boundary tile. Collision rectangles, navigation, enemy spawns and progression data are unchanged.

| Zone | `obstacle` | `rock` | `prop` | `border` |
|---|---|---|---|---|
| Backyard | Fruit tree | Garden boulders | Tool shed | Picket fence |
| Italian Village | Terracotta house | Olive barrel / stones | Espresso cart | Masonry |
| Cursed Forest | Spectral tree | Rune boulder | Mushroom cluster | Dark timber fence |
| Sahara | Router obelisk | Layered sandstone | Antenna cactus | Sandstone blocks |
| Brainrot City | Cable kiosk | Recycling heap | Vending tower | Cable barrier |
| Backrooms | Office partition | Filing trolley | Floor lamp / box | Wallpaper divider |
| Moon | Crater rock | Crystal deposit | Moon habitat | Lunar stone |
| Brainrot Dimension | Crystal growth | Eye relic | Sentient totem | Fractured crystal |

## Exact SVG manifest

- `assets/environment/structures/Slimerot_boss_portal.svg`
- `assets/environment/structures/Slimerot_fast_travel_pillar.svg`
- `assets/environment/structures/Slimerot_gate_closed.svg`
- `assets/environment/structures/Slimerot_gate_open.svg`
- `assets/environment/structures/Slimerot_mutation_lab.svg`
- `assets/environment/structures/Slimerot_portal.svg`
- `assets/environment/structures/Slimerot_potion_bench.svg`
- `assets/environment/structures/Slimerot_sell_terminal.svg`
- `assets/environment/structures/Slimerot_skill_tree_shrine.svg`
- `assets/environment/zones/Slimerot_backrooms_border.svg`
- `assets/environment/zones/Slimerot_backrooms_obstacle.svg`
- `assets/environment/zones/Slimerot_backrooms_prop.svg`
- `assets/environment/zones/Slimerot_backrooms_rock.svg`
- `assets/environment/zones/Slimerot_backyard_border.svg`
- `assets/environment/zones/Slimerot_backyard_obstacle.svg`
- `assets/environment/zones/Slimerot_backyard_prop.svg`
- `assets/environment/zones/Slimerot_backyard_rock.svg`
- `assets/environment/zones/Slimerot_brainrot_city_border.svg`
- `assets/environment/zones/Slimerot_brainrot_city_obstacle.svg`
- `assets/environment/zones/Slimerot_brainrot_city_prop.svg`
- `assets/environment/zones/Slimerot_brainrot_city_rock.svg`
- `assets/environment/zones/Slimerot_brainrot_dimension_border.svg`
- `assets/environment/zones/Slimerot_brainrot_dimension_obstacle.svg`
- `assets/environment/zones/Slimerot_brainrot_dimension_prop.svg`
- `assets/environment/zones/Slimerot_brainrot_dimension_rock.svg`
- `assets/environment/zones/Slimerot_cursed_forest_border.svg`
- `assets/environment/zones/Slimerot_cursed_forest_obstacle.svg`
- `assets/environment/zones/Slimerot_cursed_forest_prop.svg`
- `assets/environment/zones/Slimerot_cursed_forest_rock.svg`
- `assets/environment/zones/Slimerot_italian_village_border.svg`
- `assets/environment/zones/Slimerot_italian_village_obstacle.svg`
- `assets/environment/zones/Slimerot_italian_village_prop.svg`
- `assets/environment/zones/Slimerot_italian_village_rock.svg`
- `assets/environment/zones/Slimerot_moon_border.svg`
- `assets/environment/zones/Slimerot_moon_obstacle.svg`
- `assets/environment/zones/Slimerot_moon_prop.svg`
- `assets/environment/zones/Slimerot_moon_rock.svg`
- `assets/environment/zones/Slimerot_sahara_border.svg`
- `assets/environment/zones/Slimerot_sahara_obstacle.svg`
- `assets/environment/zones/Slimerot_sahara_prop.svg`
- `assets/environment/zones/Slimerot_sahara_rock.svg`

Every SVG has a companion `.svg.import` Godot texture import configuration. Cached imported binaries under `.godot/` are not source assets and are excluded from publication.

## Integration

- `SlimerotAssets.environment(zone_id, kind)` resolves zone artwork (`obstacle`, `rock`, `prop`, `border`).
- `SlimerotAssets.structure(id)` prefers the new structure artwork and retains the established fallback asset path.
- `SlimerotZone` caches textures once when a zone loads. Props are batched in `_draw()` with no per-prop nodes; all existing solid rectangles and navigation remain unchanged.
- Five persistent structure IDs remain `skill_tree_shrine`, `sell_terminal`, `potion_bench`, `fast_travel_pillar`, `mutation_lab` (displayed as Variant Shrine).
- Gate resources keep the established `gate_open`, `gate_closed`, `boss_portal`, and `portal` IDs. Gameplay gate state remains owned by `WorldManager`.

## Validation

- 41/41 SVG documents passed XML parsing.
- 41/41 SVG resources were imported by Godot 4.5.1 and rasterized successfully through Godot's SVG loader.
- The complete raster contact sheet was visually inspected for clipping, missing shapes, and consistent silhouettes. The contact sheet and its helper scripts are outside the repository and are not shipped assets.
- Runtime, packed-export and full integration results are reported in the main Prompt 15 report.
