extends CanvasLayer

## Persistent pause overlay and centralized player settings.

const RESOLUTIONS := [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var settings_path: String = "user://video_settings.cfg"
var _windowed_size: Vector2i
var _active_mode: Window.Mode = Window.MODE_WINDOWED
var _screen_index: int = 0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _resolutions: Array[Vector2i] = []
var _from_title := false
var _vsync_enabled := true
var _tab_buttons: Array[Button] = []
var _tab_pages: Array[VBoxContainer] = []
var _volume_sliders: Dictionary = {}
var _vsync_selector: OptionButton
var _fps_selector: OptionButton
var _sensitivity_slider: HSlider

@onready var overlay: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var pause_page: VBoxContainer = $Root/Panel/Margin/Content/PausePage
@onready var options_page: VBoxContainer = $Root/Panel/Margin/Content/OptionsPage
@onready var controls_page: VBoxContainer = $Root/Panel/Margin/Content/ControlsPage
@onready var controls_rows: VBoxContainer = $Root/Panel/Margin/Content/ControlsPage/List/Rows
@onready var resume_button: Button = $Root/Panel/Margin/Content/PausePage/ResumeButton
@onready var options_button: Button = $Root/Panel/Margin/Content/PausePage/OptionsButton
@onready var controls_button: Button = $Root/Panel/Margin/Content/PausePage/ControlsButton
@onready var title_button: Button = $Root/Panel/Margin/Content/PausePage/TitleButton
@onready var quit_button: Button = $Root/Panel/Margin/Content/PausePage/QuitButton
@onready var monitor_selector: OptionButton = $Root/Panel/Margin/Content/OptionsPage/MonitorSelector
@onready var mode_selector: OptionButton = $Root/Panel/Margin/Content/OptionsPage/ModeSelector
@onready var resolution_selector: OptionButton = $Root/Panel/Margin/Content/OptionsPage/ResolutionSelector
@onready var resolution_hint: Label = $Root/Panel/Margin/Content/OptionsPage/ResolutionHint
@onready var monitor_label: Label = $Root/Panel/Margin/Content/OptionsPage/MonitorLabel
@onready var back_button: Button = $Root/Panel/Margin/Content/OptionsPage/BackButton
@onready var controls_back_button: Button = $Root/Panel/Margin/Content/ControlsPage/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	_windowed_size = get_window().size
	_active_mode = get_window().mode
	_vsync_enabled = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_screen_index = clampi(get_window().current_screen, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	if _active_mode not in [Window.MODE_WINDOWED, Window.MODE_EXCLUSIVE_FULLSCREEN, Window.MODE_FULLSCREEN]:
		_active_mode = Window.MODE_WINDOWED
	if _windowed_size.x < 640 or _windowed_size.y < 360:
		_windowed_size = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/window_width_override", 1280)),
			int(ProjectSettings.get_setting("display/window/size/window_height_override", 720))
		)
	for control: Button in [resume_button, options_button, controls_button, title_button, quit_button, back_button, controls_back_button, monitor_selector, mode_selector, resolution_selector]:
		_style_control(control)
	resume_button.pressed.connect(resume_game)
	options_button.pressed.connect(show_options)
	controls_button.pressed.connect(show_controls)
	title_button.pressed.connect(return_to_title)
	quit_button.pressed.connect(_quit_game)
	back_button.pressed.connect(_on_back_pressed)
	controls_back_button.pressed.connect(_on_back_pressed)
	monitor_selector.item_selected.connect(_on_monitor_selected)
	mode_selector.item_selected.connect(_on_mode_selected)
	resolution_selector.item_selected.connect(_on_resolution_selected)
	mode_selector.add_item("Modo janela", Window.MODE_WINDOWED)
	mode_selector.add_item("Tela cheia", Window.MODE_EXCLUSIVE_FULLSCREEN)
	mode_selector.add_item("Tela cheia em janela", Window.MODE_FULLSCREEN)
	_setup_options_pages()
	_ensure_audio_buses()
	_rebuild_monitors()
	_load_settings()
	_rebuild_resolutions()
	_sync_controls()
	get_window().size_changed.connect(_layout_panel)
	_layout_panel.call_deferred()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu") or event.is_echo():
		return
	if NpcInteraction.is_dialogue_active():
		return
	if AreaTransition.is_travelling:
		return
	if not overlay.visible and is_instance_valid(get_tree().current_scene) and get_tree().current_scene.is_in_group("title_screen"):
		return
	get_viewport().set_input_as_handled()
	if not overlay.visible:
		open_pause()
	elif options_page.visible or controls_page.visible:
		_on_back_pressed()
	else:
		resume_game()


func open_pause() -> void:
	if overlay.visible:
		return
	if _active_mode == Window.MODE_WINDOWED:
		_windowed_size = get_window().size
		_screen_index = clampi(get_window().current_screen, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	_rebuild_monitors()
	_rebuild_resolutions()
	_sync_controls()
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	_show_pause_page()
	get_tree().paused = not _from_title
	resume_button.grab_focus()

## Reaproveita as opções de vídeo no menu principal sem exibir a página de pausa.
func open_title_options() -> void:
	if overlay.visible:
		return
	_from_title = true
	open_pause()
	show_options()

func open_title_controls() -> void:
	if overlay.visible:
		return
	_from_title = true
	open_pause()
	show_controls()


func resume_game() -> void:
	if not overlay.visible:
		return
	_hide_popups()
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
	_from_title = false

func return_to_title() -> void:
	if not overlay.visible or _from_title:
		return
	_hide_popups()
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_from_title = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/title_screen.tscn")


func show_options() -> void:
	pause_page.visible = false
	controls_page.visible = false
	options_page.visible = true
	_sync_controls()
	_show_tab(0)
	_layout_panel.call_deferred()
	mode_selector.grab_focus()

func show_controls() -> void:
	_populate_controls()
	pause_page.visible = false
	options_page.visible = false
	controls_page.visible = true
	_layout_panel.call_deferred()
	controls_back_button.grab_focus()


func _show_pause_page() -> void:
	_hide_popups()
	options_page.visible = false
	controls_page.visible = false
	pause_page.visible = true
	_layout_panel.call_deferred()
	resume_button.grab_focus()

func _on_back_pressed() -> void:
	if _from_title:
		resume_game()
	else:
		_show_pause_page()


func _hide_popups() -> void:
	monitor_selector.get_popup().hide()
	mode_selector.get_popup().hide()
	resolution_selector.get_popup().hide()
	if _vsync_selector != null:
		_vsync_selector.get_popup().hide()
	if _fps_selector != null:
		_fps_selector.get_popup().hide()

func _populate_controls() -> void:
	for child in controls_rows.get_children():
		controls_rows.remove_child(child)
		child.queue_free()
	_add_controls_heading("MOVIMENTO")
	for entry in [["Frente", &"move_forward"], ["Trás", &"move_back"], ["Esquerda", &"move_left"], ["Direita", &"move_right"], ["Pular / parede", &"jump"], ["Esquivar", &"dodge"]]:
		_add_control_row(entry[0], _binding_text(entry[1]))
	_add_control_row("Olhar ao redor", "Mover mouse")
	_add_control_row("Aproximar câmera", "Roda para cima")
	_add_control_row("Afastar câmera", "Roda para baixo")
	_add_controls_heading("COMBATE E INTERAÇÃO")
	for entry in [["Golpe leve", &"light_attack"], ["Golpe pesado", &"heavy_attack"], ["Focar alvo", &"lock_on"], ["Baralho Maldito", &"spell_q"], ["Conversar / avançar", &"interact"]]:
		_add_control_row(entry[0], _binding_text(entry[1]))
	_add_controls_heading("EQUIPAMENTO")
	for entry in [["Cajado", &"weapon_staff"], ["Adagas de Cartas", &"weapon_daggers"], ["Máscara do Riso", &"mask_laugh"]]:
		_add_control_row(entry[0], _binding_text(entry[1]))
	_add_controls_heading("MENUS")
	_add_control_row("Pausa / voltar", _binding_text(&"pause_menu"))
	_add_control_row("Debug de combate", _binding_text(&"debug_toggle"))
	_add_control_row("Navegar na TV", "↑ / ↓ ou W / S")
	_add_control_row("Confirmar na TV", "Enter / Espaço")
	_add_control_row("Selecionar na TV", "Mouse esquerdo")

func _add_controls_heading(title: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.77, 0.63, 0.43))
	heading.custom_minimum_size.y = 29
	controls_rows.add_child(heading)

func _add_control_row(label_text: String, binding: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	controls_rows.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var key_label := Label.new()
	key_label.text = binding
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.add_theme_color_override("font_color", Color(0.94, 0.8, 0.59))
	row.add_child(key_label)
	var right_padding := Control.new()
	right_padding.custom_minimum_size.x = 8
	row.add_child(right_padding)

func _binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		var name := ""
		if event is InputEventKey:
			var key := event as InputEventKey
			name = OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
		elif event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: name = "Mouse esquerdo"
				MOUSE_BUTTON_RIGHT: name = "Mouse direito"
				MOUSE_BUTTON_MIDDLE: name = "Mouse do meio"
				_: name = event.as_text()
		else:
			name = event.as_text()
		if not name.is_empty() and not names.has(name):
			names.append(name)
	return " / ".join(names) if not names.is_empty() else "—"

func _setup_options_pages() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "CategoryTabs"
	tabs.add_theme_constant_override("separation", 8)
	options_page.add_child(tabs)
	options_page.move_child(tabs, 1)
	for category in ["VÍDEO", "QUALIDADE", "ÁUDIO", "JOGABILIDADE"]:
		var button := Button.new()
		button.text = category
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		_style_control(button)
		tabs.add_child(button)
		_tab_buttons.append(button)
		button.pressed.connect(_show_tab.bind(_tab_buttons.size() - 1))
	for category in ["Video", "Quality", "Audio", "Gameplay"]:
		var page := VBoxContainer.new()
		page.name = category + "Settings"
		page.add_theme_constant_override("separation", 10)
		options_page.add_child(page)
		options_page.move_child(page, 2 + _tab_pages.size())
		_tab_pages.append(page)
	
	# VÍDEO tab (index 0)
	for control in [monitor_label, monitor_selector, $Root/Panel/Margin/Content/OptionsPage/ModeLabel, mode_selector, $Root/Panel/Margin/Content/OptionsPage/ResolutionLabel, resolution_selector, resolution_hint]:
		control.reparent(_tab_pages[0])
	_vsync_selector = _add_selector(_tab_pages[0], "VSync", ["Desligado", "Ligado"])
	_vsync_selector.item_selected.connect(_on_vsync_selected)
	_fps_selector = _add_selector(_tab_pages[0], "Limite de FPS", ["30", "60", "120", "Ilimitado"])
	_fps_selector.item_selected.connect(func(index: int) -> void:
		var new_fps: int = [30, 60, 120, 0][index]
		Engine.max_fps = new_fps
		if GameManager.has_method("_set_user_max_fps"):
			GameManager._set_user_max_fps(new_fps)
		_save_settings()
	)
	
	# QUALIDADE tab (index 1)
	_setup_quality_page(_tab_pages[1])
	
	# ÁUDIO tab (index 2)
	for bus_name in ["Master", "Music", "SFX"]:
		var display_name: String = {"Master": "Volume geral", "Music": "Música", "SFX": "Efeitos sonoros"}[bus_name]
		var slider := _add_slider(_tab_pages[2], display_name, 0.0, 100.0, 1.0)
		_volume_sliders[bus_name] = slider
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
	
	# JOGABILIDADE tab (index 3)
	_sensitivity_slider = _add_slider(_tab_pages[3], "Sensibilidade da câmera", 20.0, 200.0, 5.0)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	_show_tab(0)

func _setup_quality_page(page: VBoxContainer) -> void:
	# Graphics Preset Selector
	var preset_selector := _add_selector(page, "Preset Gráfico", ["LOW", "MEDIUM", "HIGH", "ULTRA", "CUSTOM"])
	preset_selector.item_selected.connect(_on_preset_selected)
	
	# Render Scale
	var render_scale_slider := _add_slider(page, "Render Scale", 50.0, 100.0, 5.0)
	render_scale_slider.value_changed.connect(_on_render_scale_changed)
	
	# MSAA 3D
	var msaa_selector := _add_selector(page, "MSAA 3D", ["Desligado", "2x", "4x", "8x"])
	msaa_selector.item_selected.connect(_on_msaa_changed)
	
	# FXAA
	var fxaa_selector := _add_selector(page, "FXAA", ["Desligado", "Ligado"])
	fxaa_selector.item_selected.connect(_on_fxaa_changed)
	
	# Anisotropic Filtering
	var aniso_selector := _add_selector(page, "Filtro Anisotrópico", ["Desligado", "2x", "4x", "8x", "16x"])
	aniso_selector.item_selected.connect(_on_aniso_changed)
	
	# Shadow Quality
	var shadow_selector := _add_selector(page, "Qualidade de Sombras", ["Baixa", "Média", "Alta"])
	shadow_selector.item_selected.connect(_on_shadow_quality_changed)
	
	# SSAO
	var ssao_selector := _add_selector(page, "SSAO", ["Desligado", "Ligado"])
	ssao_selector.item_selected.connect(_on_ssao_changed)
	
	# SSIL
	var ssil_selector := _add_selector(page, "SSIL", ["Desligado", "Ligado"])
	ssil_selector.item_selected.connect(_on_ssil_changed)
	
	# Volumetric Fog Quality
	var fog_selector := _add_selector(page, "Qualidade do Fog Volumétrico", ["Baixa", "Média", "Alta", "Ultra"])
	fog_selector.item_selected.connect(_on_fog_quality_changed)
	
	# Glow/Bloom
	var glow_selector := _add_selector(page, "Glow/Bloom", ["Desligado", "Ligado"])
	glow_selector.item_selected.connect(_on_glow_changed)
	
	# Restore Defaults Button
	var restore_btn := Button.new()
	restore_btn.text = "Restaurar Padrões (HIGH)"
	restore_btn.custom_minimum_size.y = 44
	_style_control(restore_btn)
	restore_btn.pressed.connect(_on_restore_defaults)
	page.add_child(restore_btn)

func _add_selector(page: VBoxContainer, label_text: String, choices: Array[String]) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	page.add_child(label)
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 44
	_style_control(selector)
	page.add_child(selector)
	for choice in choices:
		selector.add_item(choice)
	return selector

func _add_slider(page: VBoxContainer, label_text: String, low: float, high: float, step_size: float) -> HSlider:
	var row := HBoxContainer.new()
	page.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.custom_minimum_size.y = 30
	_style_slider(slider)
	page.add_child(slider)
	slider.set_meta("value_label", value_label)
	slider.value_changed.connect(func(value: float) -> void: value_label.text = "%d%%" % roundi(value))
	return slider

func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.16, 0.24)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.73, 0.56, 0.33)
	fill.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var pixels := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var radius := Vector2(x - 7.5, y - 7.5).length()
			pixels.set_pixel(x, y, Color(0.91, 0.77, 0.53) if radius < 6.5 else Color.TRANSPARENT)
	var handle := ImageTexture.create_from_image(pixels)
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)

