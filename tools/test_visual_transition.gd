extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(10.0).timeout
	push_error("Visual transition test timed out")
	quit(1)

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await process_frame
	await physics_frame
	var training := current_scene
	var stone := training.get_node("Floor").material_override as StandardMaterial3D
	var costume := training.get_node("Player/ModelRoot/Jester/world/Skeleton3D/JesterMesh") as MeshInstance3D
	assert(stone.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "Shared scenery material must use toon lighting")
	assert(stone.specular_mode == BaseMaterial3D.SPECULAR_TOON, "Scenery highlights must use the same style")
	assert(costume != null, "Imported jester model must remain in the scene")
	assert((costume.material_override as StandardMaterial3D).diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "Jester costume must share toon lighting")
	var gate := training.get_node("FogGate")
	assert(gate.get_node("FrontFog").material_override is ShaderMaterial, "Transparent fog must keep its dedicated shader")
	var space: PhysicsDirectSpaceState3D = training.get_world_3d().direct_space_state
	var opening := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, 14), Vector3(0, 1.0, 18))
	assert(space.intersect_ray(opening).is_empty(), "The center of the former north wall must be a real opening")
	var masonry := PhysicsRayQueryParameters3D.create(Vector3(8, 1.0, 14), Vector3(8, 1.0, 18))
	assert(not space.intersect_ray(masonry).is_empty(), "The side wall must still collide")
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 3, 21), Vector3(0, -1, 21))
	assert(not space.intersect_ray(floor_ray).is_empty(), "The covered passage must have a solid floor")
	change_scene_to_file("res://scenes/levels/main.tscn")
	for index in 3:
		await process_frame
	var city := current_scene
	var room := city.get_node("ArrivalChamber")
	assert(room.get_node("ArchitectureCollision").get_child_count() >= 8, "Arrival chamber collision must be complete on first frame")
	assert(room.has_node("ExitLintel") and room.has_node("Runner"), "Procedural chamber must be complete before reveal")
	await physics_frame
	var city_space: PhysicsDirectSpaceState3D = city.get_world_3d().direct_space_state
	var route := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 62), Vector3(0, 1, 52))
	assert(city_space.intersect_ray(route).is_empty(), "Arrival chamber exit must leave a clear route into the city")
	var city_stone := city.get_node("WorldBlockout/SouthTerrace/Floor").material as StandardMaterial3D
	assert(city_stone.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "City CSG must share toon lighting")
	print("PASS: global toon materials, preserved fog shader, open passage, floor and prebuilt arrival chamber")
	quit()
