class_name PlayerAnimationController
extends Node

## Anima o Skeleton3D por poses procedurais, sem AnimationTree.
##
## Lê o estado do jogador e recebe os tempos reais dos golpes e esquivas.
## A animação é feita diretamente nos ossos do esqueleto usando interpolação.
## Não usa AnimationTree nem AnimationPlayer - tudo é procedural.
##
## Ossos necessários no esqueleto:
## - Hips (raiz)
## - Spine (filho de Hips)
## - Head (filho de Spine)
## - LeftArm, RightArm (filhos de Hips)
## - LeftLeg, RightLeg (filhos de Hips)
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Configurar [member skeleton_path] e [member state_machine_path]
##   - Chamar métodos notify_* quando eventos ocorrerem

## Caminho para o Skeleton3D.
@export var skeleton_path: NodePath = NodePath("../Skeleton3D")
## Caminho para a máquina de estados.
@export var state_machine_path: NodePath = NodePath("../StateMachine")
## Velocidade de interpolação dos blends de locomoção.
@export var locomotion_blend_speed: float = 11.0
## Ângulo dos braços na postura neutra; o GLB foi modelado em T-pose.
@export_range(0.0, 1.4, 0.05) var relaxed_arm_angle: float = 1.05

## Referência ao Skeleton3D.
var _skeleton: Skeleton3D
var _staff_visual: Node3D
var _staff_trail: GPUParticles3D
## Referência à máquina de estados.
var _state_machine: PlayerStateMachine

## Estado de animação procedural.
var _time: float = 0.0
var _movement_blend: float = 0.0
var _airborne_blend: float = 0.0
var _attack_blend: float = 0.0
var _dodge_blend: float = 0.0
var _hit_blend: float = 0.0
var _dead_blend: float = 0.0

## Referências dos ossos para animação procedural.
var _hips_bone: int = -1
var _spine_bone: int = -1
var _head_bone: int = -1
var _left_arm_bone: int = -1
var _right_arm_bone: int = -1
var _left_leg_bone: int = -1
var _right_leg_bone: int = -1

## Estado de animação de ataque.
var _attack_time: float = 0.0
var _attack_duration: float = 0.0
var _attack_type: StringName = &""
var _reverse_sweep := false

## Estado de animação de esquiva.
var _dodge_time: float = 0.0
var _dodge_duration: float = 0.34

## Estado de animação de dano.
var _hit_time: float = 0.0
var _hit_duration: float = 0.3

## Estado de animação de morte.
var _dead_time: float = 0.0

## Inicializa o controlador: cacheia ossos e conecta sinais.
func _ready() -> void:
	_skeleton = get_node(skeleton_path) as Skeleton3D
	_staff_visual = get_node_or_null("../ModelRoot/Jester/world/Skeleton3D/StaffAttachment/MageStaff") as Node3D
	if _staff_visual != null:
		_staff_trail = _staff_visual.get_node_or_null("Crystal/AttackTrail") as GPUParticles3D
	_state_machine = get_node(state_machine_path) as PlayerStateMachine
	_cache_bones()
	_connect_signals()
	_update_procedural_animation()

## Cacheia os índices dos ossos para acesso rápido.
func _cache_bones() -> void:
	if _skeleton == null:
		return
	_hips_bone = _skeleton.find_bone(&"Hips")
	_spine_bone = _skeleton.find_bone(&"Spine")
	_head_bone = _skeleton.find_bone(&"Head")
	_left_arm_bone = _skeleton.find_bone(&"LeftArm")
	_right_arm_bone = _skeleton.find_bone(&"RightArm")
	_left_leg_bone = _skeleton.find_bone(&"LeftLeg")
	_right_leg_bone = _skeleton.find_bone(&"RightLeg")

## Conecta sinais da máquina de estados.
func _connect_signals() -> void:
	if _state_machine != null:
		_state_machine.state_changed.connect(_on_state_changed)

## Processa animação procedural a cada frame.
func _process(delta: float) -> void:
	_time += delta
	_attack_time += delta
	_dodge_time += delta
	_hit_time += delta
	_dead_time += delta
	_update_blends(delta)
	_update_procedural_animation()
	if _staff_trail != null:
		var striking := _state_machine.state in [PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK] and _attack_duration > 0.0 and _attack_time / _attack_duration > 0.16 and _attack_time / _attack_duration < 0.6
		_staff_trail.emitting = striking and _staff_visual.visible

