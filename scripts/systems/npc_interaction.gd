extends Node

## Seleciona o NPC disponível mais próximo e mostra uma ação contextual.
## NPCs futuros só precisam entrar no grupo "npcs" e oferecer can_interact(),
## get_character_name() e os métodos de diálogo usados por DialogueBox.

@onready var prompt_panel: PanelContainer = $PromptLayer/PromptPanel
@onready var prompt_label: Label = $PromptLayer/PromptPanel/Margin/Row/Label
@onready var dialogue_box: CanvasLayer = $DialogueBox

var _current_npc: Node3D
var _dialogue_player: PlayerController
var _prompt_target: Node3D
var _prompt_tween: Tween
var _prompt_hiding := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_panel.visible = false
	dialogue_box.dialogue_started.connect(_on_dialogue_started)
	dialogue_box.dialogue_ended.connect(_on_dialogue_ended)

func _process(_delta: float) -> void:
	if dialogue_box.is_active() or get_tree().paused:
		_hide_prompt()
		return
	if not is_instance_valid(GameManager.player):
		_current_npc = null
		_hide_prompt()
		return
	var player := GameManager.player as PlayerController
	if not is_instance_valid(player) or not player.is_alive():
		_current_npc = null
		_hide_prompt()
		return
	_current_npc = _find_nearest_npc(player)
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo() and not dialogue_box.is_active():
		if try_interact():
			get_viewport().set_input_as_handled()

func _find_nearest_npc(player: PlayerController) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("npcs"):
		if not candidate is Node3D or not candidate.has_method("can_interact"):
			continue
		if not candidate.can_interact():
			continue
		var distance := player.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest

func _update_prompt() -> void:
	if not is_instance_valid(_current_npc):
		_hide_prompt()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_hide_prompt()
		return
	var anchor := _current_npc.global_position + Vector3.UP * 2.25
	if _current_npc.has_method("get_interaction_anchor"):
		anchor = _current_npc.get_interaction_anchor()
	if camera.is_position_behind(anchor):
		_hide_prompt()
		return
	var screen := camera.unproject_position(anchor)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen.x < 0.0 or screen.y < 0.0 or screen.x > viewport_size.x or screen.y > viewport_size.y:
		_hide_prompt()
		return
	var npc_name := _current_npc.name
	if _current_npc.has_method("get_character_name"):
		npc_name = _current_npc.get_character_name()
	prompt_label.text = "Conversar com %s" % npc_name
	prompt_panel.reset_size()
	var size := prompt_panel.get_combined_minimum_size()
	prompt_panel.size = size
	prompt_panel.position = (screen - Vector2(size.x * 0.5, size.y + 16.0)).clamp(Vector2.ZERO, viewport_size - size)
	if _prompt_target != _current_npc or not prompt_panel.visible or _prompt_hiding:
		_prompt_target = _current_npc
		_prompt_hiding = false
		if is_instance_valid(_prompt_tween):
			_prompt_tween.kill()
		prompt_panel.visible = true
		prompt_panel.modulate.a = 0.0
		prompt_panel.scale = Vector2(0.9, 0.9)
		prompt_panel.pivot_offset = size * 0.5
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.22)
		_prompt_tween.tween_property(prompt_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_prompt() -> void:
	if not prompt_panel.visible or _prompt_hiding:
		_prompt_target = null
		return
	_prompt_target = null
	_prompt_hiding = true
	if is_instance_valid(_prompt_tween):
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.16)
	_prompt_tween.finished.connect(func() -> void:
		if _prompt_target == null:
			prompt_panel.visible = false
			_prompt_hiding = false
	)

func try_interact() -> bool:
	if get_tree().paused or dialogue_box.is_active() or not is_instance_valid(_current_npc):
		return false
	if not _current_npc.can_interact():
		return false
	dialogue_box.start_dialogue(_current_npc)
	return true

func get_current_npc() -> Node3D:
	return _current_npc if is_instance_valid(_current_npc) else null

func is_dialogue_active() -> bool:
	return dialogue_box.is_active()

func _on_dialogue_started() -> void:
	_hide_prompt()
	_dialogue_player = GameManager.player as PlayerController
	if is_instance_valid(_dialogue_player):
		_dialogue_player.set_physics_process(false)

func _on_dialogue_ended() -> void:
	if is_instance_valid(_dialogue_player):
		_dialogue_player.set_physics_process(true)
	_dialogue_player = null
