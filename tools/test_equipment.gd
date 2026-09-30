extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(18.0).timeout
	push_error("Equipment test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(50)
	var player = current_scene.get_node("Player")
	assert(player.equipment.weapon == null, "Training room must still require the staff pickup")
	player.equip_staff()
	var equipment = player.equipment
	assert(equipment.WEAPONS.size() == 5 and equipment.MASKS.size() == 3, "All requested identities must be present in the catalog")
	assert(equipment.weapon.weapon_id == &"staff" and equipment.has_weapon(&"card_daggers"), "Staff pickup must unlock two playable styles")
	assert(not equipment.request_weapon(&"puppet_strings"), "An unfinished weapon must never equip as a fake style")
	assert(not equipment.equip_mask(&"mourning"), "An unfinished mask must never equip as a fake style")
	assert(equipment.relics.size() == 1 and equipment.relic_slots == 2, "Encore ticket must occupy one of two relic slots")
	assert(not equipment.equip_relic(&"encore_ticket"), "The same relic cannot fill both slots")
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	assert(equipment.request_weapon(&"card_daggers") and equipment.has_pending_weapon(), "Weapon change during attack must queue")
	player.combat._buffer_action(&"light")
	await _frames(9)
	assert(equipment.weapon.weapon_id == &"card_daggers", "Buffered combo must commit weapon switch at the combo window")
	assert(player.combat._current_attack.attack_id == &"dagger_light_2", "Next hit must use the new weapon without resetting the chain")
	assert(not player.staff_attachment.visible and player.dagger_right.visible and player.dagger_left.visible, "Dagger visual must replace staff")
	var dagger_shape := player.get_node("Hitboxes/LightHitbox/CollisionShape3D").shape as BoxShape3D
	assert(dagger_shape.size.z < 1.2, "Daggers must have shorter collision reach")
	player.combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	await _frames(3)
	var before_blink: Vector3 = player.global_position
	player.combat._start_attack(equipment.weapon.heavy, 0)
	assert(player.global_position.distance_to(before_blink) > 1.5, "Dagger heavy must perform a real short teleport")
	player.combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	player.global_position = Vector3(8, 0.05, 14.2)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _frames(2)
	player.combat._start_attack(equipment.weapon.heavy, 0)
	assert(player.global_position.z < 15.4, "Dagger blink must stop before a solid wall")
	player.combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	assert(equipment.equip_mask(&"laugh") and player.laugh_mask_visual.visible, "Laugh mask must be equipable and visible")
	player.combat._start_attack(equipment.weapon.light_chain[0], 1)
	player.combat._attack_elapsed = equipment.weapon.light_chain[0].startup
	assert(player.combat.can_cancel_to_dodge(), "Laugh mask must open a new dodge cancel rule")
	equipment.equip_mask(&"")
	assert(not player.combat.can_cancel_to_dodge(), "Removing mask must restore normal cancel timing")
	equipment.equip_mask(&"laugh")
	player.combat._start_attack(equipment.weapon.light_chain[2], 3)
	player.combat._buffer_action(&"light")
	await _frames(9)
	assert(player.combat._current_attack == equipment.weapon.light_chain[0] and player.combat._chain_index == 1, "Laugh mask must restart the chain after the finisher")
	player.combat.cancel_attack()
	player.spell_manager._cooldowns[&"cursed_deck"] = 1.0
	player._trigger_perfect_dodge()
	assert(player.spell_manager.get_cooldown_remaining(player.spells[0]) == 0.0, "Encore ticket must refresh the deck on perfect dodge")
	await create_timer(0.35, true, false, true).timeout
	player.global_position = Vector3(0, 0.05, 18.35)
	player.velocity = Vector3.ZERO
	await _frames(5)
	assert(root.get_node("AreaTransition").is_travelling, "Fog gate must begin the scene transition")
	await create_timer(2.0).timeout
	await _frames(10)
	assert(current_scene.scene_file_path == "res://scenes/levels/main.tscn", "Fog crossing must reach the city")
	player = current_scene.get_node("Player")
	assert(player.equipment.weapon.weapon_id == &"card_daggers" and player.equipment.mask.mask_id == &"laugh", "Weapon and mask must survive scene changes")
	assert(player.equipment.relics.size() == 1, "Relic must survive scene changes")
	print("PASS: weapon catalog, queued swap, dagger combo/blink, mask cancel/loop, relic rule and scene persistence")
	quit()
