extends Node3D

## Travessia física: só inicia a mudança quando o jogador atravessa a névoa.
@export_file("*.tscn") var destination_scene: String = "res://scenes/levels/main.tscn"

@onready var threshold: Area3D = $Threshold
@onready var glow: OmniLight3D = $Glow

var _player_inside: PlayerController
var _activated := false
var _time := 0.0

func _ready() -> void:
	threshold.body_entered.connect(_on_body_entered)
	threshold.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_time += delta
	glow.light_energy = 1.65 + 0.4 * sin(_time * 1.6)

func _physics_process(_delta: float) -> void:
	if _activated or not is_instance_valid(_player_inside):
		return
	if _player_inside.global_position.z >= global_position.z + 6.0 and absf(_player_inside.global_position.x - global_position.x) < 3.0:
		_activated = true
		GameManager.reset_style()
		AreaTransition.travel_to(destination_scene)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and body.is_alive():
		_player_inside = body as PlayerController
		AreaTransition.prepare_scene(destination_scene)

func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
