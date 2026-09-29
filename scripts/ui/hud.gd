extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var combo_label: Label = %ComboLabel
@onready var style_label: Label = %StyleLabel
@onready var rank_label: Label = %RankLabel
@onready var lock_indicator: Label = %LockIndicator
@onready var debug_label: Label = %DebugLabel

var _player: PlayerController

func _ready() -> void:
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

func _bind_player(player: Node) -> void:
	if not (player is PlayerController):
		return
	_player = player as PlayerController
	health_bar.max_value = _player.health.max_health
	health_bar.value = _player.health.current_health
	if not _player.health.damaged.is_connected(_on_player_damaged):
		_player.health.damaged.connect(_on_player_damaged)
	if not _player.health.healed.is_connected(_on_player_healed):
		_player.health.healed.connect(_on_player_healed)

func _on_player_damaged(_amount: float, current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_player_healed(_amount: float, current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_style_changed(combo: int, score: int, rank: String) -> void:
	combo_label.text = "COMBO  %02d" % combo
	style_label.text = "STYLE  %04d" % score
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
	lock_indicator.position = screen_pos - lock_indicator.size * 0.5

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
