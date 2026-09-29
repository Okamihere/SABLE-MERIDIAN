# DEV NOTES

## Architecture choices
- `PlayerController` owns locomotion and defensive movement only.
- `CombatController` owns attacks, buffers, combo routing and temporary hitbox activation.
- `LockOnController` is isolated from both locomotion and camera.
- `HealthComponent`, `HitboxComponent` and `HurtboxComponent` are reusable Nodes/Areas.
- `GameManager` is an autoload for input bootstrap, style/combo bookkeeping and global time effects.
- Camera is a world sibling of the player rather than a player child, allowing independent lag and lock-on framing.
- Primitive visuals are children under `Visual`; future imported rigs can replace that branch without changing gameplay components.

## Prototype conventions
- Layers: 1 world, 2 player body, 3 enemy body, 4 player hitboxes, 5 enemy hitboxes, 6 hurtboxes.
- Attacks are data-driven through `AttackData` resources.
- Runtime input bindings are ensured by `GameManager` so the prototype remains robust if `project.godot` is regenerated.
- Perfect dodge is registered when an enemy hitbox contacts the player during the perfect-dodge portion of i-frames.

## Runtime validation
The generation environment had no `godot`, `godot4` or headless Godot executable. Static checks were used instead; run the project once in Godot 4.x before treating it as production-ready.

## Animation system — 2026-09-29
- Replaced primitive visual tweens with a Skeleton3D + AnimationTree rig.
- `PlayerAnimationController` drives procedural animation for combat/dodge/hit/death states.
- AnimationTree uses AnimationNodeStateMachine for locomotion (idle/walk) with blend transitions.
- Bone hierarchy: Hips → Spine → Head, LeftArm, RightArm, LeftLeg, RightLeg.
- Meshes are children of BoneAttachment3D nodes for proper skeletal deformation.
- CombatController notifies animation controller on attack start for synchronized motion.

## World scale pass — 2026-09-29
- Replaced the compact arena layout with a large finite city blockout composed of connected districts: South Terrace, Grand Plaza, North Avenue, Upper Court, West Cloister, East Ruins and a northern Sanctum.
- Added non-playable skyline masses and distant monumental architecture to make the playable space read like part of a much larger city without becoming an open world.
- Reduced fog density and increased camera draw distance so distant landmarks remain visible and help navigation.
- The world intentionally keeps real edges/gaps. Falling below `fall_limit_y` now returns the player to the most recent stable grounded position rather than leaving the character in the void.
- Fall recovery cancels active combat/lock-on, clears velocity and snaps the camera back to the player to avoid a delayed camera catch-up after teleporting.
