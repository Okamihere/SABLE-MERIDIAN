class_name ManaComponent
extends Node

## Reserva de mana reutilizável. Poderes devem chamar try_spend antes de agir.
## Nenhuma habilidade consome mana por padrão; a reserva fica pronta para futuros poderes.
signal changed(current: float, maximum: float)
@export var max_mana: float = 100.0
@export var regeneration_rate: float = 8.0
@export var regeneration_delay: float = 1.5
var current_mana: float = 0.0
var regeneration_enabled: bool = true
var _regeneration_wait: float = 0.0

func _ready() -> void:
	current_mana = max_mana

func _physics_process(delta: float) -> void:
	if not regeneration_enabled:
		return
	if _regeneration_wait > 0.0:
		_regeneration_wait = maxf(0.0, _regeneration_wait - delta)
		return
	restore(regeneration_rate * delta)

## Uma tentativa sem saldo não gasta parcialmente nem interrompe a regeneração.
func try_spend(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or amount > current_mana:
		return false
	current_mana -= amount
	_regeneration_wait = regeneration_delay
	changed.emit(current_mana, max_mana)
	return true

func restore(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or current_mana >= max_mana:
		return
	current_mana = minf(max_mana, current_mana + amount)
	changed.emit(current_mana, max_mana)
