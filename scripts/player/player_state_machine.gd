class_name PlayerStateMachine
extends Node

## Centraliza o estado do jogador e avisa os componentes quando ele muda.
## As regras de movimento consultam este estado para respeitar ataques e dano.

signal state_changed(previous: State, current: State)

enum State { IDLE, MOVE, JUMP, FALL, DODGE, ATTACK, AIR_ATTACK, HIT, DEAD }

var state: State = State.IDLE

func set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state)

func state_name() -> String:
	return State.keys()[state]

func allows_locomotion() -> bool:
	return state not in [State.DODGE, State.ATTACK, State.AIR_ATTACK, State.HIT, State.DEAD]
