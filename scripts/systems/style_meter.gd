class_name StyleMeter
extends Node

## Pontuação e ranking de estilo com penalidade por repetir o mesmo ataque.
## O combo expira em tempo real; perder o combo não apaga a pontuação acumulada.

signal changed(combo: int, score: int, rank: String)

var combo_count: int = 0
var score: int = 0
var rank: String = "D"

var _combo_expire_time: float = 0.0
var _last_attack_id: StringName = &""
var _repeat_count: int = 0

func _process(_delta: float) -> void:
	if combo_count > 0 and Time.get_ticks_msec() / 1000.0 > _combo_expire_time:
		combo_count = 0
		changed.emit(combo_count, score, rank)

func register_hit(attack_id: StringName, base_points: int) -> void:
	combo_count += 1
	_combo_expire_time = Time.get_ticks_msec() / 1000.0 + 3.0
	if attack_id == _last_attack_id:
		_repeat_count += 1
	else:
		_last_attack_id = attack_id
		_repeat_count = 0
	var multiplier := maxf(0.25, 1.0 - float(_repeat_count) * 0.18)
	score += int(round(base_points * multiplier))
	_update_rank()
	changed.emit(combo_count, score, rank)

func register_perfect_dodge() -> void:
	score += 250
	_update_rank()
	changed.emit(combo_count, score, rank)

func player_damaged() -> void:
	combo_count = 0
	_repeat_count = 0
	changed.emit(combo_count, score, rank)

func reset() -> void:
	combo_count = 0
	score = 0
	rank = "D"
	_last_attack_id = &""
	_repeat_count = 0
	changed.emit(combo_count, score, rank)

func _update_rank() -> void:
	if score >= 6500:
		rank = "S"
	elif score >= 3500:
		rank = "A"
	elif score >= 1800:
		rank = "B"
	elif score >= 750:
		rank = "C"
	else:
		rank = "D"
