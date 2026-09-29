# SABLE MERIDIAN — Godot 4 Combat Prototype

A self-contained third-person action prototype using only Godot primitives and GDScript.

## Quick Start

1. Open this folder in **Godot 4.x**
2. Run the project (`F5` / `F6` — main scene is pre-configured)
3. Click the game window to capture the mouse

## Controls

| Key | Action |
|-----|--------|
| `WASD` | Move |
| `Space` | Jump |
| `Shift` | Dodge |
| `Left Mouse` | Light attack |
| `Right Mouse` | Heavy attack |
| `Q` | Toggle lock-on |
| `Esc` | Release/capture mouse |
| `F3` | Toggle combat debug overlay |

## Combat

- Chain light attacks for a **four-hit combo**
- After the second light, heavy becomes a **launcher**
- In the air, light attacks keep launched targets suspended
- Dodge late into an incoming hit to trigger a **perfect dodge**

## Wall Movement & Orbs

- Jump against a wall and hold toward it — the character **grips for 0.4s**, then slides slowly
- Press **Space again** to kick off; chain jumps between walls
- You start with **2 wall jumps per air sequence**; touching the ground refills the reserve
- Each **blue orb** found increases the limit by **+1** (3 orbs placed in the prototype)
- Orb collection is saved to `user://wall_orbs.cfg` and persists across deaths and restarts

## World

The prototype is a large but finite environment with multiple connected districts and distant skyline geometry for an open-world feel. The starting room lets you test controls — press **Enter** to enter the city.

## Fall Recovery

If the player falls below the playable world, the controller automatically returns to the last stable grounded position. `fall_limit_y`, `respawn_height_offset`, and `safe_position_delay` are exported under **Fall Recovery** on the Player node.

## HUD & Mana

The HUD shows health (red), mana (blue), wall jumps, style rank, and pickup notifications. Mana starts at 100 and regenerates at 8/s after 1.5s without spending. No current ability consumes mana yet — the system is ready for future powers.

## Responsive UI

The interface adapts to any window size — compact panels on small screens, scaled-up on larger ones, ultrawide support included. Validated at 320×568 up to 3840×2160.

## Testing

```sh
python3 tools/validate_project.py
godot --headless --path . --editor --quit
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_wall_movement.gd
godot --headless --path . --script tools/test_hud.gd
godot --headless --path . --script tools/test_responsive.gd
```

## Project Structure

```
SABLE-MERIDIAN/
├── scenes/          # Game scenes (player, enemies, levels)
├── scripts/         # GDScript files
├── resources/       # Sprites, sounds, materials
├── effects/         # Visual effects
├── materials/       # Godot materials
├── tools/           # Test & validation tools
└── project.godot    # Project configuration
```

## Documentation

- [Contributing Guide](CONTRIBUTING.md) — how to help with the project
- [Development Notes](DEV_NOTES.md) — architecture & conventions
- [Roadmap](ROADMAP.md) — development phases & goals
- [TODO](TODO.md) — upcoming tasks & ideas
- [Validation Report](VALIDATION_REPORT.md) — test results & coverage
