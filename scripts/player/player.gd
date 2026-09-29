class_name PlayerController
extends CharacterBody3D

## Controla movimento, salto, esquiva, dano e recuperação de quedas.
## Combate, seleção de alvo e poses ficam em componentes separados.


@export var move_speed: float = 6.5
@export var run_speed: float = 9.5
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var rotation_speed: float = 14.0
@export var jump_velocity: float = 9.0
@export var air_control: float = 0.42
@export var gravity: float = 24.0
@export var dodge_speed: float = 15.0
@export var dodge_duration: float = 0.34
@export var dodge_cooldown: float = 0.42
@export var invulnerability_start: float = 0.05
@export var invulnerability_end: float = 0.25
@export_category("Fall Recovery")
@export var fall_limit_y: float = -18.0
@export var respawn_height_offset: float = 0.65
@export var safe_position_delay: float = 0.30

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var combat: CombatController = $CombatController
@onready var lock_on: LockOnController = $LockOnController
@onready var health: HealthComponent = $HealthComponent
@onready var animation_controller: PlayerAnimationController = get_node_or_null("PlayerAnimationController") as PlayerAnimationController

var mana: ManaComponent
var wall_movement: WallMovement

var _dodge_elapsed: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _air_dodge_used: bool = false
var _hit_stun_left: float = 0.0
var _dead: bool = false
var _perfect_dodge_consumed: bool = false
var _move_hold_time: float = 0.0
var _spawn_position: Vector3
var _last_safe_position: Vector3
var _safe_grounded_time: float = 0.0

func _ready() -> void:
	mana = ManaComponent.new()
	mana.name = "ManaComponent"
	add_child(mana)
	wall_movement = WallMovement.new()
	wall_movement.name = "WallMovement"
	add_child(wall_movement)
	_spawn_position = global_position
	_last_safe_position = global_position
	GameManager.register_player(self)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	wall_movement.gripping = false
	if not _dead:
		_track_safe_position(delta)
		if global_position.y <= fall_limit_y:
			_respawn_from_fall()
			return
	if _dead:
		velocity.y -= gravity * delta
		move_and_slide()
		return
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		_air_dodge_used = false
	if Input.is_action_just_pressed("lock_on"):
		lock_on.toggle_lock()
	if _hit_stun_left > 0.0:
		_hit_stun_left -= delta
		if _hit_stun_left <= 0.0:
			state_machine.set_state(PlayerStateMachine.State.IDLE if is_on_floor() else PlayerStateMachine.State.FALL)
		move_and_slide()
		return
	if Input.is_action_just_pressed("dodge") and _can_start_dodge():
		_start_dodge()
	if state_machine.state == PlayerStateMachine.State.DODGE:
		_update_dodge(delta)
		move_and_slide()
		return
	if state_machine.allows_locomotion():
		_update_locomotion(delta)
	elif combat.is_attacking():
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	var wall_direction := _camera_relative_direction(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	wall_movement.update_motion(self, wall_direction, delta, state_machine.allows_locomotion())
	move_and_slide()
	_update_air_state()


## Só grava chão estável; evita reaparecer em posições de ataque ou queda.
func _track_safe_position(delta: float) -> void:
	if is_on_floor() and state_machine.state not in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		_safe_grounded_time += delta
		if _safe_grounded_time >= safe_position_delay:
			_last_safe_position = global_position
	else:
		_safe_grounded_time = 0.0


## Cancela ações e reposiciona a câmera junto do jogador, sem recarregar o mapa.
func _respawn_from_fall() -> void:
	wall_movement.reset()
	combat.cancel_attack()
	lock_on.clear_target()
	velocity = Vector3.ZERO
	_dodge_elapsed = 0.0
	_dodge_cooldown_left = 0.0
	_hit_stun_left = 0.0
	_air_dodge_used = false
	_perfect_dodge_consumed = false
	_move_hold_time = 0.0
	_safe_grounded_time = 0.0
	var respawn_position := _last_safe_position
	if respawn_position.y <= fall_limit_y + 2.0:
		respawn_position = _spawn_position
	global_position = respawn_position + Vector3.UP * respawn_height_offset
	state_machine.set_state(PlayerStateMachine.State.IDLE)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent() != null and camera.get_parent().get_parent() is ThirdPersonCameraController:
		(camera.get_parent().get_parent() as ThirdPersonCameraController).snap_to_player()


func _update_locomotion(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		state_machine.set_state(PlayerStateMachine.State.JUMP)
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_vec)
	var grounded := is_on_floor()
	if input_vec.length_squared() > 0.01:
		_move_hold_time += delta
	else:
		_move_hold_time = 0.0
	var desired_speed := run_speed if _move_hold_time >= 0.42 and lock_on.get_target() == null else move_speed
	var control := 1.0 if grounded else air_control
	var desired_velocity := direction * desired_speed
	var rate := acceleration if direction.length_squared() > 0.0 else deceleration
	velocity.x = move_toward(velocity.x, desired_velocity.x, rate * control * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, rate * control * delta)
	var target := lock_on.get_target()
	if is_instance_valid(target) and grounded:
		lock_on.face_target(self, delta, rotation_speed)
	elif direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
	if grounded and velocity.y <= 0.0:
		state_machine.set_state(PlayerStateMachine.State.MOVE if direction.length_squared() > 0.01 else PlayerStateMachine.State.IDLE)


func _camera_relative_direction(input_vec: Vector2) -> Vector3:
	if input_vec.length_squared() <= 0.001:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input_vec.x + forward * -input_vec.y).normalized()


