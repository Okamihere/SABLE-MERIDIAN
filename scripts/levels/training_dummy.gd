extends CharacterBody3D

## Alvo passivo e indestrutível para praticar lock-on e ataques.
## Implementa o contrato de alvo/dano sem IA ofensiva nem perda de vida.

signal struck(attack_id: StringName)

@onready var visual: Node3D = $Visual
var _reaction: Tween

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("training_dummies")

func is_alive() -> bool:
	return true

func get_state_name() -> String:
	return "TREINO"

## Aceita somente o jogador e reinicia a reação visual em acertos consecutivos.
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
