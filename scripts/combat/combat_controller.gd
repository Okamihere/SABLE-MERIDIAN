class_name CombatController
extends Node

## Executa ataques definidos em AttackData e controla as janelas das hitboxes.
##
## Guarda entradas por um curto período (input buffer) e encadeia golpes conforme o combo atual.
## O sistema de combo permite:
## - 4 golpes leves encadeados (LIGHT_1 → LIGHT_2 → LIGHT_3 → LIGHT_4)
## - Golpe pesado (HEAVY) e launcher (LAUNCHER) após o segundo leve
## - Ataques aéreos (AIR_LIGHT, AIR_HEAVY)
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - As hitboxes (LightHitbox, HeavyHitbox) devem ser filhas do jogador
##   - O controlador gerencia automaticamente as janelas de acerto

## Tempo de buffer de input (em segundos).
@export var input_buffer_time: float = 0.27
## Janela de combo para encadear golpes (em segundos).
@export var combo_window: float = 0.12
## Janela para cancelar ataque com esquiva (em segundos).
@export var attack_cancel_window: float = 0.10
## Caminho para a hitbox de ataque leve.
@export var light_hitbox_path: NodePath = NodePath("../Hitboxes/LightHitbox")
## Caminho para a hitbox de ataque pesado.
@export var heavy_hitbox_path: NodePath = NodePath("../Hitboxes/HeavyHitbox")
## Caminho para a máquina de estados.
@export var state_machine_path: NodePath = NodePath("../StateMachine")
## Caminho para o controlador de lock-on.
@export var lock_on_path: NodePath = NodePath("../LockOnController")
## Caminho para o controlador de animação.
@export var animation_controller_path: NodePath = NodePath("../PlayerAnimationController")

## Recursos de ataque pré-carregados.
const LIGHT_1: AttackData = preload("res://resources/attacks/light_1.tres")
const LIGHT_2: AttackData = preload("res://resources/attacks/light_2.tres")
const LIGHT_3: AttackData = preload("res://resources/attacks/light_3.tres")
const LIGHT_4: AttackData = preload("res://resources/attacks/light_4.tres")
const HEAVY: AttackData = preload("res://resources/attacks/heavy.tres")
const LAUNCHER: AttackData = preload("res://resources/attacks/launcher.tres")
const AIR_LIGHT: AttackData = preload("res://resources/attacks/air_light.tres")
const AIR_HEAVY: AttackData = preload("res://resources/attacks/air_heavy.tres")
const HIT_SPARK: PackedScene = preload("res://scenes/effects/hit_spark.tscn")

## Referência ao corpo do jogador.
var _owner_body: CharacterBody3D
## Referência à máquina de estados.
var _state_machine: PlayerStateMachine
## Referência ao controlador de lock-on.
var _lock_on: LockOnController
## Referência à hitbox leve.
var _light_hitbox: HitboxComponent
## Referência à hitbox pesada.
var _heavy_hitbox: HitboxComponent
## Referência ao controlador de animação.
var _animation_controller: PlayerAnimationController

## Ataque atual em execução (null se não está atacando).
var _current_attack: AttackData
## Tempo decorrido do ataque atual (em segundos).
var _attack_elapsed: float = 0.0
## Índice do combo atual (0 = primeiro golpe).
var _chain_index: int = 0
## Ação bufferizada (light/heavy).
var _buffered_action: StringName = &""
## Tempo de expiração do buffer (em segundos).
var _buffer_expire_at: float = 0.0
## Hitbox ativa atual.
var _active_hitbox: HitboxComponent
## Indica se a hitbox está ativa (janela de acerto aberta).
var _hitbox_live: bool = false
var _last_unarmed_notice_ms: int = -5000

## Inicializa referências e conecta sinais.
func _ready() -> void:
	_owner_body = get_parent() as CharacterBody3D
	_state_machine = get_node(state_machine_path) as PlayerStateMachine
	_lock_on = get_node(lock_on_path) as LockOnController
	_light_hitbox = get_node(light_hitbox_path) as HitboxComponent
	_heavy_hitbox = get_node(heavy_hitbox_path) as HitboxComponent
	for hitbox in [_light_hitbox, _heavy_hitbox]:
		var shape_node := hitbox.get_node("CollisionShape3D") as CollisionShape3D
		shape_node.shape = shape_node.shape.duplicate()
	_animation_controller = get_node_or_null(animation_controller_path) as PlayerAnimationController
	_light_hitbox.hit_landed.connect(_on_hit_landed)
	_heavy_hitbox.hit_landed.connect(_on_hit_landed)

