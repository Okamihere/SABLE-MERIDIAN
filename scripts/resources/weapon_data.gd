class_name WeaponData
extends Resource

## Perfil de golpes e alcance. Regras exclusivas ficam em WeaponBehavior.
@export var weapon_id: StringName
@export var display_name: String
@export_multiline var identity: String
@export var light_chain: Array[AttackData] = []
@export var heavy: AttackData
@export var launcher: AttackData
@export var air_light: AttackData
@export var air_heavy: AttackData
@export var light_hitbox_size: Vector3 = Vector3(1.35, 1.1, 1.55)
@export var heavy_hitbox_size: Vector3 = Vector3(1.8, 1.45, 1.85)
@export var light_hitbox_offset: Vector3 = Vector3(0, 1.2, 1.05)
@export var heavy_hitbox_offset: Vector3 = Vector3(0, 1.15, 1.3)
@export var behavior: WeaponBehavior

func is_playable() -> bool:
	return not light_chain.is_empty() and heavy != null and air_light != null and air_heavy != null

func is_heavy_attack(attack: AttackData) -> bool:
	return attack == heavy or attack == launcher or attack == air_heavy
