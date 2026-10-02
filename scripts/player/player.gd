class_name PlayerController
extends CharacterBody3D

## Controla movimento, salto, esquiva, dano e recuperação de quedas.
##
## Combate, seleção de alvo e poses ficam em componentes separados:
## - [CombatController]: execução de ataques e janelas de hitbox
## - [LockOnController]: seleção e troca de alvos
## - [PlayerAnimationController]: animação procedural do esqueleto
## - [WallMovement]: agarre e salto em paredes
## - [HealthComponent]: vida e sinais de dano/morte
## - [ManaComponent]: reserva de mana para habilidades futuras
## - [SpellManager]: gerenciamento de magias, cooldowns e custo de mana
##
## O jogador usa uma máquina de estados ([PlayerStateMachine]) para coordenar
## todas as ações. Movimento é relativo à câmera e a esquiva concede invulnerabilidade
## temporária com janela de "perfect dodge".

## Velocidade de movimento padrão.
@export var move_speed: float = 6.5
## Velocidade de corrida (ao segurar movimento por 0.34s sem lock-on).
@export var run_speed: float = 9.5
## Aceleração do movimento.
@export var acceleration: float = 34.0
## Desaceleração do movimento.
@export var deceleration: float = 40.0
## Velocidade de rotação do personagem.
@export var rotation_speed: float = 14.0
## Velocidade vertical do salto.
@export var jump_velocity: float = 9.2
## Controle de movimento no ar (0.0 a 1.0).
@export var air_control: float = 0.50
## Força da gravidade.
@export var gravity: float = 30.0
## Acelera a descida sem encurtar o impulso inicial do salto.
@export var fall_gravity_multiplier: float = 1.25
@export var max_fall_speed: float = 28.0
## Velocidade da esquiva.
@export var dodge_speed: float = 15.5
## Duração da esquiva (em segundos).
@export var dodge_duration: float = 0.29
## Tempo de recarga da esquiva (em segundos).
@export var dodge_cooldown: float = 0.36
## Guarda um comando de esquiva dado pouco antes do fim de um golpe.
@export var dodge_input_buffer: float = 0.14
## Início da janela de invulnerabilidade na esquiva (em segundos).
@export var invulnerability_start: float = 0.04
## Fim da janela de invulnerabilidade na esquiva (em segundos).
@export var invulnerability_end: float = 0.22

@export_category("Fall Recovery")
## Limite de queda (Y mínimo antes de respawn).
@export var fall_limit_y: float = -18.0
## Altura do respawn acima da posição segura.
@export var respawn_height_offset: float = 0.65
## Tempo mínimo no chão para registrar posição segura (em segundos).
@export var safe_position_delay: float = 0.30

## Referência à máquina de estados do jogador.
@onready var state_machine: PlayerStateMachine = $StateMachine
## Referência ao controlador de combate.
@onready var combat: CombatController = $CombatController
## Referência ao controlador de lock-on.
@onready var lock_on: LockOnController = $LockOnController
## Referência ao componente de vida.
@onready var health: HealthComponent = $HealthComponent
## Referência ao controlador de animação.
@onready var animation_controller: PlayerAnimationController = get_node_or_null("PlayerAnimationController") as PlayerAnimationController

## Componente de mana (criado dinamicamente).
var mana: ManaComponent
## Componente de movimento em paredes (criado dinamicamente).
var wall_movement: WallMovement
## Gerenciador de magias (criado dinamicamente).
var spell_manager: SpellManager
## Armas, máscaras e relíquias equipadas.
var equipment: EquipmentComponent
var _skill_guard_until := 0.0
## Magias disponíveis para conjuração.
@export var spells: Array[SpellResource] = []
## Para cenas que começam depois da obtenção do cajado, como a cidade.
@export var starts_with_staff: bool = false
@onready var staff_attachment: BoneAttachment3D = get_node_or_null("ModelRoot/Jester/world/Skeleton3D/StaffAttachment") as BoneAttachment3D
@onready var dagger_right: BoneAttachment3D = get_node_or_null("ModelRoot/Jester/world/Skeleton3D/DaggerRight") as BoneAttachment3D
@onready var dagger_left: BoneAttachment3D = get_node_or_null("ModelRoot/Jester/world/Skeleton3D/DaggerLeft") as BoneAttachment3D
@onready var weapon_display: Node3D = get_node_or_null("WeaponDisplay") as Node3D
@onready var laugh_mask_visual: BoneAttachment3D = get_node_or_null("ModelRoot/Jester/world/Skeleton3D/LaughMask") as BoneAttachment3D
## Caminho para o controlador de câmera (evita dependência de hierarquia frágil).
@export var camera_controller_path: NodePath