## Processa lógica de combate: input, buffer, janelas de hitbox e combo.
func _physics_process(delta: float) -> void:
	_capture_attack_input()
	if _current_attack == null:
		var player := _owner_body as PlayerController
		if player != null and player.equipment != null:
			player.equipment.commit_pending_weapon()
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

## Verifica se o jogador está atacando.
## @return true se está atacando, false caso contrário.
func is_attacking() -> bool:
	return _current_attack != null

## Permite que efeitos teçam variações de magia durante a cadeia atual.
func get_chain_index() -> int:
	return _chain_index

## Magias usam o mesmo feedback de acerto e estilo dos golpes físicos.
func register_magic_hit(hurtbox: HurtboxComponent, hitbox: HitboxComponent) -> void:
	_on_hit_landed(hurtbox, hitbox)

## Verifica se o ataque pode ser cancelado com esquiva.
## @return true se pode cancelar, false caso contrário.
func can_cancel_to_dodge() -> bool:
	if _current_attack == null:
		return false
	var player := _owner_body as PlayerController
	if player != null and player.equipment != null and player.equipment.mask != null:
		if player.equipment.mask.behavior.can_cancel_to_dodge(_current_attack, _attack_elapsed):
			return true
	return _attack_elapsed >= maxf(attack_cancel_window, _current_attack.attack_cancel_window)

## Cancela o ataque atual.
func cancel_attack() -> void:
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = null
	_active_hitbox = null
	_hitbox_live = false
	_chain_index = 0
	_buffered_action = &""

## Captura input de ataque e armazena no buffer.
func _capture_attack_input() -> void:
	if not GameManager.has_staff:
		if Input.is_action_just_pressed("light_attack") or Input.is_action_just_pressed("heavy_attack"):
			var now := Time.get_ticks_msec()
			if now - _last_unarmed_notice_ms > 2500:
				_last_unarmed_notice_ms = now
				var hud := _owner_body.get_parent().get_node_or_null("HUD")
				if hud != null and hud.has_method("show_notice"):
					hud.show_notice("ENCONTRE SEU CAJADO", "Ele espera no centro do pátio.", 2.2)
		return
	if Input.is_action_just_pressed("light_attack"):
		_buffer_action(&"light")
	elif Input.is_action_just_pressed("heavy_attack"):
		_buffer_action(&"heavy")

## Armazena uma ação no buffer de input.
## O buffer usa tempo real; o hit stop não prolonga comandos antigos.
func _buffer_action(action: StringName) -> void:
	_buffered_action = action
	_buffer_expire_at = Time.get_ticks_msec() / 1000.0 + input_buffer_time

## Tenta iniciar um ataque a partir do buffer.
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
	var weapon := _equipped_weapon()
	if not _owner_body.is_on_floor():
		_start_attack((weapon.air_light if action == &"light" else weapon.air_heavy) if weapon != null else (AIR_LIGHT if action == &"light" else AIR_HEAVY), 0)
	elif action == &"light":
		_start_attack(weapon.light_chain[0] if weapon != null else LIGHT_1, 1)
	else:
		_start_attack(weapon.heavy if weapon != null else HEAVY, 0)

