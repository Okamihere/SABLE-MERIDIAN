extends Control

## Interface desenhada dentro da tela 3D da televisão.
signal choice_selected(choice: String)
signal selection_changed(index: int)

const CHOICES := ["new_game", "continue", "options", "controls", "exit"]
const DESCRIPTIONS := [
	"Abra as cortinas para uma nova jornada.",
	"Retorne ao pátio com as orbes que encontrou.",
	"Ajuste a imagem antes do espetáculo.",
	"Conheça os gestos antes de entrar em cena.",
	"Encerre a transmissão por enquanto."
]

@onready var menu: Control = $Menu
@onready var buttons: Array[Button] = [$Menu/NewGame, $Menu/Continue, $Menu/Options, $Menu/Controls, $Menu/Exit]
@onready var description: Label = $Description
@onready var boot_curtain: ColorRect = $BootCurtain
@onready var signal_bar: ColorRect = $SignalBar
@onready var live_label: Label = $Live

var selected_index := 0
var continue_available := false
var _booted := false
var _closing := false
var _disabled_hint_shown := false
var _phase := 0.0
var _cursor: ColorRect
var _cursor_tween: Tween
var _description_tween: Tween
var _boot_tween: Tween
var _style_selected: StyleBoxFlat
var _style_normal: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in buttons.size():
		buttons[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons[index].pressed.connect(_choose.bind(index))
	_cursor = ColorRect.new()
	_cursor.name = "SelectionMark"
	_cursor.color = Color(0.95, 0.65, 0.37)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.position = Vector2(0, 8)
	_cursor.size = Vector2(5, 38)
	menu.add_child(_cursor)
	
	# Cache styles to avoid allocation on every _update_styles call
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.15, 0.28, 0.29, 0.75)
	_style_selected.border_color = Color(0.84, 0.66, 0.43, 0.82)
	_style_selected.set_border_width_all(1)
	_style_selected.set_corner_radius_all(5)
	_style_selected.content_margin_left = 28
	_style_selected.content_margin_right = 16
	
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.04, 0.09, 0.115, 0.44)
	_style_normal.border_color = Color(0.39, 0.57, 0.56, 0.25)
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(5)
	_style_normal.content_margin_left = 28
	_style_normal.content_margin_right = 16
	
	boot_curtain.pivot_offset = size * 0.5
	set_continue_available(false)
	select_index(0, false)
	_play_intro()
	var bar_tween := create_tween().set_loops()
	bar_tween.tween_property(signal_bar, "size:x", 160.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bar_tween.tween_property(signal_bar, "size:x", 37.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	_phase += delta
	live_label.modulate.a = 0.68 + 0.32 * sin(_phase * 3.4)

func set_continue_available(available: bool) -> void:
	continue_available = available
	if is_node_ready():
		buttons[1].disabled = not available
		_update_styles()
		if not available and selected_index == 1:
			select_index(0)

func select_index(index: int, animate: bool = true) -> void:
	if index < 0 or index >= buttons.size():
		return
	if index == 1 and not continue_available:
		return
	var changed := selected_index != index
	selected_index = index
	_update_styles()
	if not is_node_ready():
		return
	if is_instance_valid(_cursor_tween):
		_cursor_tween.kill()
	var target_y := buttons[index].position.y + 8.0
	if animate and _booted:
		_cursor_tween = create_tween()
		_cursor_tween.tween_property(_cursor, "position:y", target_y, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_cursor.position.y = target_y
	if changed:
		if is_instance_valid(_description_tween):
			_description_tween.kill()
		if animate and _booted:
			_description_tween = create_tween()
			_description_tween.tween_property(description, "modulate:a", 0.0, 0.08)
			_description_tween.tween_callback(func() -> void: description.text = DESCRIPTIONS[index])
			_description_tween.tween_property(description, "modulate:a", 1.0, 0.19)
		else:
			description.text = DESCRIPTIONS[index]
		selection_changed.emit(index)

func select_direction(step: int) -> void:
	var index := selected_index
	for _attempt in buttons.size():
		index = wrapi(index + step, 0, buttons.size())
		if index != 1 or continue_available:
			select_index(index)
			return

func point_to_index(point: Vector2) -> int:
	var local_point := point - menu.position
	for index in buttons.size():
		if buttons[index].get_rect().has_point(local_point):
			return index
	return -1

func hover_at(point: Vector2) -> void:
	var index := point_to_index(point)
	if index == 1 and not continue_available:
		if not _disabled_hint_shown:
			if is_instance_valid(_description_tween):
				_description_tween.kill()
			description.modulate.a = 1.0
			description.text = "Nenhuma orbe salva. Comece um novo jogo."
			_disabled_hint_shown = true
		return
	if _disabled_hint_shown:
		description.text = DESCRIPTIONS[selected_index]
		_disabled_hint_shown = false
	if index >= 0:
		select_index(index)

func click_at(point: Vector2) -> bool:
	var index := point_to_index(point)
	if index < 0 or buttons[index].disabled:
		hover_at(point)
		return false
	select_index(index)
	_choose(index)
	return true

func activate_selected() -> void:
	_choose(selected_index)

func _choose(index: int) -> void:
	if _closing or (index == 1 and not continue_available):
		return
	choice_selected.emit(CHOICES[index])

func power_off() -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(_boot_tween):
		_boot_tween.kill()
	boot_curtain.visible = true
	boot_curtain.modulate.a = 0.0
	boot_curtain.scale = Vector2(1.0, 0.005)
	var tween := create_tween()
	tween.tween_property(boot_curtain, "modulate:a", 1.0, 0.08)
	tween.tween_property(boot_curtain, "scale:y", 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _play_intro() -> void:
	boot_curtain.visible = true
	boot_curtain.modulate.a = 1.0
	boot_curtain.scale = Vector2.ONE
	_boot_tween = create_tween()
	_boot_tween.tween_interval(0.22)
	_boot_tween.tween_property(boot_curtain, "scale:y", 0.006, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_boot_tween.tween_property(boot_curtain, "modulate:a", 0.0, 0.18)
	_boot_tween.tween_callback(func() -> void:
		boot_curtain.visible = false
		_booted = true
	)
	for index in buttons.size():
		var button := buttons[index]
		var destination := button.position
		button.position.x += 42.0
		button.modulate.a = 0.0
		var row_tween := create_tween().set_parallel(true)
		row_tween.tween_property(button, "position", destination, 0.46).set_delay(0.48 + index * 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		row_tween.tween_property(button, "modulate:a", 1.0, 0.36).set_delay(0.48 + index * 0.09)

func _update_styles() -> void:
	if not is_node_ready():
		return
	for index in buttons.size():
		var button := buttons[index]
		var selected := index == selected_index
		var disabled := index == 1 and not continue_available
		var style := _style_selected if selected else _style_normal
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("disabled", style)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color(0.98, 0.91, 0.77) if selected else Color(0.77, 0.85, 0.83))
		button.add_theme_color_override("font_disabled_color", Color(0.43, 0.53, 0.53))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if disabled:
			button.disabled = true
