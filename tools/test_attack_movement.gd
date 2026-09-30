extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(12.0).timeout
	push_error("Attack movement test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(90)
	var player = current_scene.get_node("Player")
	var model := player.get_node("ModelRoot") as Node3D
	var forward: Vector3 = player._camera_relative_direction(Vector2(0.0, -1.0))
	Input.action_press("move_forward")
	await _frames(18)
	assert(model.global_transform.basis.z.dot(forward) > 0.9, "W must point the jester away from the camera")
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _frames(18)
	assert(model.global_transform.basis.z.dot(-forward) > 0.9, "S must point the jester toward the camera")
	Input.action_release("move_back")
	player.equip_staff()
	for attack in [player.combat.LIGHT_1, player.combat.HEAVY]:
		Input.action_press("move_forward")
		await _frames(4)
		var start_position: Vector3 = player.global_position
		player.combat._start_attack(attack, 1)
		await _frames(8)
		var travel: Vector3 = player.global_position - start_position
		assert(player.combat.is_attacking(), "Attack must remain active while moving")
		assert(player.state_machine.state == PlayerStateMachine.State.ATTACK, "Moving must preserve the attack state")
		assert(travel.dot(forward) > 0.15, "Movement input must move the player during attacks")
		assert(player.animation_controller._movement_blend > 0.05, "Walking animation must continue during attacks")
		Input.action_release("move_forward")
		player.combat.cancel_attack()
		player.state_machine.set_state(PlayerStateMachine.State.IDLE)
		await _frames(2)
	print("PASS: W/S model facing and movement during light/heavy attacks")
	quit()