func _can_start_dodge() -> bool:
	if _dodge_cooldown_left > 0.0 or state_machine.state in [PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return false
	if not is_on_floor() and _air_dodge_used:
		return false
	if combat.is_attacking():
		return combat.can_cancel_to_dodge()
	return true


func _start_dodge() -> void:
	if combat.is_attacking():
		combat.cancel_attack()
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_dodge_direction = _camera_relative_direction(input_vec)
	if _dodge_direction.length_squared() <= 0.001:
		_dodge_direction = global_transform.basis.z.normalized()
	_dodge_elapsed = 0.0
	_dodge_cooldown_left = dodge_cooldown
	_perfect_dodge_consumed = false
	if not is_on_floor():
		_air_dodge_used = true
	state_machine.set_state(PlayerStateMachine.State.DODGE)
	var dodge_yaw := atan2(_dodge_direction.x, _dodge_direction.z)
	rotation.y = dodge_yaw
	if animation_controller != null:
		animation_controller.notify_dodge_started(dodge_duration)


func _update_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	velocity.x = _dodge_direction.x * dodge_speed
	velocity.z = _dodge_direction.z * dodge_speed
	if not is_on_floor():
		velocity.y = maxf(velocity.y, -1.5)
	if _dodge_elapsed >= dodge_duration:
		state_machine.set_state(PlayerStateMachine.State.IDLE if is_on_floor() else PlayerStateMachine.State.FALL)


func receive_hitbox(hitbox: HitboxComponent) -> bool:
	if _dead:
		return false
	if _is_invulnerable():
		if _is_perfect_dodge_window() and not _perfect_dodge_consumed:
			_perfect_dodge_consumed = true
			_trigger_perfect_dodge()
		return false
	if not health.damage(hitbox.damage):
		return false
	GameManager.player_damaged()
	if _dead:
		return true
	combat.cancel_attack()
	var source_position := global_position - global_transform.basis.z
	if is_instance_valid(hitbox.source) and hitbox.source is Node3D:
		source_position = (hitbox.source as Node3D).global_position
	var direction := global_position - source_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = -global_transform.basis.z
	direction = direction.normalized()
	velocity.x = direction.x * hitbox.knockback
	velocity.z = direction.z * hitbox.knockback
	velocity.y = maxf(velocity.y, hitbox.launch_force)
	_hit_stun_left = hitbox.hit_stun
	state_machine.set_state(PlayerStateMachine.State.HIT)
	if animation_controller != null:
		animation_controller.notify_hit_started(hitbox.hit_stun)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent() != null and camera.get_parent().get_parent() is ThirdPersonCameraController:
		(camera.get_parent().get_parent() as ThirdPersonCameraController).hit_impulse(0.11, true)
	return true


func get_lock_target() -> Node3D:
	return lock_on.get_target()


func get_state_name() -> String:
	return state_machine.state_name()


func is_alive() -> bool:
	return not _dead


func _is_invulnerable() -> bool:
	return state_machine.state == PlayerStateMachine.State.DODGE and _dodge_elapsed >= invulnerability_start and _dodge_elapsed <= invulnerability_end


func _is_perfect_dodge_window() -> bool:
	return _is_invulnerable() and _dodge_elapsed <= minf(invulnerability_end, invulnerability_start + 0.10)


func _trigger_perfect_dodge() -> void:
	GameManager.register_perfect_dodge()
	GameManager.perfect_dodge_slow_motion()
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent() != null and camera.get_parent().get_parent() is ThirdPersonCameraController:
		(camera.get_parent().get_parent() as ThirdPersonCameraController).kick_fov(-4.0, 0.20)


func _update_air_state() -> void:
	if state_machine.state in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return
	if not is_on_floor():
		state_machine.set_state(PlayerStateMachine.State.JUMP if velocity.y > 0.0 else PlayerStateMachine.State.FALL)


## A morte reinicia a cena atual; ainda não existe sistema de checkpoints.
func _on_died() -> void:
	_dead = true
	mana.regeneration_enabled = false
	combat.cancel_attack()
	state_machine.set_state(PlayerStateMachine.State.DEAD)
	velocity = Vector3.ZERO
	lock_on.clear_target()
	if animation_controller != null:
		animation_controller.notify_dead()
	await get_tree().create_timer(2.0).timeout
	GameManager.reset_style()
	get_tree().reload_current_scene()