func _show_tab(index: int) -> void:
	for i in _tab_pages.size():
		_tab_pages[i].visible = i == index
		_tab_buttons[i].modulate = Color(1.0, 0.85, 0.58) if i == index else Color(0.78, 0.82, 0.9)
	$Root/Panel/Margin/Content/OptionsPage/Title.text = ["VÍDEO", "QUALIDADE", "ÁUDIO", "JOGABILIDADE"][index]
	_layout_panel.call_deferred()

func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _on_volume_changed(value: float, bus_name: String) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	_on_volume_changed_without_save(value, bus_name)
	_save_settings()

func _on_sensitivity_changed(value: float) -> void:
	var new_sensitivity := 0.0028 * value / 100.0
	GameManager.set_camera_sensitivity(new_sensitivity)
	_save_settings()

func _on_vsync_selected(index: int) -> void:
	_vsync_enabled = index == 1
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
	_save_settings()


func _on_monitor_selected(index: int) -> void:
	if index < 0 or index >= DisplayServer.get_screen_count():
		return
	_screen_index = index
	if _active_mode == Window.MODE_WINDOWED:
		var usable := DisplayServer.screen_get_usable_rect(index).size
		if usable != Vector2i.ZERO and (_windowed_size.x > usable.x or _windowed_size.y > usable.y):
			_windowed_size = Vector2i(1280, 720)
			for candidate: Vector2i in RESOLUTIONS:
				if candidate.x <= usable.x and candidate.y <= usable.y:
					_windowed_size = candidate
	_apply_mode(_active_mode)
	_rebuild_resolutions()
	_sync_controls()
	_save_settings()


