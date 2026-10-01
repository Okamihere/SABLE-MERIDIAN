# Roadmap — SABLE MERIDIAN

## Goal

A Godot 4.x vertical slice focused on responsive third-person stylish action combat.

## Phases

### Phase 1 — Foundation
- [x] Project structure, autoload, runtime input bootstrap
- [x] Gothic-fantasy blockout arena
- [x] `CharacterBody3D` player, camera-relative movement, jump and air control
- [x] `SpringArm3D` third-person camera with smoothing and wall collision

### Phase 2 — Combat Core
- [x] Reusable `HealthComponent`, `HitboxComponent` and `HurtboxComponent`
- [x] Player attacks, damage delivery, dummy enemy and health feedback

### Phase 3 — Combo
- [x] Player state machine, input buffer, light chain, heavy attack, launcher
- [x] Basic juggle support and attack cancel timing

### Phase 4 — Defense
- [x] Directional ground/air dodge, i-frames and perfect dodge
- [x] Generic short slow-motion response

### Phase 5 — Enemies
- [x] Basic state-driven enemy AI: idle, chase, attack, hit, launched, dead
- [x] Separation steering for multiple enemies

### Phase 6 — Game Feel
- [x] Hit stop, camera shake/FOV kick, procedural attack motion and impact flash

### Phase 7 — Style System
- [x] Combo count, style score, repetition penalty, ranks D/C/B/A/S and HUD

### Phase 8 — Environment Polish
- [x] Monumental blockout silhouettes, stairs, platforms, arches, fog and dramatic lighting

## Future

- [ ] Target switching while locked on
- [ ] Double jump as unlockable
- [x] Expand the playable weapon roster to five weapons with Q/E/R skills
- [ ] Expand combo trees and add further weapon variants
- [ ] Navigation/pathfinding for complex levels
- [ ] Boss archetypes and encounter director
- [ ] Pooled VFX, trails, decals, dynamic audio
- [ ] Full campaign save and remappable input UI (orb progress and settings already persist)
