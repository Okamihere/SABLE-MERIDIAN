class_name CombatController
extends Node

## Executa ataques definidos em AttackData e controla as janelas das hitboxes.
## Guarda entradas por um curto período e encadeia golpes conforme o combo atual.

@export var input_buffer_time: float = 0.18
@export var combo_window: float = 0.18
@export var attack_cancel_window: float = 0.16
@export var light_hitbox_path: NodePath = NodePath("../Hitboxes/LightHitbox")
@export var heavy_hitbox_path: NodePath = NodePath("../Hitboxes/HeavyHitbox")
@export var state_machine_path: NodePath = NodePath("../StateMachine")
@export var lock_on_path: NodePath = NodePath("../LockOnController")
@export var animation_controller_path: NodePath = NodePath("../PlayerAnimationController")

const LIGHT_1: AttackData = preload("res://resources/attacks/light_1.tres")
const LIGHT_2: AttackData = preload("res://resources/attacks/light_2.tres")
const LIGHT_3: AttackData = preload("res://resources/attacks/light_3.tres")
const LIGHT_4: AttackData = preload("res://resources/attacks/light_4.tres")
const HEAVY: AttackData = preload("res://resources/attacks/heavy.tres")
const LAUNCHER: AttackData = preload("res://resources/attacks/launcher.tres")
const AIR_LIGHT: AttackData = preload("res://resources/attacks/air_light.tres")
const AIR_HEAVY: AttackData = preload("res://resources/attacks/air_heavy.tres")
const HIT_SPARK: PackedScene = preload("res://scenes/effects/hit_spark.tscn")

var _owner_body: CharacterBody3D
var _state_machine: PlayerStateMachine
var _lock_on: LockOnController
var _light_hitbox: HitboxComponent
var _heavy_hitbox: HitboxComponent
var _animation_controller: PlayerAnimationController

var _current_attack: AttackData
var _attack_elapsed: float = 0.0
var _chain_index: int = 0
var _buffered_action: StringName = &""
var _buffer_expire_at: float = 0.0
var _active_hitbox: HitboxComponent
var _hitbox_live: bool = false

func _ready() -> void:
	_owner_body = get_parent() as CharacterBody3D
	_state_machine = get_node(state_machine_path) as PlayerStateMachine
	_lock_on = get_node(lock_on_path) as LockOnController
	_light_hitbox = get_node(light_hitbox_path) as HitboxComponent
	_heavy_hitbox = get_node(heavy_hitbox_path) as HitboxComponent
	_animation_controller = get_node_or_null(animation_controller_path) as PlayerAnimationController
	_light_hitbox.hit_landed.connect(_on_hit_landed)
	_heavy_hitbox.hit_landed.connect(_on_hit_landed)

func _physics_process(delta: float) -> void:
	_capture_attack_input()
	if _current_attack == null:
		_try_start_buffered()
		return
	_attack_elapsed += delta
	var active_start := _current_attack.startup
	var active_end := active_start + _current_attack.active
	if not _hitbox_live and _attack_elapsed >= active_start and _attack_elapsed < active_end:
		_active_hitbox.begin_attack()
		_hitbox_live = true
	elif _hitbox_live and _attack_elapsed >= active_end:
		_active_hitbox.end_attack()
		_hitbox_live = false
	if _buffered_action != &"" and _attack_elapsed >= maxf(_current_attack.combo_window_start, combo_window):
		_continue_from_buffer()
		return
	var total_duration := _current_attack.startup + _current_attack.active + _current_attack.recovery
	if _attack_elapsed >= total_duration:
		_finish_attack()

func is_attacking() -> bool:
	return _current_attack != null

func can_cancel_to_dodge() -> bool:
	return _current_attack != null and _attack_elapsed >= maxf(attack_cancel_window, _current_attack.attack_cancel_window)

func cancel_attack() -> void:
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = null
	_active_hitbox = null
	_hitbox_live = false
	_chain_index = 0
	_buffered_action = &""

