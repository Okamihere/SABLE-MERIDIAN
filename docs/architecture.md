# Architecture — SABLE MERIDIAN

## Responsibilities

| Component | Role |
|-----------|------|
| `PlayerController` | Movement, damage intake, wall grip |
| `CombatController` | Attack timing via `AttackData` |
| `LockOnController` | Target selection & switching |
| `PlayerStateMachine` | Centralized state management |
| `PlayerAnimationController` | Procedural Skeleton3D poses (no AnimationTree) |
| `GameManager` | Input, style score, global time effects |
| `Progression` | Orb IDs, wall jump limit, local save |

## Animation

Hips is the root; Spine is child of Hips; Head is child of Spine; arms and legs are children of Hips. Rigid meshes follow `BoneAttachment3D`. Damage windows are controlled by combat, not animations.

## Wall Movement

`WallMovement` detects vertical surfaces on the **World** layer in the pressed direction. Base reserve is **2 jumps**; each orb ID adds one. Ground touch and fall recovery reset the spend.

Grip is temporary, then becomes a slide. Releasing the direction drops the wall. Attacks, damage, death, and dodge take priority.

To place upgrades, instance `scenes/collectibles/wall_orb.tscn` and set a unique `orb_id`. **Do not change published IDs** — they identify saved pickups.

## Conventions

- **Physics layers:** 1 World, 2 Player, 3 Enemies, 4 Player hits, 5 Enemy hits, 6 Hurtboxes
- Characters face **+Z**; camera uses **-Z**
- Hitboxes ignore their owner and hit each hurtbox once per activation
- Death signal is synchronous — do not overwrite `DEAD` after fatal damage
- Combat timers use physics delta; buffer and combo expiry use real time

## Flow & Limits

The starting room opens the city via **Enter**. Training is optional and not saved. The city is a finite blockout; enemies do not use navigation yet. `player.tscn` is legacy; maps use `player_rig.tscn`.

## HUD & Mana

`scenes/ui/hud.tscn` is shared between tutorial and city. Mana starts at 100, regenerates at 8/s after 1.5s without spending. No current ability consumes mana — the system is ready for future powers.

## Responsive Layout

Global stretch is disabled. The HUD applies its own scale from **0.85 to 2.5**. Below **900 width** or **600 height**, it uses compact mode. The `size_changed` signal recalculates layout.
