class_name EquipmentComponent
extends Node

## Inventário pequeno de estilos. Recursos incompletos existem no catálogo,
## mas não podem ser equipados antes de receberem golpes e regras reais.
signal weapon_changed(weapon: WeaponData)
signal mask_changed(mask: MaskData)
signal relics_changed

const WEAPONS := {
	&"staff": preload("res://resources/weapons/staff.tres"),
	&"card_daggers": preload("res://resources/weapons/card_daggers.tres"),
	&"puppet_strings": preload("res://resources/weapons/puppet_strings.tres"),
	&"cane_blade": preload("res://resources/weapons/cane_blade.tres"),
	&"living_grimoire": preload("res://resources/weapons/living_grimoire.tres"),
}
const MASKS := {
	&"laugh": preload("res://resources/masks/laugh.tres"),
	&"mourning": preload("res://resources/masks/mourning.tres"),
	&"empty": preload("res://resources/masks/empty.tres"),
}
const RELICS := {
	&"encore_ticket": preload("res://resources/relics/encore_ticket.tres"),
}

@export_range(1, 4, 1) var relic_slots := 2

var weapon: WeaponData
var mask: MaskData
var relics: Array[RelicData] = []
var _unlocked_weapons: Dictionary = {}
var _pending_weapon: StringName = &""

func unlock_weapon(id: StringName) -> bool:
	var data := WEAPONS.get(id) as WeaponData
	if data == null or not data.is_playable():
		return false
	_unlocked_weapons[id] = true
	return true

func has_weapon(id: StringName) -> bool:
	return _unlocked_weapons.has(id)

func request_weapon(id: StringName) -> bool:
	if not has_weapon(id):
		return false
	if weapon != null and weapon.weapon_id == id:
		_pending_weapon = &""
		return true
	var player := get_parent() as PlayerController
	if player != null and player.combat.is_attacking():
		_pending_weapon = id
		return true
	return _equip_weapon(id)

func has_pending_weapon() -> bool:
	return _pending_weapon != &""

## Chamado pelo CombatController na próxima janela de combo ou ao encerrar o golpe.
func commit_pending_weapon() -> void:
	if _pending_weapon == &"":
		return
	var id := _pending_weapon
	_pending_weapon = &""
	_equip_weapon(id)

func _equip_weapon(id: StringName) -> bool:
	if not has_weapon(id):
		return false
	weapon = WEAPONS[id] as WeaponData
	GameManager.equipped_weapon_id = id
	weapon_changed.emit(weapon)
	return true

func equip_mask(id: StringName) -> bool:
	if id == &"":
		mask = null
		GameManager.equipped_mask_id = &""
		mask_changed.emit(null)
		return true
	var data := MASKS.get(id) as MaskData
	if data == null or not data.is_playable():
		return false
	mask = data
	GameManager.equipped_mask_id = id
	mask_changed.emit(mask)
	return true

func toggle_laugh_mask() -> void:
	equip_mask(&"" if mask != null and mask.mask_id == &"laugh" else &"laugh")

func equip_relic(id: StringName) -> bool:
	var data := RELICS.get(id) as RelicData
	if data == null or not data.is_playable() or relics.size() >= relic_slots:
		return false
	for equipped in relics:
		if equipped.relic_id == id:
			return false
	relics.append(data)
	GameManager.equipped_relic_ids.append(id)
	relics_changed.emit()
	return true

func unequip_relic(id: StringName) -> bool:
	for index in relics.size():
		if relics[index].relic_id == id:
			relics.remove_at(index)
			GameManager.equipped_relic_ids.erase(id)
			relics_changed.emit()
			return true
	return false

func restore_from_manager() -> void:
	unlock_weapon(&"staff")
	unlock_weapon(&"card_daggers")
	var selected: StringName = GameManager.equipped_weapon_id
	_equip_weapon(selected if has_weapon(selected) else &"staff")
	equip_mask(GameManager.equipped_mask_id)
	var saved_relics: Array[StringName] = GameManager.equipped_relic_ids.duplicate()
	GameManager.equipped_relic_ids.clear()
	for id in saved_relics:
		equip_relic(id)

func on_perfect_dodge() -> void:
	var player := get_parent() as PlayerController
	for relic in relics:
		relic.behavior.on_perfect_dodge(player)