func _on_mode_selected(index: int) -> void:
	var mode := mode_selector.get_item_id(index) as Window.Mode
	if _active_mode == Window.MODE_WINDOWED:
		_windowed_size = get_window().size
	_apply_mode(mode)
	_save_settings()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _resolutions.size():
		return
	_windowed_size = _resolutions[index]
	if _active_mode == Window.MODE_WINDOWED:
		var best_screen := _find_screen_for_size(_windowed_size)
		if best_screen != _screen_index:
			_screen_index = best_screen
			get_window().current_screen = _screen_index
		get_window().size = _windowed_size
		_center_window()
	_sync_controls()
	_save_settings()


func _apply_mode(mode: Window.Mode) -> void:
	if mode not in [Window.MODE_WINDOWED, Window.MODE_EXCLUSIVE_FULLSCREEN, Window.MODE_FULLSCREEN]:
		return
	_active_mode = mode
	var window := get_window()
	if window.current_screen != _screen_index and window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.current_screen = _screen_index
	window.mode = mode
	if mode == Window.MODE_WINDOWED:
		window.borderless = false
		window.size = _windowed_size
		_center_window()
	_sync_controls()


func _center_window() -> void:
	var usable := DisplayServer.screen_get_usable_rect(_screen_index)
	if usable.size.x > 0 and usable.size.y > 0:
		get_window().position = usable.position + (usable.size - _windowed_size) / 2


