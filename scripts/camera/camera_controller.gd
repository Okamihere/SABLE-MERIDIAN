class_name ThirdPersonCameraController
extends Node3D

## Câmera em terceira pessoa com órbita, suavização e enquadramento do lock-on.
##
## O SpringArm3D evita atravessar o cenário; impactos aplicam tremor e variação de FOV.
## A câmera segue o jogador com suavização exponencial e ajusta a distância
## automaticamente quando há um alvo de lock-on.
##
## Uso típico:
##   - Adicionar como filho da cena (não do jogador)
##   - Configurar [member player_path] para apontar para o jogador
##   - A câmera captura o mouse automaticamente

## Caminho para o jogador.
@export var player_path: NodePath = NodePath("../Player")
## Sensibilidade do mouse.
@export var mouse_sensitivity: float = 0.0028
## Pitch mínimo em graus.
@export var min_pitch_degrees: float = -55.0
## Pitch máximo em graus.
@export var max_pitch_degrees: float = 35.0
## Altura da câmera acima do jogador.
@export var follow_height: float = 1.35
## Velocidade de suavização do seguimento.
@export var camera_lag: float = 12.0
## Velocidade de suavização da rotação.
@export var rotation_lag: float = 10.0
## Distância base da câmera.
@export var base_distance: float = 6.4
## Distância desejada ajustável com a roda, antes da colisão do SpringArm.
@export var min_distance: float = 3.2
@export var max_distance: float = 9.2
@export var zoom_step: float = 0.75
@export var zoom_smoothing: float = 9.0
## Bônus de distância máxima com lock-on.
@export var lock_distance_bonus: float = 2.6
## FOV base da câmera.
@export var base_fov: float = 72.0

## Referência ao SpringArm3D.
@onready var spring_arm: SpringArm3D = $SpringArm3D
## Referência à Camera3D.
@onready var camera: Camera3D = $SpringArm3D/Camera3D

## Referência ao jogador.
var _player: Node3D
## Yaw atual da câmera.
var _yaw: float = 0.0
## Pitch atual da câmera.
var _pitch: float = deg_to_rad(-12.0)
## Força do tremor de câmera.
var _shake_strength: float = 0.0
## Velocidade de decaimento do tremor.
var _shake_decay: float = 8.0
## Tween de FOV atual.
var _fov_tween: Tween
var _zoom_distance: float = 6.4

## Inicializa a câmera: configura SpringArm, captura mouse e posiciona.
func _ready() -> void:
	mouse_sensitivity = PauseMenu.camera_sensitivity
	_player = get_node_or_null(player_path) as Node3D
	_zoom_distance = clampf(base_distance, min_distance, max_distance)
	spring_arm.spring_length = _zoom_distance
	camera.fov = base_fov
	camera.add_to_group("game_camera")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_player):
		global_position = _player.global_position + Vector3.UP * follow_height
		yaw_from_player()

## Processa input de mouse para órbita da câmera.
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				adjust_zoom(-1)
				get_viewport().set_input_as_handled()
				return
			if button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				adjust_zoom(1)
				get_viewport().set_input_as_handled()
				return
		if button_event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Alteração incremental; o SpringArm interpola até este alvo e continua colidindo.
func adjust_zoom(steps: int) -> void:
	_zoom_distance = clampf(_zoom_distance + float(steps) * zoom_step, min_distance, max_distance)

## Processa seguimento suavizado do jogador e ajuste de lock-on.
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
		var target_distance := clampf(_zoom_distance + minf(lock_distance_bonus, _player.global_position.distance_to(lock_target.global_position) * 0.12), min_distance, max_distance)
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_distance, 1.0 - exp(-zoom_smoothing * delta))
	else:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _zoom_distance, 1.0 - exp(-zoom_smoothing * delta))
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch
	_update_shake(delta)

## Reposiciona a câmera imediatamente para a posição do jogador.
func snap_to_player() -> void:
	if not is_instance_valid(_player):
		return
	global_position = _player.global_position + Vector3.UP * follow_height
	camera.h_offset = 0.0
	camera.v_offset = 0.0

## Define o yaw da câmera baseado na rotação do jogador.
func yaw_from_player() -> void:
	if is_instance_valid(_player):
		_yaw = _player.rotation.y + PI

## Aplica tremor de câmera.
## @param strength Força do tremor.
## @param duration Duração do tremor (em segundos).
func shake(strength: float = 0.10, duration: float = 0.12) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_decay = maxf(1.0, strength / maxf(duration, 0.01))

## Aplica impacto de câmera (tremor + kick de FOV).
## @param strength Força do impacto.
## @param heavy Indica se é um golpe pesado.
func hit_impulse(strength: float, heavy: bool = false) -> void:
	shake(strength, 0.10 if not heavy else 0.16)
	kick_fov(2.0 if not heavy else 4.0, 0.12 if not heavy else 0.18)

## Aplica kick de FOV com tween.
## @param amount Quantidade de FOV a adicionar.
## @param duration Duração do efeito (em segundos).
func kick_fov(amount: float, duration: float) -> void:
	if is_instance_valid(_fov_tween):
		_fov_tween.kill()
	camera.fov = base_fov
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", base_fov + amount, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fov_tween.tween_property(camera, "fov", base_fov, duration * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## Atualiza o tremor de câmera.
func _update_shake(delta: float) -> void:
	if _shake_strength <= 0.001:
		camera.h_offset = lerpf(camera.h_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		camera.v_offset = lerpf(camera.v_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	camera.h_offset = randf_range(-_shake_strength, _shake_strength)
	camera.v_offset = randf_range(-_shake_strength, _shake_strength)
	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
