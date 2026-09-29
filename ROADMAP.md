# Roadmap — SABLE MERIDIAN Combat Prototype

## Goal

A Godot 4.x vertical slice focused on responsive third-person stylish action combat, built from replaceable primitive placeholders.

## Phases

### Phase 1 — Foundation
- [x] Project structure, autoload, runtime input bootstrap
- [x] Gothic-fantasy blockout arena with two connected combat spaces
- [x] `CharacterBody3D` player, responsive camera-relative movement, jump and air control
- [x] `SpringArm3D` third-person camera with smoothing and wall collision

### Phase 2 — Combat Core
- [x] Reusable `HealthComponent`, `HitboxComponent` and `HurtboxComponent`
- [x] Player attacks, damage delivery, dummy enemy and health feedback

### Phase 3 — Combo
- [x] Player state machine, input buffer, light chain, heavy attack, launcher and aerial attacks
- [x] Basic juggle support and attack cancel timing

### Phase 4 — Defense
- [x] Directional ground/air dodge, i-frames and perfect dodge
- [x] Generic short slow-motion response

### Phase 5 — Enemies
- [x] Basic state-driven enemy AI: idle, chase, attack, hit, launched, dead
- [x] Separation steering for multiple enemies

### Phase 6 — Game Feel
- [x] Hit stop, camera shake/FOV kick, placeholder procedural attack motion and impact flash

### Phase 7 — Style System
- [x] Combo count, style score, repetition penalty, ranks D/C/B/A/S and HUD

### Phase 8 — Environment Polish
- [x] Monumental blockout silhouettes, stairs, platforms, arches, fog and dramatic lighting

## Validation

Use the commands from the README: static validation, Godot import, combat/tutorial test, and wall/orb test. Wall upgrades already have their own persistence; the full save system remains on the roadmap.
