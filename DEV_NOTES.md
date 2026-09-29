# Development Guide — SABLE MERIDIAN

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

`WallMovement` is a player-created component. It only detects vertical surfaces on the **World** layer in the pressed direction. The initial impulse has brief protection against immediate re-grip. Base reserve is **2 jumps**; each orb ID adds one. Ground touch and fall recovery reset the spend.

Grip is temporary, then becomes a slide. Releasing the direction drops the wall. Attacks, damage, death, and dodge take priority. The counter is displayed via the `Progression` autoload.

To place upgrades, instance `scenes/collectibles/wall_orb.tscn` and set a unique `orb_id` in the inspector. **Do not change published IDs** — they identify saved pickups. An orb without an ID grants no upgrade. Duplicate pickups do not increase the limit.

## Conventions

- **Physics layers:** 1 World, 2 Player, 3 Enemies, 4 Player hits, 5 Enemy hits, 6 Hurtboxes
- Characters face **+Z**; camera uses **-Z**
- Hitboxes ignore their owner and hit each hurtbox once per activation
- Monitoring is changed deferred to respect physics callbacks
- Death signal is synchronous — do not overwrite `DEAD` after applying fatal damage
- Combat timers use physics delta; buffer and combo expiry use real time
- `GameManager` generation counter prevents old timers from interrupting new time effects

## Flow & Limits

The starting room opens the city via **Enter**. Training is optional and its lessons are not saved. The city is a finite blockout; enemies do not use navigation yet. The scene `player.tscn` is legacy; maps use `player_rig.tscn`.

Run the checks listed in the README. Tests use the development Godot with assertions enabled. Art, camera near walls, and movement balance still need manual evaluation.

## Shared HUD & Mana

`scenes/ui/hud.tscn` is used in both tutorial and city. Its `StyleBoxFlat` can be edited in Godot. Wall jump display and notifications belong to the HUD; `Progression` holds the data and notification timing without creating visual controls.

`PlayerController` creates `ManaComponent` before registering the player. Future powers should check `mana.try_spend(cost)` before acting. No current ability is wired to that consumption. Regeneration stops when the player dies. The HUD reads initial values and follows health/mana signals; it disconnects old bindings when receiving a new player.

## Responsive Layout

Global stretch is disabled to measure the viewport in real pixels. The HUD applies its own scale from **0.85 to 2.5** and organizes panels in logical coordinates. Below **900 width** or **600 height**, it uses compact mode. The tutorial `CanvasLayer` uses the same scale.

The `size_changed` signal recalculates layout; text height with line wrapping is adjusted after the container pass. Lesson changes also reposition the bottom panel. When projecting a 3D target, divide screen position by the HUD scale.