func _find_screen_for_size(size: Vector2i) -> int:
	var sizes: Array[Vector2i] = []
	for index in DisplayServer.get_screen_count():
		sizes.append(DisplayServer.screen_get_size(index))
	return _choose_screen_for_size(size, sizes, _screen_index, DisplayServer.get_primary_screen())


func _choose_screen_for_size(size: Vector2i, sizes: Array[Vector2i], current: int, primary: int) -> int:
	if sizes.is_empty():
		return current
	if current >= 0 and current < sizes.size() and (size.x <= sizes[current].x and size.y <= sizes[current].y):
		return current
	if primary >= 0 and primary < sizes.size() and (size.x <= sizes[primary].x and size.y <= sizes[primary].y):
		return primary
	for index in sizes.size():
		if size.x <= sizes[index].x and size.y <= sizes[index].y:
			return index
	return current


func _rebuild_monitors() -> void:
	monitor_selector.clear()
	for index in maxi(1, DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(index)
		var label := "Monitor %d" % (index + 1)
		if size != Vector2i.ZERO:
			label += "  •  %d × %d" % [size.x, size.y]
		monitor_selector.add_item(label, index)
	monitor_selector.visible = monitor_selector.item_count > 1
	monitor_label.visible = monitor_selector.visible


func _rebuild_resolutions() -> void:
	resolution_selector.clear()
	var screen_sizes: Array[Vector2i] = []
	for index in DisplayServer.get_screen_count():
		screen_sizes.append(DisplayServer.screen_get_size(index))
	if screen_sizes.is_empty():
		screen_sizes.append(Vector2i.ZERO)
	_resolutions = _resolutions_for_screens(screen_sizes)
	for screen_size: Vector2i in screen_sizes:
		if screen_size.x >= 640 and screen_size.y >= 360 and not _resolutions.has(screen_size):
			_resolutions.append(screen_size)
	if not _resolutions.has(_windowed_size):
		_resolutions.append(_windowed_size)
	_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	for resolution: Vector2i in _resolutions:
		resolution_selector.add_item("%d × %d" % [resolution.x, resolution.y])


func _resolutions_for_screens(screen_sizes: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for resolution: Vector2i in RESOLUTIONS:
		for screen_size: Vector2i in screen_sizes:
			if screen_size.x < 640 or screen_size.y < 360 or (resolution.x <= screen_size.x and resolution.y <= screen_size.y):
				result.append(resolution)
				break
	return result


func _sync_controls() -> void:
	if _screen_index >= 0 and _screen_index < monitor_selector.item_count:
		monitor_selector.select(_screen_index)
	for index in mode_selector.item_count:
		if mode_selector.get_item_id(index) == _active_mode:
			mode_selector.select(index)
			break
	resolution_selector.disabled = _active_mode != Window.MODE_WINDOWED
	var native_size := DisplayServer.screen_get_size(_screen_index)
	resolution_hint.text = "Escolha o tamanho da janela; resoluções maiores mudam para outro monitor." if _active_mode == Window.MODE_WINDOWED else "Na tela cheia, o jogo usa %d × %d do monitor escolhido." % [native_size.x, native_size.y]
	var shown_size := _windowed_size if _active_mode == Window.MODE_WINDOWED else native_size
	var selected := _resolutions.find(shown_size)
	if selected >= 0:
		resolution_selector.select(selected)
	_vsync_selector.select(1 if _vsync_enabled else 0)
	var fps_index := [30, 60, 120, 0].find(Engine.max_fps)
	_fps_selector.select(fps_index if fps_index >= 0 else 3)
	for bus_name in _volume_sliders:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			var volume := 0.0 if AudioServer.is_bus_mute(bus) else db_to_linear(AudioServer.get_bus_volume_db(bus)) * 100.0
			(_volume_sliders[bus_name] as HSlider).set_value_no_signal(volume)
			(_volume_sliders[bus_name] as HSlider).get_meta("value_label").text = "%d%%" % roundi(volume)
	_sensitivity_slider.set_value_no_signal(GameManager.camera_sensitivity / 0.0028 * 100.0)
	_sensitivity_slider.get_meta("value_label").text = "%d%%" % roundi(_sensitivity_slider.value)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var size_value: Variant = config.get_value("video", "windowed_size", _windowed_size)
	if size_value is Vector2i and size_value.x >= 640 and size_value.y >= 360:
		_windowed_size = size_value
	var saved_screen := int(config.get_value("video", "screen_index", _screen_index))
	if saved_screen >= 0 and saved_screen < DisplayServer.get_screen_count():
		_screen_index = saved_screen
	var mode_value := int(config.get_value("video", "mode", Window.MODE_WINDOWED))
	if mode_value in [Window.MODE_WINDOWED, Window.MODE_EXCLUSIVE_FULLSCREEN, Window.MODE_FULLSCREEN]:
		_apply_mode(mode_value as Window.Mode)
	_vsync_enabled = bool(config.get_value("video", "vsync", _vsync_enabled))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
	var fps := int(config.get_value("video", "fps_limit", Engine.max_fps))
	if fps in [0, 30, 60, 120]:
		Engine.max_fps = fps
		if GameManager.has_method("_set_user_max_fps"):
			GameManager._set_user_max_fps(fps)
	for bus_name in _volume_sliders:
		var volume := clampf(float(config.get_value("audio", bus_name.to_lower(), 100.0)), 0.0, 100.0)
		_on_volume_changed_without_save(volume, bus_name)
	var sens_percent := float(config.get_value("gameplay", "camera_sensitivity_percent", 100.0))
	sens_percent = clampf(sens_percent, 20.0, 200.0)
	GameManager.set_camera_sensitivity(0.0028 * sens_percent / 100.0)
	_sync_controls()

func _on_volume_changed_without_save(value: float, bus_name: String) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, value <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value / 100.0, 0.001)))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "mode", _active_mode)
	config.set_value("video", "windowed_size", _windowed_size)
	config.set_value("video", "screen_index", _screen_index)
	config.set_value("video", "vsync", _vsync_enabled)
	config.set_value("video", "fps_limit", Engine.max_fps)
	for bus_name in _volume_sliders:
		config.set_value("audio", bus_name.to_lower(), (_volume_sliders[bus_name] as HSlider).value)
	config.set_value("gameplay", "camera_sensitivity_percent", GameManager.camera_sensitivity / 0.0028 * 100.0)
	var result := config.save(settings_path)
	if result != OK:
		push_warning("Não foi possível salvar as configurações: %s" % error_string(result))


