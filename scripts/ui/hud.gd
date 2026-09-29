extends CanvasLayer

## HUD compartilhado pelo pátio e pela cidade: vida, mana, mobilidade e estilo.
## Atualiza valores por sinais e projeta o indicador do alvo na tela.

@onready var mana_bar: ProgressBar = %ManaBar
@onready var health_value: Label = %HealthValue
@onready var mana_value: Label = %ManaValue
@onready var wall_label: Label = %WallLabel
@onready var notice_label: Label = %NoticeLabel
@onready var location_label: Label = %LocationLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var combo_label: Label = %ComboLabel
@onready var style_label: Label = %StyleLabel
@onready var rank_label: Label = %RankLabel
@onready var lock_indicator: Label = %LockIndicator
@onready var debug_label: Label = %DebugLabel

var compact_layout: bool = false
var _player: PlayerController
var _health_tween: Tween
var _mana_tween: Tween

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout.call_deferred()
	location_label.text = "PÁTIO DE TREINO" if get_parent().name == "StartRoom" else "CIDADE • SABLE MERIDIAN"
	GameManager.style_changed.connect(_on_style_changed)
	GameManager.player_registered.connect(_bind_player)
	GameManager.debug_changed.connect(_on_debug_changed)
	_on_style_changed(GameManager.combo_count, GameManager.style_score, GameManager.style_rank)
	_on_debug_changed(GameManager.DEBUG_COMBAT)
	if GameManager.player is PlayerController:
		_bind_player(GameManager.player)

func _process(_delta: float) -> void:
	_update_lock_indicator()
	_update_debug()
	_update_resources()
	_update_tutorial_position()

func _bind_player(player: Node) -> void:
	if not (player is PlayerController):
		return
	_unbind_player()
	_player = player as PlayerController
	health_bar.max_value = _player.health.max_health
	health_bar.value = _player.health.current_health
	health_value.text = "%d / %d" % [ceili(_player.health.current_health), ceili(_player.health.max_health)]
	mana_bar.max_value = _player.mana.max_mana
	mana_bar.value = _player.mana.current_mana
	mana_value.text = "%d / %d" % [ceili(_player.mana.current_mana), ceili(_player.mana.max_mana)]
	_player.mana.changed.connect(_on_mana_changed)
	if not _player.health.damaged.is_connected(_on_player_damaged):
		_player.health.damaged.connect(_on_player_damaged)
	if not _player.health.healed.is_connected(_on_player_healed):
		_player.health.healed.connect(_on_player_healed)

