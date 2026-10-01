extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(12)
	var player = current_scene.get_node("Player")
	player.equip_staff()
	var dummy := current_scene.get_node("Dummy1")
	var hits := [0]
	dummy.struck.connect(func(_attack_id: StringName) -> void: hits[0] += 1)
	var ids: Array[StringName] = [&"staff", &"card_daggers", &"puppet_strings", &"cane_blade", &"living_grimoire"]
	assert(current_scene.get_node("StaffPickup") != null)
	for id in ids.slice(1):
		var exhibit := current_scene.get_node({&"card_daggers":"DaggersExhibit", &"puppet_strings":"StringsExhibit", &"cane_blade":"CaneExhibit", &"living_grimoire":"GrimoireExhibit"}[id])
		assert(exhibit.weapon_id == id and exhibit.description.contains("Q") and exhibit.description.contains("R"))
	for id in ids:
		assert(player.equipment.request_weapon(id), "Weapon must be available: " + id)
		assert(player.equipment.weapon.is_playable())
		assert(player.equipment.weapon.skills.size() == 3)
		for index in 3:
			player.global_position = Vector3(3, 0.05, 3)
			player.rotation.y = 0.0
			player.velocity = Vector3.ZERO
			player.mana.current_mana = player.mana.max_mana
			var spell: SpellResource = player.equipment.weapon.skills[index]
			assert(spell.effect_scene != null and spell.ability_id != &"")
			var before_hits: int = hits[0]
			assert(player.spell_manager.cast_spell(spell, player), "Skill must cast: " + spell.spell_name)
			assert(not player.spell_manager.cast_spell(spell, player), "Cooldown must hold: " + spell.spell_name)
			await _frames(18)
			if spell.ability_id not in [&"cane_e", &"dagger_e"]:
				assert(hits[0] > before_hits, "Skill must hit training target: " + spell.spell_name)
	for id in ids.slice(1):
		var exhibit := current_scene.get_node({&"card_daggers":"DaggersExhibit", &"puppet_strings":"StringsExhibit", &"cane_blade":"CaneExhibit", &"living_grimoire":"GrimoireExhibit"}[id])
		exhibit._on_body_entered(player)
		assert(player.equipment.weapon.weapon_id == id, "Exhibit must equip: " + id)
	current_scene.get_node("StaffPickup")._on_body_entered(player)
	assert(player.equipment.weapon.weapon_id == &"staff", "Staff pedestal must remain reusable")
	print("PASS: five weapons, four exhibits, 15 distinct Q/E/R skills and cooldowns")
	quit()