## Tempo decorrido da esquiva atual (em segundos).
var _dodge_elapsed: float = 0.0
## Referência ao controlador de câmera (via NodePath exportado).
var _camera_controller: ThirdPersonCameraController
## Tempo restante de recarga da esquiva (em segundos).
var _dodge_cooldown_left: float = 0.0
var _dodge_buffer_until: float = 0.0
## Direção da esquiva atual.
var _dodge_direction: Vector3 = Vector3.ZERO
## Indica se a esquiva aérea já foi usada.
var _air_dodge_used: bool = false
## Tempo restante de hit stun (em segundos).
var _hit_stun_left: float = 0.0
## Indica se o jogador está morto.
var _dead: bool = false
## Indica se o perfect dodge já foi consumido nesta esquiva.
var _perfect_dodge_consumed: bool = false
## Tempo segurando movimento (para ativar corrida).
var _move_hold_time: float = 0.0
## Última posição segura registrada.
var _last_safe_position: Vector3
## Tempo acumulado no chão em estado seguro (em segundos).
var _safe_grounded_time: float = 0.0

## Inicializa componentes dinâmicos e conecta sinais.
func _ready() -> void:
	mana = ManaComponent.new()
	mana.name = "ManaComponent"
	add_child(mana)
	wall_movement = WallMovement.new()
	wall_movement.name = "WallMovement"
	add_child(wall_movement)
	spell_manager = SpellManager.new()
	spell_manager.name = "SpellManager"
	add_child(spell_manager)
	equipment = EquipmentComponent.new()
	equipment.name = "Equipment"
	add_child(equipment)
	equipment.weapon_changed.connect(_on_weapon_changed)
	equipment.mask_changed.connect(_on_mask_changed)
	# Resolve referência ao controlador de câmera via NodePath (fallback para busca na cena).
	if camera_controller_path:
		_camera_controller = get_node_or_null(camera_controller_path) as ThirdPersonCameraController
	if not is_instance_valid(_camera_controller):
		var cam := get_viewport().get_camera_3d()
		if cam != null and cam.get_parent() != null:
			_camera_controller = cam.get_parent().get_parent() as ThirdPersonCameraController
	_last_safe_position = global_position
	GameManager.register_player(self)
	if starts_with_staff or GameManager.has_staff:
		equip_staff()
	health.died.connect(_on_died)

func equip_staff() -> void:
	GameManager.has_staff = true
	equipment.restore_from_manager()

func _on_weapon_changed(weapon: WeaponData) -> void:
	if is_instance_valid(weapon_display):
		weapon_display.show_weapon(weapon.weapon_id)
	if is_instance_valid(staff_attachment):
		staff_attachment.visible = weapon.weapon_id == &"staff"
	if is_instance_valid(dagger_right):
		dagger_right.visible = weapon.weapon_id == &"card_daggers"
	if is_instance_valid(dagger_left):
		dagger_left.visible = weapon.weapon_id == &"card_daggers"

func _on_mask_changed(mask: MaskData) -> void:
	if is_instance_valid(laugh_mask_visual):
		laugh_mask_visual.visible = mask != null and mask.mask_id == &"laugh"

func _handle_equipment_input() -> void:
	if NpcInteraction.is_dialogue_active():
		return
	if equipment.weapon == null:
		return
	var requested: StringName = &""
	if Input.is_action_just_pressed("weapon_staff"):
		requested = &"staff"
	elif Input.is_action_just_pressed("weapon_daggers"):
		requested = &"card_daggers"
	if requested != &"" and equipment.request_weapon(requested):
		_show_equipment_notice("CAJADO" if requested == &"staff" else "ADAGAS DE CARTAS", "O próximo compasso muda de forma." if equipment.has_pending_weapon() else "Uma nova forma entra em cena.")
	if Input.is_action_just_pressed("mask_laugh"):
		equipment.toggle_laugh_mask()
		_show_equipment_notice("MÁSCARA DO RISO" if equipment.mask != null else "MÁSCARA RETIRADA", "A cadeia pode recomeçar." if equipment.mask != null else "O ritmo volta ao normal.")

func _show_equipment_notice(title: String, body: String) -> void:
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(title, body, 1.7)

