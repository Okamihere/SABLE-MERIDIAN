extends CharacterBody3D

## NPC mentor "O Contrarregra" - antigo ilusionista de palco.
##
## Aparência provisória: casaco comprido preto, detalhes em marfim,
## luvas e meia máscara lisa. Conhece o protagonista bem demais,
## mas nunca explica diretamente quem é.
##
## A cena está organizada para permitir trocar o visual por um
## modelo definitivo depois.

## Distância máxima para interação.
@export var interaction_distance: float = 3.0
## Altura do aviso contextual em relação ao chão do NPC.
@export var interaction_anchor_height: float = 2.65
## Referência ao visual do NPC.
@onready var visual: Node3D = $Visual

const DIALOGUE_LINE := "Não vim ensinar você a vencer. Vim descobrir o que fará quando puder."

## Estado do diálogo.
var _dialogue_active: bool = false

## Sinal emitido quando o diálogo começa.
signal dialogue_started
## Sinal emitido quando o diálogo termina.
signal dialogue_ended
## Sinal emitido quando uma linha de diálogo é exibida.
signal dialogue_line_changed(line_text: String, speaker_name: String)

## Inicializa o NPC.
func _ready() -> void:
	# Adiciona ao grupo de NPCs para fácil identificação
	add_to_group("npcs")
	_pose_seated()

## Pose estática leve para o modelo sem esqueleto nem animação de sentar.
func _pose_seated() -> void:
	var model := visual.get_node_or_null("Model")
	if model == null:
		return
	for part in model.get_children():
		if part is Node3D:
			(part as Node3D).position.y -= 0.43
	for side in ["L", "R"]:
		var trouser := model.find_child("%s trouser" % side, true, false) as Node3D
		var boot := model.find_child("%s boot" % side, true, false) as Node3D
		var boot_top := model.find_child("%s boot top" % side, true, false) as Node3D
		if trouser != null:
			trouser.rotation.x += deg_to_rad(62.0)
			trouser.position.y += 0.23
			trouser.position.z += 0.27
		for foot in [boot, boot_top]:
			if foot != null:
				foot.position.y += 0.43
				foot.position.z += 0.63
		var arm := model.find_child("%s arm" % side, true, false) as Node3D
		if arm != null:
			arm.rotation.x += deg_to_rad(18.0)

## Verifica se o jogador pode interagir.
## @return true se o jogador está perto o suficiente.
func can_interact() -> bool:
	if _dialogue_active:
		return false
	var player := GameManager.player
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= interaction_distance

## Inicia o diálogo com o jogador.
func start_dialogue() -> void:
	if _dialogue_active:
		return
	_dialogue_active = true
	dialogue_started.emit()
	dialogue_line_changed.emit(DIALOGUE_LINE, get_character_name())

## Avança para a próxima linha do diálogo.
## @return true se o diálogo continua, false se terminou.
func advance_dialogue() -> bool:
	if not _dialogue_active:
		return false
	end_dialogue()
	return false

## Termina o diálogo.
func end_dialogue() -> void:
	if not _dialogue_active:
		return
	_dialogue_active = false
	dialogue_ended.emit()

## Retorna o nome do personagem.
## @return Nome do NPC.
func get_character_name() -> String:
	return "O Contrarregra"

## Ponto opcional usado pelo aviso de interação compartilhado.
func get_interaction_anchor() -> Vector3:
	return global_position + Vector3.UP * interaction_anchor_height

## Verifica se o diálogo está ativo.
## @return true se o diálogo está ativo.
func is_dialogue_active() -> bool:
	return _dialogue_active
