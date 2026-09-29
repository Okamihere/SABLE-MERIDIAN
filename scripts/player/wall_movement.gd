class_name WallMovement
extends Node

## Agarre e salto em paredes do mundo. O chão repõe a reserva de saltos.
## Segure uma direção contra a parede; Espaço consome um salto e afasta o corpo.
@export var jump_speed: float = 9.5
@export var push_speed: float = 7.0
@export var grip_duration: float = 0.4
@export var slide_speed: float = 2.0
var used_jumps: int = 0
var gripping: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var _grip_left: float = 0.4
var _detach_left: float = 0.0
var _push_direction: Vector3 = Vector3.ZERO

func reset() -> void:
	used_jumps = 0
	gripping = false
	wall_normal = Vector3.ZERO
	_grip_left = grip_duration
	_detach_left = 0.0

func remaining() -> int:
	return maxi(0, Progression.max_wall_jumps() - used_jumps)

## Chamado pelo jogador depois da locomoção e antes de move_and_slide.
func update_motion(body: CharacterBody3D, direction: Vector3, delta: float, allowed: bool) -> void:
	gripping = false
	wall_normal = Vector3.ZERO
	if body.is_on_floor():
		reset()
		return
	_detach_left = maxf(0.0, _detach_left - delta)
	if not allowed:
		return
	if _detach_left > 0.0:
		# Preserva o impulso inicial mesmo que a direção continue apontando para a parede.
		body.velocity.x = _push_direction.x * push_speed
		body.velocity.z = _push_direction.z * push_speed
		return
	wall_normal = find_wall(body, direction)
	if wall_normal == Vector3.ZERO or remaining() == 0:
		return
	if Input.is_action_just_pressed("jump"):
		used_jumps += 1
		_push_direction = wall_normal
		body.velocity = wall_normal * push_speed + Vector3.UP * jump_speed
		body.rotation.y = atan2(wall_normal.x, wall_normal.z)
		_detach_left = 0.18
		_grip_left = grip_duration
		return
	if body.velocity.y <= 0.0:
		gripping = true
		_grip_left = maxf(0.0, _grip_left - delta)
		body.velocity.y = 0.0 if _grip_left > 0.0 else maxf(body.velocity.y, -slide_speed)

## Só aceita superfícies verticais da camada World; inimigos não são paredes.
func find_wall(body: CharacterBody3D, direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.01:
		return Vector3.ZERO
	var origin := body.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 0.75, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO
	var normal: Vector3 = hit.normal
	if absf(normal.y) > 0.2 or direction.dot(normal) > -0.4:
		return Vector3.ZERO
	return Vector3(normal.x, 0, normal.z).normalized()