## Processa física do jogador: movimento, esquiva, dano e gravidade.
func _physics_process(delta: float) -> void:
	wall_movement.gripping = false
	if not _dead:
		_track_safe_position(delta)
		if global_position.y <= fall_limit_y:
			_respawn_from_fall()
			return
	if _dead:
		_apply_gravity(delta)
		move_and_slide()
		return
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	if not is_on_floor():
		_apply_gravity(delta)
	else:
		_air_dodge_used = false
	if _hit_stun_left <= 0.0 and not _dead and not NpcInteraction.is_dialogue_active() and Input.is_action_just_pressed("lock_on"):
		lock_on.toggle_lock()
	if _hit_stun_left > 0.0:
		_hit_stun_left -= delta
		if _hit_stun_left <= 0.0:
			state_machine.set_state(PlayerStateMachine.State.IDLE if is_on_floor() else PlayerStateMachine.State.FALL)
		move_and_slide()
		return
	_handle_equipment_input()
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer_until = Time.get_ticks_msec() / 1000.0 + dodge_input_buffer
	if _dodge_buffer_until > Time.get_ticks_msec() / 1000.0 and _can_start_dodge():
		_dodge_buffer_until = 0.0
		_start_dodge()
	if state_machine.state == PlayerStateMachine.State.DODGE:
		_update_dodge(delta)
		move_and_slide()
		return
	if state_machine.allows_locomotion():
		_update_locomotion(delta)
	_handle_spell_input()
	var wall_direction := _camera_relative_direction(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	wall_movement.update_motion(self, wall_direction, delta, state_machine.allows_locomotion())
	move_and_slide()
	_update_air_state()

func _apply_gravity(delta: float) -> void:
	var scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity.y = maxf(velocity.y - gravity * scale * delta, -max_fall_speed)

## Processa input de magias: seleção e conjuração.
## O primeiro espaço do repertório está ativo; outros efeitos entram sem alterar o input base.
func _handle_spell_input() -> void:
	if state_machine.state in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return
	if NpcInteraction.is_dialogue_active():
		return
	if equipment.weapon == null:
		return
	for index in 3:
		var action: StringName = [&"spell_q", &"spell_e", &"spell_r"][index]
		if Input.is_action_just_pressed(action) and equipment.weapon.skills.size() > index:
			_cast_spell(equipment.weapon.skills[index])
			return

## Conjura uma magia selecionada.
## @param spell A magia a ser conjurada.
func _cast_spell(spell: SpellResource) -> void:
	if spell == null or spell_manager == null:
		return
	if combat.is_attacking() and not spell.weave_during_attack:
		return
	spell_manager.cast_spell(spell, self)

## Rastreia posições seguras no chão para respawn.
## Só grava chão estável; evita reaparecer em posições de ataque ou queda.
func _track_safe_position(delta: float) -> void:
	if is_on_floor() and state_machine.state not in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		_safe_grounded_time += delta
		if _safe_grounded_time >= safe_position_delay:
			_last_safe_position = global_position
	else:
		_safe_grounded_time = 0.0

## Respawna o jogador após cair abaixo do limite.
## Cancela ações e reposiciona a câmera junto do jogador, sem recarregar o mapa.
func _respawn_from_fall() -> void:
	wall_movement.reset()
	combat.cancel_attack()
	lock_on.clear_target()
	velocity = Vector3.ZERO
	_dodge_elapsed = 0.0
	_dodge_cooldown_left = 0.0
	_dodge_buffer_until = 0.0
	_hit_stun_left = 0.0
	_air_dodge_used = false
	_perfect_dodge_consumed = false
	_move_hold_time = 0.0
	_safe_grounded_time = 0.0
	var respawn_position := _last_safe_position
	if respawn_position.y <= fall_limit_y + 2.0:
		respawn_position = Vector3(0, 0.05, -10)
	global_position = respawn_position + Vector3.UP * respawn_height_offset
	state_machine.set_state(PlayerStateMachine.State.IDLE)
	if is_instance_valid(_camera_controller):
		_camera_controller.snap_to_player()

## Atualiza locomoção: movimento, salto, rotação e transições de estado.
func _update_locomotion(delta: float) -> void:
	var attacking := combat.is_attacking()
	if not attacking and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		state_machine.set_state(PlayerStateMachine.State.JUMP)
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_vec)
	var grounded := is_on_floor()
	if input_vec.length_squared() > 0.01:
		_move_hold_time += delta
	else:
		_move_hold_time = 0.0
	var desired_speed := run_speed if _move_hold_time >= 0.34 and lock_on.get_target() == null else move_speed
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
	if not attacking and grounded and velocity.y <= 0.0:
		state_machine.set_state(PlayerStateMachine.State.MOVE if direction.length_squared() > 0.01 else PlayerStateMachine.State.IDLE)

