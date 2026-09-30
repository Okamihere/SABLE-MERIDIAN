extends Node3D

## Pátio inicial: registra treino opcional, diálogo e acesso à cidade.
##
## A névoa sob o arco leva à cidade; progresso do treino é só desta sessão.
## O tutorial monitora ações do jogador (mover, pular, esquivar, lock-on, atacar)
## sem ocupar a tela com dicas permanentes.
##
## Lições disponíveis:
## - move: andar 4 metros
## - jump: pular
## - dodge: esquivar
## - lock: adquirir alvo de lock-on
## - light: acertar um golpe leve
## - heavy: acertar um golpe pesado

## Dicionário de lições concluídas.
var completed: Dictionary = {}
## Distância total caminhada pelo jogador.
var _walked: float = 0.0
## Posição anterior do jogador.
var _previous_position: Vector3
## Referência ao jogador.
@onready var player: PlayerController = $Player

## Inicializa o registro opcional do treino.
func _ready() -> void:
	_previous_position = player.position
	for dummy in get_tree().get_nodes_in_group("training_dummies"):
		dummy.struck.connect(_on_dummy_struck)

## Processa o progresso do tutorial.
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

## Chamado quando um boneco de treino é atingido.
## As lições de combate exigem acerto; apertar o botão no vazio não basta.
func _on_dummy_struck(attack_id: StringName) -> void:
	if attack_id in [&"heavy", &"air_heavy", &"launcher"]:
		_complete("heavy")
	else:
		_complete("light")

## Marca uma lição como concluída.
## Registro idempotente: ações repetidas não aumentam o total concluído.
## @param key Chave da lição.
func _complete(key: String) -> void:
	if completed.has(key):
		return
	completed[key] = true
