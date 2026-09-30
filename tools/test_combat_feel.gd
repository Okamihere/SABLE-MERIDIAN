extends SceneTree

## Verifica trajetórias e janelas de comando em física real, sem depender de animação visual.
func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(15.0).timeout
	push_error("Combat feel test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(50)
	var player = current_scene.get_node("Player")
	player.equip_staff()
	assert(player.is_on_floor(), "Player must start on solid ground")
	var floor_y: float = player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	assert(player.velocity.y > 0.0, "Jump command must produce upward velocity immediately")
	var apex: float = player.global_position.y
	var rising_frames := 0
	var falling_frames := 0
	for index in 65:
		await _frames(1)
		apex = maxf(apex, player.global_position.y)
		if player.velocity.y > 0.0:
			rising_frames += 1
		elif not player.is_on_floor():
			falling_frames += 1
	assert(apex - floor_y > 1.1 and apex - floor_y < 1.7, "Jump arc must remain useful but compact")
	assert(rising_frames < 24 and falling_frames < 28, "Jump and fall should finish promptly")
	assert(player.is_on_floor(), "Player must land after jumping")
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	player.combat._buffer_action(&"light")
	await _frames(9)
	assert(player.combat._chain_index == 2, "Buffered light attack must flow into second strike")
	player.combat._buffer_action(&"heavy")
	await _frames(9)
	assert(player.combat._current_attack == player.combat.LAUNCHER, "Heavy input after second light must launch")
	await _frames(13)
	assert(player.combat.can_cancel_to_dodge(), "Launcher must expose a dodge cancel after commitment")
	player._start_dodge()
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE and not player.combat.is_attacking(), "Dodge must cancel committed attack")
	await _frames(20)
	assert(player.state_machine.state != PlayerStateMachine.State.DODGE, "Dodge must end promptly")
	await _frames(7)
	player.velocity.y = 5.0
	player.global_position.y += 0.5
	await _frames(2)
	player.combat._start_attack(player.combat.AIR_LIGHT, 0)
	assert(player.state_machine.state == PlayerStateMachine.State.AIR_ATTACK, "Air attack must be available after jump")
	player.combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.FALL)
	player.velocity.y = -4.0
	player._dodge_cooldown_left = 0.0
	player._start_dodge()
	var before_fall: float = player.velocity.y
	await _frames(6)
	assert(player.velocity.y < before_fall - 2.0, "Air dodge must allow gravity instead of suspending the player")
	print("PASS: jump arc, fall, buffered combo, launcher, dodge cancel, air attack and air dodge")
	quit()