## Continua o combo a partir do buffer.
## O golpe pesado após o segundo leve vira launcher; demais rotas usam AttackData.
func _continue_from_buffer() -> void:
	if Time.get_ticks_msec() / 1000.0 > _buffer_expire_at:
		_buffered_action = &""
		return
	if _state_machine.state in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		_buffered_action = &""
		return
	var action := _buffered_action
	_buffered_action = &""
	var player := _owner_body as PlayerController
	if player != null and player.equipment != null:
		player.equipment.commit_pending_weapon()
	var weapon := _equipped_weapon()
	if not _owner_body.is_on_floor():
		_start_attack((weapon.air_light if action == &"light" else weapon.air_heavy) if weapon != null else (AIR_LIGHT if action == &"light" else AIR_HEAVY), 0)
		return
	if action == &"heavy":
		if _chain_index == 2 and (weapon == null or weapon.launcher != null):
			_start_attack(weapon.launcher if weapon != null else LAUNCHER, 0)
		else:
			_start_attack(weapon.heavy if weapon != null else HEAVY, 0)
		return
	var chain: Array[AttackData] = weapon.light_chain if weapon != null else [LIGHT_1, LIGHT_2, LIGHT_3, LIGHT_4]
	if _chain_index < chain.size():
		_start_attack(chain[_chain_index], _chain_index + 1)
	elif player != null and player.equipment.mask != null and player.equipment.mask.behavior.continue_after_finisher(weapon):
		_start_attack(chain[0], 1)
	else:
		_finish_attack()

## Inicia um ataque.
## @param data Recurso AttackData com os parâmetros do golpe.
## @param chain_index Índice do combo (0 = primeiro golpe).
func _start_attack(data: AttackData, chain_index: int) -> void:
	if not GameManager.has_staff or data == null:
		return
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = data
	_attack_elapsed = 0.0
	_chain_index = chain_index
	_hitbox_live = false
	var weapon := _equipped_weapon()
	_active_hitbox = _heavy_hitbox if (weapon != null and weapon.is_heavy_attack(data)) or data in [HEAVY, LAUNCHER, AIR_HEAVY] else _light_hitbox
	if weapon != null:
		_configure_hitbox_geometry(weapon)
	_active_hitbox.configure_from_attack(data)
	_state_machine.set_state(PlayerStateMachine.State.ATTACK if _owner_body.is_on_floor() else PlayerStateMachine.State.AIR_ATTACK)
	if weapon != null and weapon.behavior != null:
		weapon.behavior.on_attack_started(_owner_body as PlayerController, data)
	_face_attack_target()
	var forward := _owner_body.global_transform.basis.z.normalized()
	_owner_body.velocity += forward * data.forward_impulse
	if _animation_controller != null:
		_animation_controller.notify_attack_started(data)

## Finaliza o ataque atual.
func _finish_attack() -> void:
	if _active_hitbox != null:
		_active_hitbox.end_attack()
	_current_attack = null
	_active_hitbox = null
	_hitbox_live = false
	_chain_index = 0
	var player := _owner_body as PlayerController
	if player != null and player.equipment != null:
		player.equipment.commit_pending_weapon()
	if _owner_body.is_on_floor():
		_state_machine.set_state(PlayerStateMachine.State.IDLE)
	else:
		_state_machine.set_state(PlayerStateMachine.State.FALL)
	_try_start_buffered()

func _equipped_weapon() -> WeaponData:
	var player := _owner_body as PlayerController
	return player.equipment.weapon if player != null and player.equipment != null else null

func _configure_hitbox_geometry(weapon: WeaponData) -> void:
	var light_shape := _light_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	var heavy_shape := _heavy_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(light_shape.shape as BoxShape3D).size = weapon.light_hitbox_size
	(heavy_shape.shape as BoxShape3D).size = weapon.heavy_hitbox_size
	_light_hitbox.position = weapon.light_hitbox_offset
	_heavy_hitbox.position = weapon.heavy_hitbox_offset

## Rotaciona o jogador em direção ao alvo de lock-on.
func _face_attack_target() -> void:
	var target := _lock_on.get_target()
	if target == null:
		return
	var direction := target.global_position - _owner_body.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_owner_body.rotation.y = atan2(direction.x, direction.z)

## Chamado quando um golpe acerta uma hurtbox.
## Aplica efeitos: estilo, hit stop, câmera e partícula de impacto.
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

## Spawna um efeito de impacto na posição especificada.
## @param world_position Posição 3D onde o efeito será criado.
func _spawn_hit_spark(world_position: Vector3) -> void:
	var spark := HIT_SPARK.instantiate() as Node3D
	get_tree().current_scene.add_child(spark)
	spark.global_position = world_position
