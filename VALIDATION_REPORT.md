# Validation Report

Reviewed on **Godot 4.7.2**. Reproducible commands in the README.

## Checks Performed

| Check | Description |
|-------|-------------|
| **Static** | Resources, main scene, hierarchies and current rig; caches ignored |
| **Headless import** | Scenes and scripts accepted by Godot editor |
| **Gameplay regression** | Ground, camera, animation timer, self-hit, dummies, combat tips, city transition, real hits, lock-on, death and restart |
| **Wall regression** | Surface detection, grip, sliding, opposite wall jumps, limit, ground refill, blocking during other states, real pickup, persistence and duplicate prevention |

## Coverage Notes

Tests do not guarantee the absence of all bugs. They do not cover all map routes, all combos, performance or appearance. Wall jump feel and camera require manual evaluation. No new visual inspection was performed in this review.

## UI Review

Health, mana, invalid spend, regeneration, limits and bindings after scene change/death are covered by `tools/test_hud.gd`. Courtyard and city screenshots were inspected at 1280×720, including bars after damage and mana spend by the test. No enemy AI changes were made in this review.
