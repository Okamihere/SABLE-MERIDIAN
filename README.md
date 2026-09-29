# Nocturne Vector — Godot 4 Combat Prototype

A self-contained third-person action prototype using only Godot primitives and GDScript.

## Run
1. Open this folder in Godot 4.x.
2. Run the project (`F6/F5` depending on your workflow; main scene is configured).
3. Click the game window to capture the mouse.

## Controls
- WASD: move
- Space: jump
- Shift: dodge
- Left Mouse: light attack
- Right Mouse: heavy attack
- Q: toggle lock-on
- Esc: release/capture mouse
- F3: toggle combat debug overlay/volumes

## Combat notes
- Chain light attacks for a four-hit combo.
- After the second light, heavy becomes a launcher.
- In the air, light attacks help keep launched targets suspended.
- Dodge late into an incoming enemy hit to trigger a perfect dodge.

## World layout
The prototype is now a large but finite environment rather than a single enclosed arena. The playable blockout spans multiple connected districts and uses distant skyline geometry to create an open-world-like sense of scale without requiring actual open-world streaming.

## Fall recovery
If the player falls below the playable world, the controller automatically returns to the last stable grounded position. `fall_limit_y`, `respawn_height_offset` and `safe_position_delay` are exported under **Fall Recovery** on the Player node.
