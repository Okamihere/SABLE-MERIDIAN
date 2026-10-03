extends Node

## Autoload compartilhado entre cenas: entradas, jogador, estilo e efeitos de tempo.
##
## Não salva progresso em disco; as configurações de entrada são criadas em execução.
## Este é o ponto central de comunicação entre todos os sistemas do jogo.
##
## Responsabilidades:
## - Gerenciar input map (criado em runtime para evitar conflitos)
## - Registrar referência global do jogador
## - Gerenciar sistema de estilo (pontuação, combo, rank)
## - Aplicar efeitos de tempo (hit stop, slow motion)
## - Toggle de debug de combate

## Emitido quando o estilo muda. Parâmetros: combo, score, rank.
signal style_changed(combo: int, score: int, rank: String)
## Emitido quando o modo debug é alternado. Parâmetro: enabled.
signal debug_changed(enabled: bool)
## Emitido quando um jogador é registrado. Parâmetro: player.
signal player_registered(player: Node)

## Indica se o debug de combate está ativo.
var DEBUG_COMBAT: bool = false
## Sensibilidade da câmera (centralizada para evitar dependência de ordem de init).
var camera_sensitivity: float = 0.0028
## Emitido quando a sensibilidade da câmera muda.
signal camera_sensitivity_changed(sensitivity: float)
## Referência global ao jogador.
var player: Node
## Cajado adquirido nesta sessão; acompanha a troca de cenas.
var has_staff: bool = false
var equipped_weapon_id: StringName = &"staff"
var equipped_mask_id: StringName = &""
var equipped_relic_ids: Array[StringName] = [&"encore_ticket"]

func reset_equipment() -> void:
	has_staff = false
	equipped_weapon_id = &"staff"
	equipped_mask_id = &""
	equipped_relic_ids = [&"encore_ticket"]
## Referência ao medidor de estilo.
var style_meter: StyleMeter

## Contagem de combo atual.
var combo_count: int:
	get:
		return style_meter.combo_count if is_instance_valid(style_meter) else 0

## Pontuação de estilo atual.
var style_score: int:
	get:
		return style_meter.score if is_instance_valid(style_meter) else 0

## Rank de estilo atual.
var style_rank: String:
	get:
		return style_meter.rank if is_instance_valid(style_meter) else "D"

## Geração atual de time scale (para evitar conflitos de timers).
var _time_scale_generation: int = 0
## FPS alvo quando a janela perde foco.
const BACKGROUND_FPS: int = 30
## FPS configurado pelo usuário (restaurado ao ganhar foco).
var _user_max_fps: int = 0

## Inicializa o GameManager: cria StyleMeter e configura inputs.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	style_meter = StyleMeter.new()
	style_meter.name = "StyleMeter"
	add_child(style_meter)
	style_meter.changed.connect(_on_style_meter_changed)
	_ensure_inputs()
	_user_max_fps = Engine.max_fps

## Processa input de debug. O menu de pausa cuida do Esc e do cursor.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		DEBUG_COMBAT = not DEBUG_COMBAT
		debug_changed.emit(DEBUG_COMBAT)

## Detecta ganho/perda de foco da janela para ajustar FPS.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Janela perdeu foco: limita a 30 FPS para economizar CPU/GPU
			if Engine.max_fps != BACKGROUND_FPS:
				Engine.max_fps = BACKGROUND_FPS
		NOTIFICATION_APPLICATION_FOCUS_IN:
			# Janela recuperou foco: restaura FPS do usuário
			if _user_max_fps > 0 and Engine.max_fps != _user_max_fps:
				Engine.max_fps = _user_max_fps

## Registra o jogador global.
## @param value Nó do jogador.
func register_player(value: Node) -> void:
	player = value
	player_registered.emit(player)

## Define a sensibilidade da câmera e emite sinal de mudança.
## @param value Nova sensibilidade.
func set_camera_sensitivity(value: float) -> void:
	if camera_sensitivity == value:
		return
	camera_sensitivity = value
	camera_sensitivity_changed.emit(value)

## Atualiza o FPS máximo do usuário (chamado ao mudar configurações).
## @param fps Novo limite de FPS (0 = ilimitado).
func _set_user_max_fps(fps: int) -> void:
	_user_max_fps = fps
	# Aplica imediatamente; o _notification() vai restaurar BACKGROUND_FPS se perder foco
	Engine.max_fps = fps

## Registra um golpe que acertou.
## @param attack_id Identificador do ataque.
## @param base_points Pontos base do ataque.
func register_hit(attack_id: StringName, base_points: int) -> void:
	style_meter.register_hit(attack_id, base_points)

## Registra um perfect dodge.
func register_perfect_dodge() -> void:
	style_meter.register_perfect_dodge()

## Registra que o jogador foi danificado.
func player_damaged() -> void:
	style_meter.player_damaged()

## Reseta o sistema de estilo.
func reset_style() -> void:
	style_meter.reset()

## Aplica hit stop (pausa breve no tempo).
## @param duration Duração do hit stop (em segundos).
func hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	_apply_time_scale(0.06, duration)

## Aplica slow motion de perfect dodge.
func perfect_dodge_slow_motion() -> void:
	_apply_time_scale(0.35, 0.32)

## Aplica uma escala de tempo temporária.
## A geração impede um timer antigo de desfazer um efeito de tempo mais recente.
## @param scale Escala de tempo a aplicar.
## @param duration Duração do efeito (em segundos).
func _apply_time_scale(scale: float, duration: float) -> void:
	_time_scale_generation += 1
	var generation := _time_scale_generation
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == _time_scale_generation:
		Engine.time_scale = 1.0

## Chamado quando o StyleMeter muda.
func _on_style_meter_changed(combo: int, score: int, rank: String) -> void:
	style_changed.emit(combo, score, rank)

## Cria apenas vínculos ausentes para evitar duplicação ao trocar de cena.
func _ensure_inputs() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("dodge", KEY_SHIFT)
	_bind_mouse("lock_on", MOUSE_BUTTON_MIDDLE)
	_bind_key("pause_menu", KEY_ESCAPE)
	_bind_key("debug_toggle", KEY_F3)
	_bind_mouse("light_attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("heavy_attack", MOUSE_BUTTON_RIGHT)
	_bind_key("spell_q", KEY_Q)
	_bind_key("spell_e", KEY_E)
	_bind_key("spell_r", KEY_R)
	_unbind_key("interact", KEY_G)
	_bind_key("interact", KEY_F)
	_bind_key("weapon_staff", KEY_1)
	_bind_key("weapon_daggers", KEY_2)
	_bind_key("mask_laugh", KEY_TAB)

## Remove um vínculo antigo sem apagar os demais eventos da ação.
func _unbind_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if key_event.physical_keycode == physical_keycode or key_event.keycode == physical_keycode:
				InputMap.action_erase_event(action, input_event)

## Vincula uma tecla a uma ação.
## @param action Nome da ação.
## @param physical_keycode Código físico da tecla.
func _bind_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)

## Vincula um botão do mouse a uma ação.
## @param action Nome da ação.
## @param button Índice do botão do mouse.
func _bind_mouse(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventMouseButton:
			var mouse_event := input_event as InputEventMouseButton
			if mouse_event.button_index == button:
				return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
