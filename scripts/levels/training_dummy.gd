extends CharacterBody3D

## Alvo passivo e indestrutível para praticar lock-on e ataques.
##
## Implementa o contrato de alvo/dano sem IA ofensiva nem perda de vida.
## O boneco de treino reage visualmente aos acertos e emite sinais para o tutorial.
##
## Uso típico:
##   - Instanciar a cena training_dummy.tscn
##   - Posicionar no mundo
##   - Conectar [signal struck] para reagir a acertos

## Emitido quando o boneco é atingido. Parâmetro: ID do ataque.
signal struck(attack_id: StringName)

## Referência ao nó visual.
@onready var visual: Node3D = $Visual
## Tween de reação atual.
var _reaction: Tween

## Inicializa o boneco: adiciona aos grupos "enemies" e "training_dummies".
func _ready() -> void:
	add_to_group("enemies")
	add_to_group("training_dummies")

## Retorna sempre true (boneco é indestrutível).
func is_alive() -> bool:
	return true

## Retorna o nome do estado (sempre "TREINO").
func get_state_name() -> String:
	return "TREINO"

## Recebe um golpe do jogador.
## Aceita somente o jogador e reinicia a reação visual em acertos consecutivos.
## @param hitbox A hitbox que acertou o boneco.
## @return true se o golpe foi aceito, false caso contrário.
func receive_hitbox(hitbox: HitboxComponent) -> bool:
	if not is_instance_valid(hitbox.source) or not (hitbox.source is PlayerController):
		return false
	struck.emit(hitbox.attack_id)
	if is_instance_valid(_reaction):
		_reaction.kill()
	visual.rotation.x = -0.18
	_reaction = create_tween()
	_reaction.tween_property(visual, "rotation:x", 0.0, 0.22)
	return true
