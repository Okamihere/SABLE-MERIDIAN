class_name HealthComponent
extends Node

## Componente de vida reutilizável com sinais de dano, cura e morte.
##
## Emite [signal died] uma vez quando a vida chega a zero.
## A reação à morte e o reinício pertencem ao personagem que possui este componente.
##
## Uso típico:
##   - Adicionar como filho de um CharacterBody3D
##   - Conectar sinais [signal damaged], [signal healed] e [signal died]
##   - Chamar [method damage] para aplicar dano e [method heal] para curar

## Emitido quando dano é aplicado. Parâmetros: quantidade de dano, vida atual, vida máxima.
signal damaged(amount: float, current_health: float, max_health: float)
## Emitido quando cura é aplicada. Parâmetros: quantidade curada, vida atual, vida máxima.
signal healed(amount: float, current_health: float, max_health: float)
## Emitido uma única vez quando a vida chega a zero.
signal died

## Vida máxima do personagem.
@export var max_health: float = 100.0

## Vida atual do personagem.
var current_health: float = 0.0

## Inicializa a vida atual para o valor máximo.
func _ready() -> void:
	current_health = max_health

## Aplica dano ao personagem.
## @param amount Quantidade de dano a aplicar (valores <= 0 são ignorados).
## @return true se o dano foi aplicado, false se o personagem já estava morto ou o dano era inválido.
func damage(amount: float) -> bool:
	if current_health <= 0.0 or amount <= 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, current_health, max_health)
	if current_health <= 0.0:
		died.emit()
	return true

## Cura o personagem.
## @param amount Quantidade de vida a recuperar (valores <= 0 são ignorados).
func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0 or current_health >= max_health:
		return
	var previous := current_health
	current_health = minf(max_health, current_health + amount)
	healed.emit(current_health - previous, current_health, max_health)

## Reinicializa os valores silenciosamente; não emite sinais de cura.
func reset() -> void:
	current_health = max_health
