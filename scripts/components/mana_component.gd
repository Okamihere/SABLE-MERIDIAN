class_name ManaComponent
extends Node

## Reserva de mana reutilizável. Poderes devem chamar [method try_spend] antes de agir.
##
## Nenhuma habilidade consome mana por padrão; a reserva fica pronta para futuros poderes.
## A regeneração começa após [member regeneration_delay] segundos sem gastar mana.
##
## Uso típico:
##   - Adicionar como filho de um CharacterBody3D
##   - Chamar [method try_spend] antes de usar uma habilidade
##   - Conectar [signal changed] para atualizar a UI

## Emitido quando a mana muda. Parâmetros: mana atual, mana máxima.
signal changed(current: float, maximum: float)

## Mana máxima do personagem.
@export var max_mana: float = 100.0
## Taxa de regeneração por segundo.
@export var regeneration_rate: float = 8.0
## Tempo de espera após gastar mana antes de regenerar (em segundos).
@export var regeneration_delay: float = 1.5

## Mana atual do personagem.
var current_mana: float = 0.0
## Indica se a regeneração está ativa.
var regeneration_enabled: bool = true
## Tempo restante antes de regenerar (em segundos).
var _regeneration_wait: float = 0.0

## Inicializa a mana atual para o valor máximo.
func _ready() -> void:
	current_mana = max_mana

## Processa a regeneração de mana.
func _physics_process(delta: float) -> void:
	if not regeneration_enabled:
		return
	if _regeneration_wait > 0.0:
		_regeneration_wait = maxf(0.0, _regeneration_wait - delta)
		return
	restore(regeneration_rate * delta)

## Tenta gastar uma quantidade de mana.
## Uma tentativa sem saldo não gasta parcialmente nem interrompe a regeneração.
## @param amount Quantidade de mana a gastar.
## @return true se a mana foi gasta, false se não havia saldo suficiente.
func try_spend(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or amount > current_mana:
		return false
	current_mana -= amount
	_regeneration_wait = regeneration_delay
	changed.emit(current_mana, max_mana)
	return true

## Restaura uma quantidade de mana.
## @param amount Quantidade de mana a restaurar.
func restore(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or current_mana >= max_mana:
		return
	current_mana = minf(max_mana, current_mana + amount)
	changed.emit(current_mana, max_mana)
