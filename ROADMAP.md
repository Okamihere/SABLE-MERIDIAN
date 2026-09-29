# ROADMAP — SABLE MERIDIAN Combat Prototype

## Goal
A Godot 4.x vertical slice focused on responsive third-person stylish action combat, built from replaceable primitive placeholders.

## Phase 1 — Foundation
- Project structure, autoload, runtime input bootstrap.
- Gothic-fantasy blockout arena with two connected combat spaces.
- CharacterBody3D player, responsive camera-relative movement, jump and air control.
- SpringArm3D third-person camera with smoothing and wall collision.

## Phase 2 — Combat Core
- Reusable HealthComponent, HitboxComponent and HurtboxComponent.
- Player attacks, damage delivery, dummy enemy and health feedback.

## Phase 3 — Combo
- Player state machine, input buffer, light chain, heavy attack, launcher and aerial attacks.
- Basic juggle support and attack cancel timing.

## Phase 4 — Defense
- Directional ground/air dodge, i-frames and perfect dodge.
- Generic short slow-motion response.

## Phase 5 — Enemies
- Basic state-driven enemy AI: idle, chase, attack, hit, launched, dead.
- Separation steering for multiple enemies.

## Phase 6 — Game Feel
- Hit stop, camera shake/FOV kick, placeholder procedural attack motion and impact flash.

## Phase 7 — Style System
- Combo count, style score, repetition penalty, ranks D/C/B/A/S and HUD.

## Phase 8 — Environment Polish
- Monumental blockout silhouettes, stairs, platforms, arches, fog and dramatic lighting.

## Validation strategy
Godot CLI is not available in the generation environment. The project therefore includes `tools/validate_project.py` for static path/reference checks. Final runtime validation should be performed by opening the project in Godot 4.x and running the main scene.
