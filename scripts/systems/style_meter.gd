class_name StyleMeter
extends Node

## Pontuação e ranking de estilo com penalidade por repetir o mesmo ataque.
##
## O combo expira em tempo real; perder o combo não apaga a pontuação acumulada.
## O sistema de ranks é baseado na pontuação total:
## - D: 0-749
## - C: 750-1799
## - B: 1800-3499
## - A: 3500-6499
## - S: 6500+
##
## Uso típico:
##   - Adicionar como filho do GameManager
##   - Chamar [method register_hit] quando um golpe acertar
##   - Chamar [method register_perfect_dodge] para bônus de estilo
##   - Conectar [signal changed] para atualizar a UI

## Emitido quando o estilo muda. Parâmetros: combo, score, rank.
signal changed(combo: int, score: int, rank: String)

## Contagem de combo atual.
var combo_count: int = 0
## Pontuação de estilo atual.
var score: int = 0
## Rank de estilo atual.
var rank: String = "D"

## Tempo de expiração do combo (em segundos).
var _combo_expire_time: float = 0.0
## ID do último ataque registrado.
var _last_attack_id: StringName = &""
## Contagem de repetições do mesmo ataque.
var _repeat_count: int = 0

## Processa expiração do combo.
func _process(_delta: float) -> void:
	if combo_count > 0 and Time.get_ticks_msec() / 1000.0 > _combo_expire_time:
		combo_count = 0
		changed.emit(combo_count, score, rank)

## Registra um golpe que acertou.
## Aplica penalidade por repetir o mesmo ataque.
## @param attack_id Identificador do ataque.
## @param base_points Pontos base do ataque.
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

## Registra um perfect dodge (+250 pontos).
func register_perfect_dodge() -> void:
	score += 250
	_update_rank()
	changed.emit(combo_count, score, rank)

## Registra que o jogador foi danificado (perde combo).
func player_damaged() -> void:
	combo_count = 0
	_repeat_count = 0
	changed.emit(combo_count, score, rank)

## Reseta o sistema de estilo.
func reset() -> void:
	combo_count = 0
	score = 0
	rank = "D"
	_last_attack_id = &""
	_repeat_count = 0
	changed.emit(combo_count, score, rank)

## Atualiza o rank baseado na pontuação atual.
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
