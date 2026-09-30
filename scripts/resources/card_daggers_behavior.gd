class_name CardDaggersBehavior
extends WeaponBehavior

## O corte pesado dobra a distância por um instante, sem atravessar paredes.
func on_attack_started(player: PlayerController, attack: AttackData) -> void:
	if attack.attack_id != &"dagger_blink":
		return
	var direction := player.global_transform.basis.z.normalized()
	var target: Node3D = player.get_lock_target()
	var distance := 2.4
	if is_instance_valid(target):
		var toward := target.global_position - player.global_position
		toward.y = 0.0
		if toward.length_squared() > 0.01:
			direction = toward.normalized()
			distance = clampf(toward.length() - 1.2, 0.0, 2.8)
	if distance < 0.25:
		return
	var space := player.get_world_3d().direct_space_state
	var body_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_shape == null or body_shape.shape == null:
		return
	var origin := player.global_position + Vector3.UP
	var destination := origin + direction * distance
	var wall_query := PhysicsRayQueryParameters3D.create(origin, destination, 1)
	wall_query.exclude = [player.get_rid()]
	var wall := space.intersect_ray(wall_query)
	if not wall.is_empty():
		distance = maxf(0.0, origin.distance_to(wall.position) - 0.6)
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = body_shape.shape
	var sweep_xform := body_shape.global_transform
	sweep_xform.origin.y += 0.15
	sweep.transform = sweep_xform
	sweep.motion = direction * distance
	sweep.collision_mask = 1
	sweep.exclude = [player.get_rid()]
	var clearance := space.cast_motion(sweep)
	if clearance.size() >= 1:
		distance = maxf(0.0, distance * clearance[0] - 0.08)
	if distance < 0.25:
		return
	var next_position := player.global_position + direction * distance
	var floor_query := PhysicsRayQueryParameters3D.create(next_position + Vector3.UP * 1.2, next_position - Vector3.UP * 2.5, 1)
	floor_query.exclude = [player.get_rid()]
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.65:
		return
	var landing := Vector3(next_position.x, floor_hit.position.y + 0.05, next_position.z)
	var overlap := PhysicsShapeQueryParameters3D.new()
	overlap.shape = body_shape.shape
	overlap.transform = Transform3D(body_shape.global_transform.basis, landing + body_shape.position)
	overlap.collision_mask = 1
	overlap.exclude = [player.get_rid()]
	if not space.intersect_shape(overlap, 1).is_empty():
		return
	player.global_position = landing
