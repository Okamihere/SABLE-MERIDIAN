extends Area3D

## Coletável de melhoria permanente. Defina um ID diferente para cada instância.
##
## Cada orbe concede +1 salto de parede permanente quando coletado.
## O progresso é salvo automaticamente pelo sistema Progression.
## Orbes já coletados são removidos ao carregar a cena.
##
## Uso típico:
##   - Instanciar a cena wall_orb.tscn
##   - Definir [member orb_id] com um identificador único
##   - Posicionar no mundo
##   - O jogador coleta automaticamente ao tocar

## Identificador único da orbe (não deve ser alterado após publicar).
@export var orb_id: String = ""
## Indica se a orbe já foi coletada.
var _collected: bool = false
## Tempo decorrido para animação de flutuação.
var _elapsed: float = 0.0
## Referência ao nó visual.
@onready var visual: MeshInstance3D = $Visual

## Inicializa a orbe: verifica se já foi coletada e conecta sinais.
func _ready() -> void:
	if orb_id.is_empty():
		push_warning("Orbe sem ID: configure orb_id no inspetor.")
	if Progression.collected.has(orb_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

## Anima a orbe (flutuação e rotação).
func _process(delta: float) -> void:
	_elapsed += delta
	visual.position.y = sin(_elapsed * 2.5) * 0.15
	visual.rotation.y += delta

## Detecta quando o jogador toca a orbe e a coleta.
func _on_body_entered(body: Node3D) -> void:
	if _collected or not (body is PlayerController) or not body.is_alive():
		return
	if Progression.collect(orb_id):
		_collected = true
		set_deferred("monitoring", false)
		hide()
		queue_free()
