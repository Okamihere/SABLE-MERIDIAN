extends CanvasLayer

## Janela compartilhada pelos NPCs. O NPC fornece as falas; esta classe as apresenta.
signal dialogue_started
signal dialogue_ended
signal dialogue_line_changed(line_text: String, speaker_name: String)

@onready var dialogue_panel: PanelContainer = $Root/DialoguePanel
@onready var veil: ColorRect = $Root/Veil
@onready var speaker_label: Label = $Root/DialoguePanel/Content/VBox/Header/SpeakerName
@onready var text_label: Label = $Root/DialoguePanel/Content/VBox/DialogueText
@onready var hint_label: Label = $Root/DialoguePanel/Content/VBox/Hint

var _current_npc: Node
var _active := false
var _displaying_line := false
var _panel_tween: Tween
var _line_tween: Tween
var _base_position := Vector2.ZERO

func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void: _layout.call_deferred())
	_layout.call_deferred()

func _process(_delta: float) -> void:
	if _active and not is_instance_valid(_current_npc):
		close_dialogue()

func _input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance_dialogue()
	elif event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		close_dialogue()

func start_dialogue(npc: Node) -> void:
	if _active or not is_instance_valid(npc):
		return
	_current_npc = npc
	_active = true
	if is_instance_valid(_panel_tween):
		_panel_tween.kill()
	_layout()
	veil.visible = true
	veil.modulate.a = 0.0
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	dialogue_panel.scale = Vector2(0.97, 0.97)
	dialogue_panel.position = _base_position + Vector2(0, 32)
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(veil, "modulate:a", 1.0, 0.36)
	_panel_tween.tween_property(dialogue_panel, "position", _base_position, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.28)
	_panel_tween.tween_property(dialogue_panel, "scale", Vector2.ONE, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if npc.has_signal("dialogue_line_changed") and not npc.dialogue_line_changed.is_connected(_on_npc_line_changed):
		npc.dialogue_line_changed.connect(_on_npc_line_changed)
	dialogue_started.emit()
	if npc.has_method("start_dialogue"):
		npc.start_dialogue()

func advance_dialogue() -> void:
	if not _active:
		return
	if _displaying_line:
		if is_instance_valid(_line_tween):
			_line_tween.kill()
		text_label.visible_characters = -1
		_displaying_line = false
		hint_label.modulate.a = 1.0
		return
	if not is_instance_valid(_current_npc):
		close_dialogue()
		return
	if _current_npc.has_method("advance_dialogue") and not _current_npc.advance_dialogue():
		close_dialogue()

func close_dialogue() -> void:
	if not _active:
		return
	if is_instance_valid(_line_tween):
		_line_tween.kill()
	_displaying_line = false
	if is_instance_valid(_current_npc):
		if _current_npc.has_method("end_dialogue"):
			_current_npc.end_dialogue()
		if _current_npc.has_signal("dialogue_line_changed") and _current_npc.dialogue_line_changed.is_connected(_on_npc_line_changed):
			_current_npc.dialogue_line_changed.disconnect(_on_npc_line_changed)
	_current_npc = null
	_active = false
	dialogue_ended.emit()
	if is_instance_valid(_panel_tween):
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(dialogue_panel, "position:y", _base_position.y + 18.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.22)
	_panel_tween.tween_property(veil, "modulate:a", 0.0, 0.22)
	_panel_tween.finished.connect(func() -> void:
		if not _active:
			dialogue_panel.visible = false
			veil.visible = false
	)

func _on_npc_line_changed(line_text: String, speaker_name: String) -> void:
	speaker_label.text = speaker_name
	text_label.text = line_text
	text_label.visible_characters = 0
	hint_label.modulate.a = 0.5
	if is_instance_valid(_line_tween):
		_line_tween.kill()
	_displaying_line = true
	_line_tween = create_tween()
	_line_tween.tween_property(text_label, "visible_characters", line_text.length(), clampf(line_text.length() * 0.018, 0.3, 1.25))
	_line_tween.finished.connect(func() -> void:
		_displaying_line = false
		hint_label.modulate.a = 1.0
	)
	dialogue_line_changed.emit(line_text, speaker_name)

func _layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(920.0, viewport_size.x - 32.0)
	var height := minf(228.0, viewport_size.y * 0.48)
	if _active and is_instance_valid(_panel_tween):
		_panel_tween.kill()
		dialogue_panel.modulate.a = 1.0
		dialogue_panel.scale = Vector2.ONE
		veil.modulate.a = 1.0
	dialogue_panel.reset_size()
	height = maxf(height, dialogue_panel.get_combined_minimum_size().y)
	dialogue_panel.size = Vector2(width, height)
	_base_position = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - height - minf(24.0, viewport_size.y * 0.04))
	if _active:
		dialogue_panel.position = _base_position

func is_active() -> bool:
	return _active
