extends SceneTree

## Verifica o aviso contextual e a conversa compartilhados entre NPCs.

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(12.0).timeout
	push_error("NPC interaction test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(30)
	var player = current_scene.get_node("Player")
	var mentor := current_scene.get_node("Mentor") as Node3D
	var interaction := root.get_node("NpcInteraction")
	assert(interaction.get_current_npc() == null, "Distant NPC must not be selected")
	player.global_position = mentor.global_position + mentor.global_basis.z * 1.5
	await _frames(35)
	assert(interaction.get_current_npc() == mentor, "Nearby mentor must be selected")
	assert(interaction.prompt_panel.visible, "Nearby mentor must show a prompt")
	assert(interaction.prompt_label.text.contains("O Contrarregra"), "Prompt must show the NPC name")
	assert(interaction.try_interact(), "Nearby NPC must open a conversation")
	assert(interaction.is_dialogue_active(), "Dialogue must become active")
	assert(interaction.dialogue_box.text_label.text == "Não vim ensinar você a vencer. Vim descobrir o que fará quando puder.", "Approved line must be exact")
	assert(not player.is_physics_processing(), "Player movement must pause during dialogue")
	assert(interaction.dialogue_box.text_label.visible_characters == 0, "Dialogue should reveal text progressively")
	await _frames(3)
	assert(root.get_visible_rect().grow(1).encloses(interaction.dialogue_box.dialogue_panel.get_global_rect()), "Dialogue must fit the default viewport")
	interaction.dialogue_box.advance_dialogue()
	assert(interaction.dialogue_box.text_label.visible_characters == -1, "First press should finish the current line")
	for dims in [Vector2i(320, 568), Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = dims
		await _frames(5)
		var panel := interaction.dialogue_box.dialogue_panel as Control
		assert(root.get_visible_rect().grow(1).encloses(panel.get_global_rect()), "Dialogue must fit %s" % dims)
	root.size = Vector2i(320, 568)
	await _frames(5)
	interaction.dialogue_box.close_dialogue()
	assert(not interaction.is_dialogue_active(), "Dialogue must close")
	assert(player.is_physics_processing(), "Player movement must resume")
	assert(interaction.try_interact(), "NPC must support repeat conversations")
	assert(interaction.dialogue_box.text_label.text == "Não vim ensinar você a vencer. Vim descobrir o que fará quando puder.", "Repeat conversation must use the same single line")
	interaction.dialogue_box.close_dialogue()

	var second_npc := load("res://scenes/npc/contrarregra.tscn").instantiate() as Node3D
	current_scene.add_child(second_npc)
	second_npc.global_position = player.global_position + Vector3(0, 0, 0.5)
	await _frames(3)
	assert(interaction.get_current_npc() == second_npc, "Nearest NPC must be selected automatically")
	assert(interaction.try_interact(), "A newly placed NPC must use the same dialogue UI")
	second_npc.queue_free()
	await _frames(3)
	assert(not interaction.is_dialogue_active(), "Dialogue must close if its NPC leaves the scene")
	assert(player.is_physics_processing(), "Player must resume when an NPC disappears")
	assert(interaction.get_current_npc() == mentor, "Selection must recover when an NPC leaves")
	print("PASS: reusable NPC prompt, dialogue, repeat, nearest selection and cleanup")
	quit()
