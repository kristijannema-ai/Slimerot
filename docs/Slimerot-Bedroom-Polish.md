# Bedroom Hub: compact layout and depth polish

The existing Bedroom Hub is now 10% smaller on each axis (1620 x 1458 world units), with its camera following at the same zoom and the original full-size player. All navigation, collision queries, spawn coordinates and interaction anchors follow the new scale.

Furniture uses the existing illustrations with engine-rendered 2.5D depth: a projected, softened silhouette shadow, soft contact shadow and subtle directional surface shading. These remain separate playable 2D props, not actual 3D meshes. The room and reference composition remain intact.

Wooden signs are centered on their stations and their icon/caption groups are centered inside the plaque. They have a visible bottom/right side, bevel lighting, wood grain, brass pins and a stationary cast shadow. Each floats vertically by up to 3 authored pixels (2.7 world pixels) over 3.5 seconds. Animation pauses with gameplay menus and has no cumulative drift. Exact text and icons are retained, including Collection's open book and the low To Backyard sign.

## Changed files

- `scenes/zones/SlimerotBedroom.tscn`: 0.9 room scale, centered sign/interaction anchors, depth presentation attached to furniture and interior plants.
- `scripts/world/SlimerotBedroom.gd`: scaled spawn/camera/anchor coordinates, world-space collision and navigation with original player clearance.
- `scripts/world/SlimerotBedroomSign.gd`: dimensional wooden plaques, measured centered captions/icons, paused-aware bob and fixed shadow.
- `scripts/world/SlimerotWorld.gd`: place shared interactions at World coordinates after parenting so the Bedroom scale is applied once.
- `tests/SlimerotBedroomTests.gd`: room scale, player clearance, navigation, station alignment, centered signs, bounded bob and full plaque visibility.
- `docs/Slimerot-Bedroom-Polish.md`: this delivery and testing record.

## Added assets and code

- `scripts/world/SlimerotBedroomProp.gd` and its `.uid`: reusable cached contact/projected shadows and surface-material setup.
- `assets/environment/bedroom/furniture_surface.gdshader` and its `.uid`: restrained upper-left surface relief and warm directional shading.
- `assets/environment/bedroom/furniture_shadow.gdshader` and its `.uid`: softened projected silhouette with distance fade.

No new bitmap images were added. All nine existing Bedroom environment PNGs were reused unchanged. User-provided slime sprites, floor/greenery drawing, shared UI, balance, currencies, skill backend and save behavior are unchanged. Painted furniture remains replaceable concept art; floor/wall/lantern details remain procedural art. No new temporary visual placeholders were introduced.

## Interactions

- Bed calls the existing `SaveManager.save_game()`.
- Collection calls the shared HUD's existing Collection tab.
- Shrine keeps WorldManager's existing 25-Coin repair/unlock and the shared Skills interface/SkillTreeManager.
- Sell Terminal keeps its existing 75-Coin repair and Team inventory selling route/InventoryManager.
- Walking downward through the open bottom path still invokes WorldManager's normal zone exit. There is no portal.

## Verification

Godot 4.5.1: full regression suite **2,324 checks, zero failures**, including the Bedroom integration tests. The focused Bedroom suite previously passed 84 checks; its assertions are included in the final full run. Final full-run, OpenGL compatibility captures and exported-pack startup contain no parser/runtime/shader errors. Android-preset resource pack exported successfully and started independently for 180 headless frames. Portrait screenshots were inspected at 720 x 1280. Tests used isolated save profiles.

No Android handset was available: device frame rate and installed APK behavior are not claimed as tested. Rendering uses small prop-local shaders, a shared generated contact texture, cached geometry and five sign transform updates; no extra viewport, full-screen effect or dynamic lighting pass was introduced.

## Exact manual test steps

1. Open `project.godot` from this branch in Godot 4.5.x, allow imports and run the game in a 720 x 1280 window. Enter Bedroom Hub. The camera follows normally, the player retains its size and all room distances are 90% of the prior version.
2. Walk from the spawn across the purple rug toward each station. Confirm bed upper-left, Collection upper-center, shrine upper-right and Sell lower-right. Furniture is solid; the central floor and rug remain traversable. Inspect cast/contact shadows below the furniture while moving the camera.
3. Stand in front of each station. Its plaque should be centered horizontally on the prop, have visible thickness, and float very slightly. Watch for at least 7 seconds (two cycles); no horizontal drift. Open a menu: the motion pauses. Close it: the motion resumes without a jump back to the original position.
4. Approach Bed and press INTERACT. Quit and reopen the game; confirm the existing save loads and the return spawn is unobstructed.
5. Approach Collection and press INTERACT. Confirm the existing Collection screen opens, the sign says exactly Collection / View Your Slimes and shows an open book. Close the screen and move again.
6. Approach the shrine. If unrepaired, verify the existing 25-Coin unlock when affordable; then interact to open Skills and check existing purchases. Already-repaired saves must not pay twice.
7. Approach Sell Terminal. If unrepaired, verify its existing 75-Coin unlock; then interact to open the Team inventory selling route. Sell an eligible duplicate using the existing UI and confirm protected/equipped copies remain intact.
8. Walk toward bottom-center. The low To Backyard sign must remain readable above the touch controls; grass/flowers start beside the stone path. Walk straight DOWN through the opening without pressing INTERACT: Backyard should load normally.
9. Use Backyard's normal return gate. Confirm Bedroom Hub returns at its safe spawn with no instant bounce back outside. Repeat steps 4-8 after a save/load.
10. Export/install with the existing Slimerot Android preset on a test phone. Check font readability, joystick plus interaction input, room navigation, save/restart and frame pacing while crossing the room. Compare performance with the prior build on that same device.