## Converte input de movimento em direção relativa à câmera.
## @param input_vec Vetor 2D de input (-1 a 1 em cada eixo).
## @return Direção 3D normalizada no plano XZ.
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

## Verifica se a esquiva pode ser iniciada.
## @return true se a esquiva está disponível, false caso contrário.
func _can_start_dodge() -> bool:
	if _dodge_cooldown_left > 0.0 or state_machine.state in [PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return false
	if not is_on_floor() and _air_dodge_used:
		return false
	if combat.is_attacking():
		return combat.can_cancel_to_dodge()
	return true

## Inicia a esquiva na direção do input (ou frente se não houver input).
func _start_dodge() -> void:
	if combat.is_attacking():
		combat.cancel_attack()
	# Clear attack buffer on dodge
	combat.clear_buffer()
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

## Atualiza a esquiva em andamento.
func _update_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	velocity.x = _dodge_direction.x * dodge_speed
	velocity.z = _dodge_direction.z * dodge_speed
	if _dodge_elapsed >= dodge_duration:
		state_machine.set_state(PlayerStateMachine.State.IDLE if is_on_floor() else PlayerStateMachine.State.FALL)

## Recebe um golpe de uma hitbox.
## @param hitbox A hitbox que acertou o jogador.
## @return true se o golpe foi aceito, false se o jogador estava invulnerável ou morto.
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
	# Clear attack buffer on hit stun
	combat.clear_buffer()
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
	if is_instance_valid(_camera_controller):
		_camera_controller.hit_impulse(0.11, true)
	return true

## Retorna o alvo atual de lock-on.
## @return O nó 3D do alvo, ou null se não há alvo.
func get_lock_target() -> Node3D:
	return lock_on.get_target()

## Retorna o nome do estado atual do jogador.
## @return String com o nome do estado (ex: "IDLE", "MOVE", "ATTACK").
func get_state_name() -> String:
	return state_machine.state_name()

## Verifica se o jogador está vivo.
## @return true se o jogador está vivo, false se está morto.
func is_alive() -> bool:
	return not _dead

## Verifica se o jogador está invulnerável (janela de esquiva).
## @return true se está invulnerável, false caso contrário.
func _is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _skill_guard_until or (state_machine.state == PlayerStateMachine.State.DODGE and _dodge_elapsed >= invulnerability_start and _dodge_elapsed <= invulnerability_end)

## Verifica se está na janela de perfect dodge.
## @return true se está na janela de perfect dodge, false caso contrário.
func _is_perfect_dodge_window() -> bool:
	return _is_invulnerable() and _dodge_elapsed <= invulnerability_start + 0.10

## Dispara efeitos de perfect dodge: slow motion, câmera e estilo.
func _trigger_perfect_dodge() -> void:
	GameManager.register_perfect_dodge()
	if equipment != null:
		equipment.on_perfect_dodge()
	GameManager.perfect_dodge_slow_motion()
	if is_instance_valid(_camera_controller):
		_camera_controller.kick_fov(-4.0, 0.20)

## Atualiza estado aéreo (JUMP/FALL) baseado na velocidade vertical.
func _update_air_state() -> void:
	if state_machine.state in [PlayerStateMachine.State.DODGE, PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK, PlayerStateMachine.State.HIT, PlayerStateMachine.State.DEAD]:
		return
	if not is_on_floor():
		state_machine.set_state(PlayerStateMachine.State.JUMP if velocity.y > 0.0 else PlayerStateMachine.State.FALL)

## Chamado quando o jogador morre.
## A morte reinicia a cena atual; ainda não existe sistema de checkpoints.
func _on_died() -> void:
	_dead = true
	mana.regeneration_enabled = false
	combat.cancel_attack()
	# Clear attack buffer on death
	combat.clear_buffer()
	state_machine.set_state(PlayerStateMachine.State.DEAD)
	velocity = Vector3.ZERO
	lock_on.clear_target()
	if animation_controller != null:
		animation_controller.notify_dead()
	await get_tree().create_timer(2.0).timeout
	GameManager.reset_style()
	get_tree().reload_current_scene()