## Atualiza os valores de blend baseados no estado atual.
func _update_blends(delta: float) -> void:
	if _state_machine == null:
		return
	var target_movement := 0.0
	var target_airborne := 0.0
	var target_attack := 0.0
	var target_dodge := 0.0
	var target_hit := 0.0
	var target_dead := 0.0
	match _state_machine.state:
		PlayerStateMachine.State.IDLE:
			target_movement = 0.0
		PlayerStateMachine.State.MOVE:
			target_movement = 1.0
		PlayerStateMachine.State.JUMP:
			target_airborne = 1.0
		PlayerStateMachine.State.FALL:
			target_airborne = 1.0
		PlayerStateMachine.State.DODGE:
			target_dodge = 1.0
		PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK:
			target_attack = 1.0
			var body := get_parent() as PlayerController
			if body != null:
				target_movement = clampf(Vector2(body.velocity.x, body.velocity.z).length() / body.move_speed, 0.0, 1.0)
		PlayerStateMachine.State.HIT:
			target_hit = 1.0
		PlayerStateMachine.State.DEAD:
			target_dead = 1.0
	_movement_blend = lerp(_movement_blend, target_movement, clampf(locomotion_blend_speed * delta, 0.0, 1.0))
	_airborne_blend = lerp(_airborne_blend, target_airborne, clampf(locomotion_blend_speed * delta, 0.0, 1.0))
	_attack_blend = lerp(_attack_blend, target_attack, clampf(18.0 * delta, 0.0, 1.0))
	_dodge_blend = lerp(_dodge_blend, target_dodge, clampf(18.0 * delta, 0.0, 1.0))
	_hit_blend = lerp(_hit_blend, target_hit, clampf(16.0 * delta, 0.0, 1.0))
	_dead_blend = lerp(_dead_blend, target_dead, clampf(6.0 * delta, 0.0, 1.0))

## Aplica animação procedural baseada nos blends atuais.
func _update_procedural_animation() -> void:
	if _skeleton == null:
		return
	_reset_bones()
	if _movement_blend > 0.01:
		_apply_locomotion()
	if _airborne_blend > 0.01:
		_apply_airborne()
	if _attack_blend > 0.01:
		_apply_attack()
	if _dodge_blend > 0.01:
		_apply_dodge()
	if _hit_blend > 0.01:
		_apply_hit()
	if _dead_blend > 0.01:
		_apply_dead()

## Prepara a postura neutra; a pose de repouso importada é uma T-pose.
func _reset_bones() -> void:
	if is_instance_valid(_staff_visual):
		_staff_visual.rotation = Vector3(0, 0, deg_to_rad(60.0))
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3(0.0, 0.008 * sin(_time * 2.2), 0.0))
		_skeleton.set_bone_pose_rotation(_hips_bone, Quaternion.IDENTITY)
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(0.012 * sin(_time * 2.2), 0.0, 0.0)))
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.IDENTITY)
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(0.025 * sin(_time * 2.2), 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-0.025 * sin(_time * 2.2), 0.0, 0.0)))
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.IDENTITY)
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.IDENTITY)

## Combina a postura baixa dos braços com os movimentos de cada ação.
func _set_arm_rotation(bone: int, motion: Quaternion) -> void:
	var angle := relaxed_arm_angle if bone == _left_arm_bone else -relaxed_arm_angle
	_skeleton.set_bone_pose_rotation(bone, Quaternion.from_euler(Vector3(0.0, 0.0, angle)) * motion)

## Aplica animação de locomoção (ciclo de caminhada).
func _apply_locomotion() -> void:
	var walk_cycle := _time * 8.0
	var swing := sin(walk_cycle) * 0.4 * _movement_blend
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(swing, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(-swing, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-swing * 0.6, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(swing * 0.6, 0.0, 0.0)))
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(0.05 * _movement_blend, 0.0, 0.0)))

## Aplica animação aérea (salto/queda).
func _apply_airborne() -> void:
	var t := clampf(_airborne_blend, 0.0, 1.0)
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(-0.3 * t, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(0.2 * t, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-0.4 * t, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-0.4 * t, 0.0, 0.0)))
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-0.1 * t, 0.0, 0.0)))