func _layout_panel() -> void:
	if not is_node_ready():
		return
	var available := get_viewport().get_visible_rect().size
	var desired := panel.get_combined_minimum_size()
	var factor := minf(1.0, minf((available.x - 24.0) / desired.x, (available.y - 24.0) / desired.y))
	factor = maxf(0.25, factor)
	panel.size = desired
	panel.scale = Vector2.ONE * factor
	panel.position = (available - desired * factor) * 0.5


func _style_control(control: Button) -> void:
	control.add_theme_font_size_override("font_size", 17)
	control.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.15, 0.23) if state == "normal" else Color(0.15, 0.27, 0.37)
		style.border_color = Color(0.28, 0.47, 0.6) if state == "normal" else Color(0.67, 0.79, 0.91)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 14
		style.content_margin_right = 14
		control.add_theme_stylebox_override(state, style)


func _on_preset_selected(index: int) -> void:
	if not GraphicsSettings.has_method("apply_preset"):
		return
	GraphicsSettings.apply_preset(index)
	_sync_quality_controls()
	_save_settings()

func _on_render_scale_changed(value: float) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("render_scale", value / 100.0)
	_save_settings()

func _on_msaa_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("msaa_3d", index)
	_save_settings()

func _on_fxaa_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("fxaa", index == 1)
	_save_settings()