func _on_player_damaged(_amount: float, current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_value.text = "%d / %d" % [ceili(current), ceili(maximum)]
	if is_instance_valid(_health_tween):
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", current, 0.18)

func _on_player_healed(amount: float, current: float, maximum: float) -> void:
	_on_player_damaged(amount, current, maximum)

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_value.text = "%d / %d" % [ceili(current), ceili(maximum)]
	if is_instance_valid(_mana_tween):
		_mana_tween.kill()
	_mana_tween = create_tween()
	_mana_tween.tween_property(mana_bar, "value", current, 0.12)

## Desconecta antes de vincular outro jogador; evita sinais de uma instância antiga.
func _unbind_player() -> void:
	if not is_instance_valid(_player):
		return
	if _player.health.damaged.is_connected(_on_player_damaged):
		_player.health.damaged.disconnect(_on_player_damaged)
	if _player.health.healed.is_connected(_on_player_healed):
		_player.health.healed.disconnect(_on_player_healed)
	if _player.mana.changed.is_connected(_on_mana_changed):
		_player.mana.changed.disconnect(_on_mana_changed)

func _update_resources() -> void:
	if not is_instance_valid(_player):
		return
	wall_label.text = "PAREDE   %d / %d" % [_player.wall_movement.remaining(), Progression.max_wall_jumps()]
	if Progression.notice_time > 0.0:
		notice_label.text = "◇ ORBE ENCONTRADA\n+1 salto de parede permanente"
	elif _player.wall_movement.gripping:
		notice_label.text = "ESPAÇO • saltar da parede"
	elif not _player.is_alive():
		notice_label.text = "VOCÊ CAIU\nRetornando ao início da área…"
	else:
		notice_label.text = ""

func _on_style_changed(combo: int, score: int, rank: String) -> void:
	combo_label.text = ("%d hits" if compact_layout else "%d ACERTOS") % combo
	style_label.text = ("%d pts" if compact_layout else "%04d PONTOS") % score
	rank_label.text = rank

func _on_debug_changed(enabled: bool) -> void:
	debug_label.visible = enabled

func _update_lock_indicator() -> void:
	if not is_instance_valid(_player):
		lock_indicator.visible = false
		return
	var target := _player.get_lock_target()
	var camera := get_viewport().get_camera_3d()
	if target == null or camera == null or camera.is_position_behind(target.global_position):
		lock_indicator.visible = false
		return
	lock_indicator.visible = true
	var screen_pos := camera.unproject_position(target.global_position + Vector3.UP * 1.25)
	var local_pos := screen_pos / scale - lock_indicator.size * 0.5
	lock_indicator.position = local_pos.clamp(Vector2.ZERO, ($Root as Control).size - lock_indicator.size)

func _update_debug() -> void:
	if not GameManager.DEBUG_COMBAT or not is_instance_valid(_player):
		return
	var lines: Array[String] = []
	lines.append("PLAYER: %s" % _player.get_state_name())
	var target := _player.get_lock_target()
	lines.append("LOCK: %s" % (target.name if target != null else "NONE"))
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_state_name"):
			lines.append("%s: %s" % [enemy.name, enemy.call("get_state_name")])
			count += 1
			if count >= 5:
				break
	debug_label.text = "\n".join(lines)

## A escala acompanha a resolução; o layout muda quando falta espaço.
## Coordenadas do HUD são lógicas, separadas dos pixels projetados pela câmera.
func _apply_responsive_layout() -> void:
	var pixels := get_viewport().get_visible_rect().size
	if pixels.x <= 0.0 or pixels.y <= 0.0:
		return
	var factor := clampf(minf(pixels.x / 1280.0, pixels.y / 720.0), 0.85, 2.5)
	scale = Vector2.ONE * factor
	var area := pixels / factor
	compact_layout = area.x < 900.0 or area.y < 600.0
	var margin := 12.0 if compact_layout else 24.0
	var root_control := $Root as Control
	_place(root_control, Vector2.ZERO, area)
	var vitals := $Root/Vitals as PanelContainer
	var style_panel := $Root/StylePanel as PanelContainer
	var stack := $Root/Vitals/Stack as VBoxContainer
	var style_stack := $Root/StylePanel/Stack as VBoxContainer
	for panel in [vitals, style_panel]:
		var box := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			box.set_content_margin(side, 9.0 if compact_layout else 18.0)
		panel.add_theme_stylebox_override("panel", box)
	stack.add_theme_constant_override("separation", 4 if compact_layout else 8)
	style_stack.add_theme_constant_override("separation", 2 if compact_layout else 4)
	$Root/Vitals/Stack/Brand.visible = not compact_layout
	location_label.visible = not compact_layout
	$Root/Vitals/Stack/ManaHint.visible = not compact_layout
	$Root/Vitals/Stack/Divider.visible = not compact_layout
	for text_label in [health_value, mana_value, $Root/Vitals/Stack/HealthRow/HealthTitle, $Root/Vitals/Stack/ManaRow/ManaTitle, wall_label]:
		text_label.add_theme_font_size_override("font_size", 16 if compact_layout else 18)
	rank_label.add_theme_font_size_override("font_size", 30 if compact_layout else 48)
	combo_label.add_theme_font_size_override("font_size", 13 if compact_layout else 17)
	style_label.add_theme_font_size_override("font_size", 12 if compact_layout else 15)
	style_label.clip_text = true
	combo_label.clip_text = true
	$Root/StylePanel/Stack/Caption.add_theme_font_size_override("font_size", 12 if compact_layout else 15)
	health_bar.custom_minimum_size = Vector2(0, 12 if compact_layout else 18)
	mana_bar.custom_minimum_size = Vector2(0, 9 if compact_layout else 12)
	var style_width := 104.0 if compact_layout else 170.0
	var vital_width := minf(370.0, area.x - style_width - margin * 3.0)
	_place(vitals, Vector2(margin, margin), Vector2(vital_width, 0))
	_place(style_panel, Vector2(area.x - margin - style_width, margin), Vector2(style_width, 0))
	_on_style_changed(GameManager.combo_count, GameManager.style_score, GameManager.style_rank)
	var controls := $Root/Controls as Label
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 15 if compact_layout else 17)
	controls.text = "WASD mover • Espaço pular • Shift esquivar\nMouse atacar • Q alvo • Esc cursor" if compact_layout else "WASD Mover   ESPAÇO Pular   SHIFT Esquivar   MOUSE Atacar   Q Alvo   ESC Cursor"
	var controls_height := 48.0 if compact_layout else 28.0
	_place(controls, Vector2(margin, area.y - margin - controls_height), Vector2(area.x - margin * 2.0, controls_height))
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 16 if compact_layout else 20)
	var top_height := maxf(vitals.get_combined_minimum_size().y, style_panel.get_combined_minimum_size().y)
	_place(notice_label, Vector2(margin, margin + top_height + 8), Vector2(area.x - margin * 2.0, 48))
	debug_label.add_theme_font_size_override("font_size", 12 if compact_layout else 16)
	debug_label.clip_text = true
	_place(debug_label, Vector2(margin, margin + top_height + 60), Vector2(minf(400, area.x - margin * 2), 110))
	var instructions := get_parent().get_node_or_null("Instructions") as CanvasLayer
	if instructions != null:
		instructions.scale = scale
		get_parent().set_compact_layout(compact_layout)
		var panel := instructions.get_node("Panel") as PanelContainer
		var help := panel.get_node("Margin/Help") as Label
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.add_theme_font_size_override("font_size", 16 if compact_layout else 20)
		var panel_width := minf(800, area.x - margin * 2)
		_place(panel, Vector2.ZERO, Vector2(panel_width, 0))
		# Containers calculate wrapped text on the deferred layout pass.
		_finish_tutorial_layout.call_deferred(panel, area, margin, controls_height)
	_settle_responsive_layout.call_deferred(area, margin)

