class_name LockOnController
extends Node

signal target_changed(target: Node3D)

@export var max_distance: float = 24.0
@export var center_weight: float = 10.0
@export var distance_weight: float = 0.35

var current_target: Node3D

func toggle_lock() -> void:
	if is_instance_valid(current_target):
		clear_target()
	else:
		acquire_target()

func acquire_target() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var origin := get_parent() as Node3D
	var best_score := INF
	var best_target: Node3D
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node3D):
			continue
		var enemy := candidate as Node3D
		if enemy.has_method("is_alive") and not enemy.call("is_alive"):
			continue
		var distance := origin.global_position.distance_to(enemy.global_position)
		if distance > max_distance or camera.is_position_behind(enemy.global_position):
			continue
		var screen_pos := camera.unproject_position(enemy.global_position + Vector3.UP * 1.2)
		var center_distance := screen_pos.distance_to(screen_center) / maxf(1.0, viewport_size.length())
		var score := center_distance * center_weight + distance * distance_weight
		if score < best_score:
			best_score = score
			best_target = enemy
	current_target = best_target
	target_changed.emit(current_target)
	return current_target

func clear_target() -> void:
	current_target = null
	target_changed.emit(null)

func get_target() -> Node3D:
	if is_instance_valid(current_target):
		if current_target.has_method("is_alive") and not current_target.call("is_alive"):
			clear_target()
	return current_target

func face_target(body: Node3D, delta: float, rotation_speed: float) -> void:
	var target := get_target()
	if target == null:
		return
	var direction := target.global_position - body.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
