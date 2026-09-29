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
	var player = current_scene.get_node("Player")
	assert(player.is_on_floor(), "Training floor must hold the player")
	assert(get_root().get_camera_3d() != null, "Training camera is missing")
	var animation = player.get_node("PlayerAnimationController")
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
	var dummies = get_nodes_in_group("training_dummies")
	assert(dummies.size() == 2, "Tutorial needs two passive targets")
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
	var input_event = InputEventAction.new()
	input_event.action = "ui_accept"
	input_event.pressed = true
	current_scene._unhandled_input(input_event)
	await frames(90)
	assert(current_scene.scene_file_path == "res://scenes/levels/main.tscn", "Enter must open city")
	player = current_scene.get_node("Player")
	assert(player.is_on_floor(), "City floor must hold the player")
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
	print("PASS: floor, camera, animation timers, self-hit protection, city transition, lock range, lethal hits, respawn")
	quit()