func _finish_tutorial_layout(panel: PanelContainer, area: Vector2, margin: float, controls_height: float) -> void:
	var height := panel.get_combined_minimum_size().y
	_place(panel, Vector2((area.x - panel.size.x) * 0.5, area.y - margin - controls_height - 12 - height), Vector2(panel.size.x, height))

func _place(control: Control, position_value: Vector2, size_value: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = position_value
	control.size = size_value

## A quebra de linhas só estabiliza depois que os containers recebem a largura.
func _settle_responsive_layout(area: Vector2, margin: float) -> void:
	await get_tree().process_frame
	var style_panel := $Root/StylePanel as PanelContainer
	style_panel.size = Vector2(104.0 if compact_layout else 170.0, style_panel.get_combined_minimum_size().y)
	style_panel.position.x = area.x - margin - style_panel.size.x
	var controls := $Root/Controls as Label
	controls.size.y = controls.get_combined_minimum_size().y
	controls.position.y = area.y - margin - controls.size.y
	var panel := get_parent().get_node_or_null("Instructions/Panel") as PanelContainer
	if panel != null:
		_finish_tutorial_layout(panel, area, margin, controls.size.y)

## Mantém a dica acima dos controles quando o texto muda de uma lição para outra.
func _update_tutorial_position() -> void:
	var panel := get_parent().get_node_or_null("Instructions/Panel") as PanelContainer
	if panel == null:
		return
	var margin := 12.0 if compact_layout else 24.0
	_finish_tutorial_layout(panel, ($Root as Control).size, margin, ($Root/Controls as Control).size.y)
