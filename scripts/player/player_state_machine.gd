class_name PlayerStateMachine
extends Node

## Centraliza o estado do jogador e avisa os componentes quando ele muda.
##
## As regras de movimento consultam este estado para respeitar ataques e dano.
## A máquina de estados é o ponto de verdade para todas as transições de estado.
##
## Estados disponíveis:
## - IDLE: parado no chão
## - MOVE: movendo no chão
## - JUMP: subindo após salto
## - FALL: caindo
## - DODGE: executando esquiva (invulnerável)
## - ATTACK: executando ataque no chão
## - AIR_ATTACK: executando ataque no ar
## - HIT: recebendo dano (hit stun)
## - DEAD: morto

## Emitido quando o estado muda. Parâmetros: estado anterior, estado atual.
signal state_changed(previous: State, current: State)

## Enumeração de estados possíveis do jogador.
enum State { IDLE, MOVE, JUMP, FALL, DODGE, ATTACK, AIR_ATTACK, HIT, DEAD }

## Estado atual do jogador.
var state: State = State.IDLE

## Define o estado do jogador.
## Não faz nada se o estado for o mesmo que o atual.
## @param next_state Novo estado a ser definido.
func set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state)

## Retorna o nome do estado atual como string.
## @return Nome do estado (ex: "IDLE", "MOVE", "ATTACK").
func state_name() -> String:
	return State.keys()[state]

## Verifica se o estado atual permite locomoção.
## @return true se o jogador pode se mover, false caso contrário.
func allows_locomotion() -> bool:
	return state not in [State.DODGE, State.HIT, State.DEAD]