func _capture_attack_input() -> void:
	if Input.is_action_just_pressed("light_attack"):
		_buffer_action(&"light")
	elif Input.is_action_just_pressed("heavy_attack"):
		_buffer_action(&"heavy")

## O buffer usa tempo real; o hit stop não prolonga comandos antigos.
func _buffer_action(action: StringName) -> void:
	_buffered_action = action
	_buffer_expire_at = Time.get_ticks_msec() / 1000.0 + input_buffer_time

func _try_start_buffered() -> void:
	if _buffered_action == &"":
		return
	if Time.get_ticks_msec() / 1000.0 > _buffer_expire_at:
		_buffered_action = &""
		return
	if _state_machine.state in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return
	var action := _buffered_action
	_buffered_action = &""
	if not _owner_body.is_on_floor():
		_start_attack(AIR_LIGHT if action == &"light" else AIR_HEAVY, 0)
	elif action == &"light":
		_start_attack(LIGHT_1, 1)
	else:
		_start_attack(HEAVY, 0)

## O golpe pesado após o segundo leve vira launcher; demais rotas usam AttackData.
func _continue_from_buffer() -> void:
	if Time.get_ticks_msec() / 1000.0 > _buffer_expire_at:
		_buffered_action = &""
		return
	var action := _buffered_action
	_buffered_action = &""
	if not _owner_body.is_on_floor():
		_start_attack(AIR_LIGHT if action == &"light" else AIR_HEAVY, 0)
		return
	if action == &"heavy":
		if _chain_index == 2:
			_start_attack(LAUNCHER, 0)
		else:
			_start_attack(HEAVY, 0)
		return
	match _chain_index:
		1:
			_start_attack(LIGHT_2, 2)
		2:
			_start_attack(LIGHT_3, 3)
		3:
			_start_attack(LIGHT_4, 4)
		_:
			_finish_attack()

func _start_attack(data: AttackData, chain_index: int) -> void:
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = data
	_attack_elapsed = 0.0
	_chain_index = chain_index
	_hitbox_live = false
	_active_hitbox = _heavy_hitbox if data in [HEAVY, LAUNCHER, AIR_HEAVY] else _light_hitbox
	_active_hitbox.configure_from_attack(data)
	_state_machine.set_state(PlayerStateMachine.State.ATTACK if _owner_body.is_on_floor() else PlayerStateMachine.State.AIR_ATTACK)
	_face_attack_target()
	var forward := _owner_body.global_transform.basis.z.normalized()
	_owner_body.velocity += forward * data.forward_impulse
	if _animation_controller != null:
		_animation_controller.notify_attack_started(data)

func _finish_attack() -> void:
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = null
	_active_hitbox = null
	_hitbox_live = false
	_chain_index = 0
	if _owner_body.is_on_floor():
		_state_machine.set_state(PlayerStateMachine.State.IDLE)
	else:
		_state_machine.set_state(PlayerStateMachine.State.FALL)
	_try_start_buffered()

func _face_attack_target() -> void:
	var target := _lock_on.get_target()
	if target == null:
		return
	var direction := target.global_position - _owner_body.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_owner_body.rotation.y = atan2(direction.x, direction.z)

func _on_hit_landed(hurtbox: HurtboxComponent, hitbox: HitboxComponent) -> void:
	GameManager.register_hit(hitbox.attack_id, hitbox.style_points)
	if hitbox.attack_id == &"launcher":
		_owner_body.velocity.y = maxf(_owner_body.velocity.y, 6.6)
	GameManager.hit_stop(hitbox.hit_stop_duration)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent() != null and camera.get_parent().get_parent() is ThirdPersonCameraController:
		var rig := camera.get_parent().get_parent() as ThirdPersonCameraController
		rig.hit_impulse(0.07 if hitbox.launch_force <= 0.0 else 0.12, hitbox.damage >= 20.0)
	_spawn_hit_spark(hurtbox.global_position)

func _spawn_hit_spark(world_position: Vector3) -> void:
	var spark := HIT_SPARK.instantiate() as Node3D
	get_tree().current_scene.add_child(spark)
	spark.global_position = world_position
