# Development Notes — SABLE MERIDIAN

See [docs/architecture.md](docs/architecture.md) for component responsibilities and [docs/validation.md](docs/validation.md) for test commands.

## Active player scene

Both levels instance `scenes/player/player_rig.tscn`. `scenes/player/player.tscn` is a legacy placeholder. The player root owns movement, collision, combat, hitboxes, health and lock-on. The visible player uses eight camera-relative idle images in `AnimatedSprite3D`. The retained jester rig is under the hidden `ModelRoot`; its `Skeleton3D` is controlled by `PlayerAnimationController`.

The supplied `paiaço.glb` contained only an untextured static mesh. `assets/characters/jester_rig.glb` adds a seven-bone procedural skin, normals and costume vertex colors. `materials/jester_costume.tres` enables those colors. `tools/generate_clown_rig.py` can rebuild the game asset from the original GLB with NumPy. It reduces the source geometry to roughly 154,000 triangles. Keep the source GLB available separately if you intend to regenerate the asset.

Animations are procedural poses, not authored clips. Combat timing and damage windows are controlled by `CombatController`; changing visual poses must not change those windows. For detailed combo animation, create a proper rig and animation clips, then adapt the controller to that skeleton.

## Gameplay conventions

- Physics layers: 1 World, 2 Player, 3 Enemies, 4 PlayerHitbox, 5 EnemyHitbox, 6 Hurtbox.
- Characters face **+Z** in gameplay; the imported jester is rotated under `ModelRoot` to match.
- Hitboxes must initialize their owner and ignore their own hurtbox. Monitoring changes are deferred to respect physics callbacks.
- `Progression` stores wall-orb upgrades; it is not a complete save system.
- The starting room opens the city when the player crosses the fog gate under the north arch. Training lessons are not saved.

Run `python3 tools/validate_project.py` and `godot --headless --path . --script res://tools/test_gameplay.gd` after changing the player, combat or imported art.
