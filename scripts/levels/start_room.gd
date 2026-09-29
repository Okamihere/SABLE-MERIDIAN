extends Node3D

## StartRoom
##
## Sala de início do jogo — área segura para o jogador se acostumar com os controles
## antes de entrar na cidade principal.
##
## Controles:
## - WASD: mover
## - Space: pular
## - Shift: dodge
## - Mouse esq: ataque leve
## - Mouse dir: ataque pesado
## - Q: lock-on
## - F3: debug overlay

@export var main_scene_path: String = "res://scenes/levels/main.tscn"

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D

var _elapsed: float = 0.0

func _ready() -> void:
	# Conecta o sinal de morte do player para reiniciar a sala
	if player != null:
		var health := player.get_node_or_null("HealthComponent") as Node
		if health != null and health.has_signal("died"):
			health.died.connect(_on_player_died)

func _process(delta: float) -> void:
	_elapsed += delta
	# Suave movimento de câmera para dar vida à sala
	if camera != null:
		camera.position.x = sin(_elapsed * 0.3) * 0.5
		camera.position.y = 3.0 + sin(_elapsed * 0.5) * 0.2

func _on_player_died() -> void:
	# Reinicia a sala de início quando o jogador morre
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
