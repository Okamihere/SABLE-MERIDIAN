extends Node

## Autoload compartilhado entre cenas: entradas, jogador, estilo e efeitos de tempo.
## Não salva progresso em disco; as configurações de entrada são criadas em execução.

signal style_changed(combo: int, score: int, rank: String)
signal debug_changed(enabled: bool)
signal player_registered(player: Node)

var DEBUG_COMBAT: bool = false
var player: Node
var style_meter: StyleMeter

var combo_count: int:
	get:
		return style_meter.combo_count if is_instance_valid(style_meter) else 0

var style_score: int:
	get:
		return style_meter.score if is_instance_valid(style_meter) else 0

var style_rank: String:
	get:
		return style_meter.rank if is_instance_valid(style_meter) else "D"

var _time_scale_generation: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	style_meter = StyleMeter.new()
	style_meter.name = "StyleMeter"
	add_child(style_meter)
	style_meter.changed.connect(_on_style_meter_changed)
	_ensure_inputs()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		DEBUG_COMBAT = not DEBUG_COMBAT
		debug_changed.emit(DEBUG_COMBAT)
	if Input.is_action_just_pressed("mouse_release"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func register_player(value: Node) -> void:
	player = value
	player_registered.emit(player)

func register_hit(attack_id: StringName, base_points: int) -> void:
	style_meter.register_hit(attack_id, base_points)

func register_perfect_dodge() -> void:
	style_meter.register_perfect_dodge()

func player_damaged() -> void:
	style_meter.player_damaged()

func reset_style() -> void:
	style_meter.reset()

func hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	_apply_time_scale(0.06, duration)

func perfect_dodge_slow_motion() -> void:
	_apply_time_scale(0.35, 0.32)

## A geração impede um timer antigo de desfazer um efeito de tempo mais recente.
func _apply_time_scale(scale: float, duration: float) -> void:
	_time_scale_generation += 1
	var generation := _time_scale_generation
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == _time_scale_generation:
		Engine.time_scale = 1.0

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
	_bind_key("lock_on", KEY_Q)
	_bind_key("mouse_release", KEY_ESCAPE)
	_bind_key("debug_toggle", KEY_F3)
	_bind_mouse("light_attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("heavy_attack", MOUSE_BUTTON_RIGHT)

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
