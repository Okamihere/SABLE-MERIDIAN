# Validation Report

Reviewed on **Godot 4.7.2**.

## Checks Performed

| Check | Description |
|-------|-------------|
| **Static** | Resources, main scene, hierarchies and current rig; caches ignored |
| **Headless import** | Scenes and scripts accepted by Godot editor |
| **Gameplay regression** | Ground, camera, animation timer, self-hit, dummies, combat tips, city transition, real hits, lock-on, death and restart |
| **Wall regression** | Surface detection, grip, sliding, opposite wall jumps, limit, ground refill, blocking during other states, real pickup, persistence and duplicate prevention |
| **HUD regression** | Health, mana, invalid spend, regeneration, limits and bindings after scene change/death |

## Commands

```sh
python3 tools/validate_project.py
godot --headless --path . --editor --quit
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_wall_movement.gd
godot --headless --path . --script tools/test_hud.gd
godot --headless --path . --script tools/test_responsive.gd
```

## Coverage Notes

Tests do not guarantee the absence of all bugs. They do not cover all map routes, all combos, performance or appearance. Wall jump feel and camera require manual evaluation.
