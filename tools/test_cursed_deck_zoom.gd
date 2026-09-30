extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _cards() -> Array:
	return get_nodes_in_group("cursed_cards")

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(15)
	var player := current_scene.get_node("Player")
	var camera := current_scene.get_node("CameraRig")
	assert(is_equal_approx(camera._zoom_distance, camera.base_distance), "Zoom deve começar na distância atual")
	camera.adjust_zoom(-100)
	assert(is_equal_approx(camera._zoom_distance, camera.min_distance), "Zoom próximo deve respeitar limite")
	camera.adjust_zoom(100)
	assert(is_equal_approx(camera._zoom_distance, camera.max_distance), "Zoom distante deve respeitar limite")
	var before: float = camera.spring_arm.spring_length
	await process_frame
	assert(camera.spring_arm.spring_length > before and camera.spring_arm.spring_length < camera.max_distance, "SpringArm deve interpolar sem salto")
	assert(camera.spring_arm.collision_mask == 1, "Colisão da câmera deve permanecer ativa")
	var spell := player.spells[0] as SpellResource
	assert(spell.spell_name == "Baralho Maldito", "Repertório ativo deve ser teatral")
	assert(player.spell_manager._mana == player.mana, "Magia deve usar mana real")
	player.global_position = Vector3(-3, 0.05, 3)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	var dummy := current_scene.get_node("Dummy0")
	var hits := [0]
	dummy.struck.connect(func(_id: StringName) -> void: hits[0] += 1)
	var mana_before: float = player.mana.current_mana
	var style_before: int = root.get_node("GameManager").style_meter.score
	assert(player.spell_manager.cast_spell(spell, player), "Carta deve ser conjurada")
	assert(_cards().size() == 1, "Fora do combo deve sair uma carta")
	assert(is_equal_approx(player.mana.current_mana, mana_before - spell.mana_cost), "Mana deve ser consumida")
	assert(not player.spell_manager.cast_spell(spell, player), "Cooldown deve impedir spam imediato")
	await _frames(25)
	assert(hits[0] >= 1, "Carta deve acertar a hurtbox de treino")
	assert(root.get_node("GameManager").style_meter.score > style_before, "Carta deve pontuar no sistema de estilo")
	await _frames(25)
	player.equip_staff()
	player.combat._start_attack(player.combat.LIGHT_2, 2)
	assert(player.combat.is_attacking(), "Segundo golpe deve estar ativo")
	player._cast_spell(spell)
	assert(_cards().size() == 3, "Combo avançado deve abrir leque de três cartas")
	assert(player.combat.is_attacking(), "Conjuração deve preservar o golpe em curso")
	print("PASS: zoom suave e limitado, mana, cooldown, dano e leque de cartas no combo")
	quit()