## Aplica animação de ataque (windup → strike → recover).
func _apply_attack() -> void:
	if _attack_duration <= 0.0:
		return
	var t := clampf(_attack_time / _attack_duration, 0.0, 1.0)
	var windup := 0.25
	var strike := 0.45
	var attack_angle: float
	if t < windup:
		attack_angle = -1.2 * (t / windup)
	elif t < strike:
		attack_angle = -1.2 + 2.4 * ((t - windup) / (strike - windup))
	else:
		attack_angle = 1.2 * (1.0 - (t - strike) / (1.0 - strike))
	var heavy := _attack_type == &"heavy" or _attack_type == &"launcher"
	var multiplier := 1.3 if heavy else 1.0
	var sweep_direction := -1.0 if _reverse_sweep else 1.0
	var sweep := sweep_direction * sin(t * PI) * (0.65 if heavy else 0.43)
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(attack_angle * multiplier * 0.82, sweep, sweep * 0.55)))
	if is_instance_valid(_staff_visual):
		_staff_visual.rotation.z = deg_to_rad(60.0) + sweep_direction * sin(t * PI) * (0.7 if heavy else 0.48)
		_staff_visual.rotation.x = -sin(t * PI) * (0.28 if heavy else 0.18)
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(0.0, -sweep * 0.42, 0.0)))

## Aplica animação de esquiva (rolamento).
func _apply_dodge() -> void:
	var t := clampf(_dodge_time / _dodge_duration, 0.0, 1.0)
	var roll := sin(t * PI) * 0.5
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(roll, 0.0, 0.0)))
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3(0.0, -0.2 * sin(t * PI), 0.0))
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-0.5 * sin(t * PI), 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-0.5 * sin(t * PI), 0.0, 0.0)))

## Aplica animação de dano (flinch).
func _apply_hit() -> void:
	var t := clampf(_hit_time / _hit_duration, 0.0, 1.0)
	var flinch := sin(t * PI) * 0.4
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-flinch, 0.0, 0.0)))
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.from_euler(Vector3(-flinch * 0.5, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-flinch * 0.3, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-flinch * 0.3, 0.0, 0.0)))

## Aplica animação de morte (queda).
func _apply_dead() -> void:
	var t := clampf(_dead_time / 1.0, 0.0, 1.0)
	var ease := 1.0 - (1.0 - t) * (1.0 - t)
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-ease * 1.2, 0.0, 0.0)))
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.from_euler(Vector3(-ease * 0.4, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_set_arm_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-ease * 0.8, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_set_arm_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-ease * 0.8, 0.0, 0.0)))
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(ease * 0.3, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(ease * 0.3, 0.0, 0.0)))
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3(0.0, -ease * 0.5, 0.0))

## Chamado quando o estado do jogador muda.
func _on_state_changed(_previous: PlayerStateMachine.State, current: PlayerStateMachine.State) -> void:
	match current:
		PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK:
			_attack_time = 0.0
			_attack_duration = 0.4
			_attack_type = &"light"
		PlayerStateMachine.State.DODGE:
			_dodge_time = 0.0
		PlayerStateMachine.State.HIT:
			_hit_time = 0.0
		PlayerStateMachine.State.DEAD:
			_dead_time = 0.0

## Notifica o início de um ataque.
## @param data Recurso AttackData com os parâmetros do golpe.
func notify_attack_started(attack_data: AttackData) -> void:
	_attack_time = 0.0
	_attack_duration = attack_data.startup + attack_data.active + attack_data.recovery
	_attack_type = StringName(attack_data.animation_style) if attack_data.animation_style != "auto" else (&"heavy" if attack_data.damage >= 20.0 or attack_data.launch_force > 4.0 else &"light")
	_reverse_sweep = attack_data.reverse_sweep or attack_data.attack_id in [&"light_2", &"light_4", &"air_heavy"]

## Notifica o início de uma esquiva.
## @param duration Duração da esquiva (em segundos).
func notify_dodge_started(duration: float) -> void:
	_dodge_time = 0.0
	_dodge_duration = duration

## Notifica o início de um hit stun.
## @param duration Duração do hit stun (em segundos).
func notify_hit_started(duration: float) -> void:
	_hit_time = 0.0
	_hit_duration = duration

## Notifica a morte do jogador.
func notify_dead() -> void:
	_dead_time = 0.0
