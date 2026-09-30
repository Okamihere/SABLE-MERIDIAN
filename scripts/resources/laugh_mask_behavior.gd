class_name LaughMaskBehavior
extends MaskBehavior

## O Riso permite esquivar assim que o golpe se torna ativo e repetir a cadeia.
func can_cancel_to_dodge(attack: AttackData, elapsed: float) -> bool:
	return elapsed >= attack.startup

func continue_after_finisher(weapon: WeaponData) -> bool:
	return weapon != null and not weapon.light_chain.is_empty()
