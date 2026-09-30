extends SceneTree

## Navegação da televisão, opções e distinção entre continuar/novo jogo.
func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Title screen test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var progression = root.get_node("Progression")
	progression.save_path = "user://title_test_%d.cfg" % Time.get_ticks_usec()
	progression.collected.clear()
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(12)
	var title = current_scene
	var ui = title.ui
	assert(ui.buttons.size() == 5 and not ui.continue_available, "Fresh game must disable Continue and show Controls")
	assert(title.screen_mesh.material_override.albedo_texture == title.screen_viewport.get_texture(), "TV must render the menu on its screen")
	for dims in [Vector2i(320, 568), Vector2i(640, 360), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		root.size = dims
		await _frames(8)
		var view := root.get_visible_rect().grow(2)
		for corner in [Vector3(-1.95, -1.37, 0.35), Vector3(1.95, 1.37, 0.35)]:
			var pixel: Vector2 = title.camera.unproject_position(title.tv.to_global(corner))
			assert(view.has_point(pixel), "TV must fit %s" % dims)
	var point := Vector2(510, 313)
	var local := Vector3((point.x / 1000.0 - 0.5) * title.SCREEN_SIZE.x, (0.5 - point.y / 650.0) * title.SCREEN_SIZE.y, 0.0)
	var projected: Vector2 = title.camera.unproject_position(title.screen_mesh.to_global(local))
	assert(title._screen_point(projected).distance_to(point) < 3.0, "Mouse ray must land on the correct TV pixel")
	ui.select_direction(1)
	assert(ui.selected_index == 2, "Navigation should skip unavailable Continue")
	ui.activate_selected()
	assert(root.get_node("PauseMenu").overlay.visible and root.get_node("PauseMenu").options_page.visible, "Options must open from the title")
	root.get_node("PauseMenu")._on_back_pressed()
	assert(not paused and not root.get_node("PauseMenu").overlay.visible, "Back must return to the title")
	assert(current_scene == title, "Options must preserve the title scene")
	ui.select_index(3)
	ui.activate_selected()
	var menu := root.get_node("PauseMenu")
	assert(menu.overlay.visible and menu.controls_page.visible, "Controls must open from the title")
	assert(menu.controls_rows.get_child_count() > 15, "Controls must list current gameplay and menu bindings")
	menu._on_back_pressed()
	assert(not paused and current_scene == title, "Back from controls must restore the title")
	assert(progression.collect("title_test_orb"))
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(8)
	title = current_scene
	ui = title.ui
	assert(ui.continue_available, "Saved orb progress must enable Continue")
	ui.select_index(1)
	ui.activate_selected()
	await create_timer(0.8).timeout
	await _frames(4)
	assert(current_scene.scene_file_path == "res://scenes/levels/start_room.tscn", "Continue should enter the game")
	assert(progression.collected.has("title_test_orb"), "Continue must preserve collected orbs")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(8)
	current_scene.ui.select_index(0)
	current_scene.ui.activate_selected()
	await create_timer(0.8).timeout
	await _frames(4)
	assert(current_scene.scene_file_path == "res://scenes/levels/start_room.tscn", "New Game should enter the game")
	assert(progression.collected.is_empty() and not FileAccess.file_exists(progression.save_path), "New Game must reset orb progress")
	print("PASS: title TV navigation, options, Continue and New Game")
	quit()
