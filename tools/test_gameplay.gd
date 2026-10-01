extends SceneTree

## Teste de integração headless com colisões reais e troca de cenas.
## Execute conforme README; assert falha em builds de depuração e o watchdog limita a espera.

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Gameplay regression timed out")
	quit(1)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await frames(90)
	var middle_mouse_focus := false
	for event in InputMap.action_get_events("lock_on"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			middle_mouse_focus = true
		assert(not (event is InputEventKey and (event.physical_keycode == KEY_F or event.keycode == KEY_F)), "F must not focus enemies")
	assert(middle_mouse_focus, "Middle mouse button must focus enemies")
	var f_interaction := false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey and event.physical_keycode == KEY_F:
			f_interaction = true
		assert(not (event is InputEventKey and (event.physical_keycode == KEY_G or event.keycode == KEY_G)), "G must not interact")
	assert(f_interaction, "F must interact with nearby NPCs")
	var player = current_scene.get_node("Player")
	assert(player.is_on_floor(), "Training floor must hold the player")
	assert(not get_root().get_node("GameManager").has_staff, "Training must begin without the staff")
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	assert(not player.combat.is_attacking(), "The jester must not punch before taking the staff")
	player.global_position = Vector3(0, 0.05, -5.5)
	await frames(12)
	assert(get_root().get_node("GameManager").has_staff and player.staff_attachment.visible, "Central staff must equip on contact")
	assert(get_root().get_camera_3d() != null, "Training camera is missing")
	var animation = player.get_node("PlayerAnimationController")
	var jester_skeleton := player.get_node("ModelRoot/Jester/world/Skeleton3D") as Skeleton3D
	var jester_mesh := jester_skeleton.get_node("JesterMesh") as MeshInstance3D
	assert(animation._skeleton == jester_skeleton, "Jester animation must target its imported rig")
	assert(jester_skeleton.get_bone_count() == 7 and jester_mesh.skin != null, "Jester mesh must be skinned")
	var left_arm := jester_skeleton.find_bone(&"LeftArm")
	var right_arm := jester_skeleton.find_bone(&"RightArm")
	assert(jester_skeleton.get_bone_pose_rotation(left_arm).get_euler().z > 0.7, "Idle left arm must leave T-pose")
	assert(jester_skeleton.get_bone_pose_rotation(right_arm).get_euler().z < -0.7, "Idle right arm must leave T-pose")
	assert((jester_mesh.material_override as StandardMaterial3D).vertex_color_use_as_albedo, "Jester costume must show its vertex colors")
	animation.notify_dodge_started(0.34)
	await frames(5)
	assert(animation._dodge_time > 0.0, "Animation timers must progress")
	var hitbox = player.get_node("Hitboxes/LightHitbox")
	var health_before = player.health.current_health
	hitbox.begin_attack()
	hitbox._on_area_entered(player.get_node("Hurtbox"))
	assert(player.health.current_health == health_before, "Own hitbox must not hurt player")
	hitbox.end_attack()
	# Tutorial: progresso depende de alvo adquirido e golpes que acertaram.
	var training_room = current_scene
	# Aguardar dummies entrarem no grupo (headless pode precisar de frames extras para _ready)
	await frames(12)
	var dummies = get_nodes_in_group("training_dummies")
	# Filtrar apenas dummies da cena atual (evita lixo de runs anteriores)
	var current_dummies = []
	for dummy in dummies:
		if dummy.get_parent() == training_room:
			current_dummies.append(dummy)
	if current_dummies.size() < 2:
		# Fallback: buscar por nome dos nodes
		current_dummies = []
		for i in 2:
			var dummy = training_room.get_node_or_null("Dummy%d" % i)
			if dummy != null:
				current_dummies.append(dummy)
	dummies = current_dummies
	assert(dummies.size() >= 2, "Tutorial needs two passive targets")
	assert(training_room.completed.is_empty(), "Tutorial must wait for player actions")
	player.position = Vector3(-3, 0.05, 4.5)
	player.rotation.y = 0.0
	await frames(8)
	player.lock_on.acquire_target()
	await frames(2)
	assert(training_room.completed.has("lock"), "Lock lesson must react to target acquisition")
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	await frames(30)
	assert(training_room.completed.has("light"), "Light lesson must require a landed hit")
	player.combat._start_attack(player.combat.HEAVY, 0)
	await frames(45)
	assert(training_room.completed.has("heavy"), "Heavy lesson must require a landed hit")
	assert(dummies[0].is_alive() and dummies[1].is_alive(), "Training targets must survive")
	assert(player.health.current_health == health_before, "Training targets must not attack")
	Input.action_press("jump")
	Input.action_press("ui_accept")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("ui_accept")
	assert(current_scene == training_room, "Jump/confirm must never leave the training area")
	assert(training_room.has_node("FogGate"), "The route to the city must be visible in the training area")
	player.combat.cancel_attack()
	player.global_position = Vector3(0, 0.05, 18.35)
	player.velocity = Vector3.ZERO
	await frames(5)
	assert(get_root().get_node("AreaTransition").is_travelling, "Crossing the fog gate must start the transition")
	await create_timer(2.0).timeout
	await frames(15)
	assert(current_scene.scene_file_path == "res://scenes/levels/main.tscn", "Crossing the fog gate must open the city")
	player = current_scene.get_node("Player")
	assert(player.is_on_floor(), "City floor must hold the player")
	assert(player.staff_attachment.visible and get_root().get_node("GameManager").has_staff, "The staff must remain equipped after crossing")
	assert(not get_root().get_node("AreaTransition").is_travelling, "The fog must clear after arrival")
	# Cidade: valida dano, estado de morte e reinício automático.
	var enemies = get_nodes_in_group("enemies")
	assert(not enemies.is_empty(), "City must contain enemies")
	for enemy in enemies:
		enemy.set_physics_process(false)
	var enemy = enemies[0]
	player.rotation.y = 0.0
	enemy.global_position = player.global_position + Vector3(0, 0, 1.5)
	var enemy_health = enemy.health.current_health
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	await frames(30)
	assert(enemy.health.current_health < enemy_health, "Real attack must damage an overlapping enemy")
	assert(player.health.current_health == player.health.max_health, "Attack must not hurt its owner")
	player.lock_on.current_target = enemy
	enemy.global_position = player.global_position + Vector3(100, 0, 0)
	assert(player.lock_on.get_target() == null, "Out-of-range target must clear")
	hitbox = player.get_node("Hitboxes/LightHitbox")
	hitbox.damage = 10000.0
	assert(enemy.receive_hitbox(hitbox))
	assert(enemy.get_state_name() == "DEAD", "Lethal hit must preserve enemy DEAD state")
	var attack = enemies[1].get_node("AttackHitbox")
	attack.damage = 10000.0
	assert(player.receive_hitbox(attack))
	assert(player.get_state_name() == "DEAD", "Lethal hit must preserve player DEAD state")
	await create_timer(2.5).timeout
	await frames(10)
	assert(current_scene.get_node("Player").is_alive(), "Player must respawn after death")
	print("PASS: floor, camera, animation timers, self-hit protection, fog-gate transition, lock range, lethal hits, respawn")
	quit()
