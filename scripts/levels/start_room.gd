extends Node3D

## Tutorial opcional: registra ações reais em qualquer ordem e exibe a próxima dica.
## Enter abre a cidade sem exigir a conclusão das lições; progresso é só desta sessão.

@export_file("*.tscn") var main_scene_path: String = "res://scenes/levels/main.tscn"
var _compact_layout: bool = false
var _entering_city: bool = false
var completed: Dictionary = {}
var _walked: float = 0.0
var _previous_position: Vector3
@onready var player: PlayerController = $Player
@onready var help: Label = $Instructions/Panel/Margin/Help

const LESSONS = [
	["move", "WASD — explore o pátio"],
	["jump", "ESPAÇO — experimente um salto nos blocos à esquerda"],
	["dodge", "SHIFT + direção — experimente uma esquiva"],
	["lock", "Q — fixe um dos bonecos à frente"],
	["light", "Mouse esquerdo — acerte um boneco"],
	["heavy", "Mouse direito — acerte um golpe pesado"]
]

func _ready() -> void:
	_previous_position = player.position
	for dummy in get_tree().get_nodes_in_group("training_dummies"):
		dummy.struck.connect(_on_dummy_struck)
	_update_help()

func _process(_delta: float) -> void:
	var displacement := player.position - _previous_position
	displacement.y = 0.0
	if displacement.length() < 1.0:
		_walked += displacement.length()
	_previous_position = player.position
	if _walked >= 4.0:
		_complete("move")
	if player.state_machine.state == PlayerStateMachine.State.JUMP:
		_complete("jump")
	if player.state_machine.state == PlayerStateMachine.State.DODGE:
		_complete("dodge")
	if player.get_lock_target() != null:
		_complete("lock")

## As lições de combate exigem acerto; apertar o botão no vazio não basta.
func _on_dummy_struck(attack_id: StringName) -> void:
	if attack_id in [&"heavy", &"air_heavy", &"launcher"]:
		_complete("heavy")
	else:
		_complete("light")

## Registro idempotente: ações repetidas não aumentam o total concluído.
func _complete(key: String) -> void:
	if completed.has(key):
		return
	completed[key] = true
	_update_help()

func set_compact_layout(value: bool) -> void:
	_compact_layout = value
	_update_help()

func _update_help() -> void:
	var next_step: String = "Treino concluído. Explore ou entre na cidade."
	for lesson in LESSONS:
		if not completed.has(lesson[0]):
			next_step = lesson[1]
			break
	if _compact_layout:
		help.text = "TREINO %d / %d • ENTER: cidade\n%s" % [completed.size(), LESSONS.size(), next_step]
		return
	help.text = "PÁTIO DE TREINO   %d / %d\n%s\nMouse: câmera • Esc: liberar mouse\nENTER: cidade a qualquer momento" % [completed.size(), LESSONS.size(), next_step]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo() and not _entering_city:
		_entering_city = true
		_enter_city.call_deferred()

## A transição é adiada pelo chamador para não remover a cena durante o input.
func _enter_city() -> void:
	GameManager.reset_style()
	var result := get_tree().change_scene_to_file(main_scene_path)
	if result != OK:
		_entering_city = false
		push_error("Não foi possível abrir a cidade: %s" % error_string(result))
