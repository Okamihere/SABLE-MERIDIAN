class_name ThirdPersonCameraController
extends Node3D

## Câmera em terceira pessoa com órbita, suavização e enquadramento do lock-on.
## O SpringArm3D evita atravessar o cenário; impactos aplicam tremor e variação de FOV.

@export var player_path: NodePath = NodePath("../Player")
@export var mouse_sensitivity: float = 0.0028
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 35.0
@export var follow_height: float = 1.35
@export var camera_lag: float = 12.0
@export var rotation_lag: float = 10.0
@export var base_distance: float = 6.4
@export var lock_distance_bonus: float = 2.6
@export var base_fov: float = 72.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _player: Node3D
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-12.0)
var _shake_strength: float = 0.0
var _shake_decay: float = 8.0
var _fov_tween: Tween

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	spring_arm.spring_length = base_distance
	camera.fov = base_fov
	camera.add_to_group("game_camera")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_player):
		global_position = _player.global_position + Vector3.UP * follow_height
		yaw_from_player()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var follow_target := _player.global_position + Vector3.UP * follow_height
	global_position = global_position.lerp(follow_target, 1.0 - exp(-camera_lag * delta))
	var lock_target: Node3D = null
	if _player.has_method("get_lock_target"):
		lock_target = _player.call("get_lock_target") as Node3D
	if is_instance_valid(lock_target):
		var direction := lock_target.global_position - _player.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.01:
			var desired_yaw := atan2(-direction.x, -direction.z)
			_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-rotation_lag * delta))
		var target_distance := clampf(base_distance + _player.global_position.distance_to(lock_target.global_position) * 0.12, base_distance, base_distance + lock_distance_bonus)
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_distance, 1.0 - exp(-6.0 * delta))
	else:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, base_distance, 1.0 - exp(-6.0 * delta))
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch
	_update_shake(delta)


func snap_to_player() -> void:
	if not is_instance_valid(_player):
		return
	global_position = _player.global_position + Vector3.UP * follow_height
	camera.h_offset = 0.0
	camera.v_offset = 0.0

func yaw_from_player() -> void:
	if is_instance_valid(_player):
		_yaw = _player.rotation.y + PI

func shake(strength: float = 0.10, duration: float = 0.12) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_decay = maxf(1.0, strength / maxf(duration, 0.01))

func hit_impulse(strength: float, heavy: bool = false) -> void:
	shake(strength, 0.10 if not heavy else 0.16)
	kick_fov(2.0 if not heavy else 4.0, 0.12 if not heavy else 0.18)

func kick_fov(amount: float, duration: float) -> void:
	if is_instance_valid(_fov_tween):
		_fov_tween.kill()
	camera.fov = base_fov
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", base_fov + amount, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fov_tween.tween_property(camera, "fov", base_fov, duration * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _update_shake(delta: float) -> void:
	if _shake_strength <= 0.001:
		camera.h_offset = lerpf(camera.h_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		camera.v_offset = lerpf(camera.v_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	camera.h_offset = randf_range(-_shake_strength, _shake_strength)
	camera.v_offset = randf_range(-_shake_strength, _shake_strength)
	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
