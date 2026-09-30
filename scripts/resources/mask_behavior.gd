class_name MaskBehavior
extends Resource

## Retorna true somente quando a persona altera uma regra de cancelamento.
func can_cancel_to_dodge(_attack: AttackData, _elapsed: float) -> bool:
	return false

## Permite uma rota especial ao fim da cadeia, se a persona a tiver.
func continue_after_finisher(_weapon: WeaponData) -> bool:
	return false
