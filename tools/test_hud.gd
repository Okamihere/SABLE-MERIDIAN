extends SceneTree
## Vida/mana reais, sincronização visual e vínculos após a troca de cenas.
func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(15).timeout
	push_error("HUD test timeout")
	quit(1)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await frames(45)
	var player = current_scene.get_node("Player")
	var hud = current_scene.get_node("HUD")
	assert(hud.health_value.text == "100 / 100")
	assert(hud.mana_value.text == "100 / 100")
	player.health.damage(35)
	player.mana.set_physics_process(false)
	assert(player.mana.try_spend(40))
	assert(not player.mana.try_spend(61))
	assert(not player.mana.try_spend(-1))
	assert(not player.mana.try_spend(NAN))
	await frames(20)
	assert(hud.health_value.text == "65 / 100")
	assert(hud.mana_value.text == "60 / 100")
	assert(is_equal_approx(hud.health_bar.value, 65))
	assert(is_equal_approx(hud.mana_bar.value, 60))
	player.mana._physics_process(1.5)
	assert(player.mana.current_mana == 60, "Regen must wait after spending")
	player.mana._physics_process(1)
	assert(player.mana.current_mana == 68, "Mana should regenerate 8 per second")
	player.mana.restore(10000)
	assert(player.mana.current_mana == 100, "Mana must stay capped")
	player.health.heal(15)
	await frames(20)
	assert(hud.health_value.text == "80 / 100")
	assert(hud.mana_value.text == "100 / 100")
	var vitals = hud.get_node("Root/Vitals").get_global_rect()
	var instructions = current_scene.get_node("Instructions/Panel").get_global_rect()
	assert(not vitals.intersects(instructions), "Tutorial must not overlap vitals")
	change_scene_to_file("res://scenes/levels/main.tscn")
	await frames(30)
	hud = current_scene.get_node("HUD")
	player = current_scene.get_node("Player")
	assert(hud._player == player and hud.mana_value.text == "100 / 100")
	player.health.damage(1000)
	assert(not player.mana.regeneration_enabled)
	await create_timer(2.4).timeout
	await frames(5)
	hud = current_scene.get_node("HUD")
	assert(hud.health_value.text == "100 / 100" and hud.mana_value.text == "100 / 100")
	print("PASS: HUD life/mana, damage, heal, spend limits, regen, no overlap, scene binding, death/restart")
	quit()