func _on_aniso_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("anisotropic_filter", index)
	_save_settings()

func _on_shadow_quality_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("shadow_quality", index)
	_save_settings()

func _on_ssao_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("ssao_enabled", index == 1)
	_save_settings()

func _on_ssil_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("ssil_enabled", index == 1)
	_save_settings()

func _on_fog_quality_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("volumetric_fog_quality", index)
	_save_settings()

func _on_glow_changed(index: int) -> void:
	if not GraphicsSettings.has_method("set_setting"):
		return
	GraphicsSettings.set_setting("glow_enabled", index == 1)
	_save_settings()

func _on_restore_defaults() -> void:
	if not GraphicsSettings.has_method("restore_defaults"):
		return
	GraphicsSettings.restore_defaults()
	_sync_quality_controls()
	_save_settings()

func _sync_quality_controls() -> void:
	if not GraphicsSettings.has_method("get_current_preset_name") or not GraphicsSettings.has_method("get_effective_value"):
		return
	
	# Sync preset selector (first child after preset label)
	var quality_page := _tab_pages[1]
	var preset_selector := quality_page.get_child(1) as OptionButton
	if preset_selector:
		preset_selector.select(["LOW", "MEDIUM", "HIGH", "ULTRA", "CUSTOM"].find(GraphicsSettings.get_current_preset_name()))
	
	# Sync other controls based on effective values
	var render_scale_slider := quality_page.get_child(3) as HSlider
	if render_scale_slider:
		render_scale_slider.set_value_no_signal(GraphicsSettings.get_effective_value("render_scale") * 100.0)
	
	var msaa_selector := quality_page.get_child(5) as OptionButton
	if msaa_selector:
		msaa_selector.select(GraphicsSettings.get_effective_value("msaa_3d"))
	
	var fxaa_selector := quality_page.get_child(7) as OptionButton
	if fxaa_selector:
		fxaa_selector.select(1 if GraphicsSettings.get_effective_value("fxaa") else 0)
	
	var aniso_selector := quality_page.get_child(9) as OptionButton
	if aniso_selector:
		aniso_selector.select(GraphicsSettings.get_effective_value("anisotropic_filter"))
	
	var shadow_selector := quality_page.get_child(11) as OptionButton
	if shadow_selector:
		shadow_selector.select(GraphicsSettings.get_effective_value("shadow_quality"))
	
	var ssao_selector := quality_page.get_child(13) as OptionButton
	if ssao_selector:
		ssao_selector.select(1 if GraphicsSettings.get_effective_value("ssao_enabled") else 0)
	
	var ssil_selector := quality_page.get_child(15) as OptionButton
	if ssil_selector:
		ssil_selector.select(1 if GraphicsSettings.get_effective_value("ssil_enabled") else 0)
	
	var fog_selector := quality_page.get_child(17) as OptionButton
	if fog_selector:
		fog_selector.select(GraphicsSettings.get_effective_value("volumetric_fog_quality"))
	
	var glow_selector := quality_page.get_child(19) as OptionButton
	if glow_selector:
		glow_selector.select(1 if GraphicsSettings.get_effective_value("glow_enabled") else 0)

func _quit_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()
