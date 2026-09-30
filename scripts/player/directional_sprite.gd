extends AnimatedSprite3D

## Representação visual do player. Cada direção tem uma animação idle de um quadro;
## outras animações podem seguir o mesmo padrão: run_front, attack_back etc.
const DIRECTIONS: Array[String] = [
	"front", "front_right", "right", "back_right",
	"back", "back_left", "left", "front_left",
]
const IDLE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/front.png"),
	preload("res://assets/Sprites_persona/front-right.png"),
	preload("res://assets/Sprites_persona/right.png"),
	preload("res://assets/Sprites_persona/back-right.png"),
	preload("res://assets/Sprites_persona/back.png"),
	preload("res://assets/Sprites_persona/back-left.png"),
	preload("res://assets/Sprites_persona/left.png"),
	preload("res://assets/Sprites_persona/front-left.png"),
]

@export_range(0.0, 15.0, 0.5) var direction_hysteresis_degrees := 6.0

var _direction_index := -1
var _visual_state: StringName = &"idle"
@onready var _fill_light: OmniLight3D = get_node_or_null("../SpriteFillLight") as OmniLight3D

func _ready() -> void:
	var idle_frames := SpriteFrames.new()
	idle_frames.remove_animation(&"default")
	for index in DIRECTIONS.size():
		var name := StringName("idle_" + DIRECTIONS[index])
		idle_frames.add_animation(name)
		idle_frames.add_frame(name, IDLE_TEXTURES[index])
	sprite_frames = idle_frames
	_update_direction()

func _process(_delta: float) -> void:
	_update_direction()

func set_visual_state(state: StringName) -> void:
	_visual_state = state
	_show_direction()

func _update_direction() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var player := get_parent() as Node3D
	var relative := player.to_local(camera.global_position)
	relative.y = 0.0
	if relative.length_squared() < 0.001:
		return
	if _fill_light != null:
		var facing := Vector3(camera.global_position.x - player.global_position.x, 0.0, camera.global_position.z - player.global_position.z).normalized()
		_fill_light.global_position = player.global_position + Vector3(0.0, 1.35, 0.0) + facing * 1.35
	var angle := atan2(-relative.x, relative.z)
	var candidate := posmod(roundi(angle / (PI / 4.0)), DIRECTIONS.size())
	if candidate == _direction_index:
		return
	if _direction_index >= 0:
		var center := _direction_index * PI / 4.0
		var distance := absf(wrapf(angle - center, -PI, PI))
		if distance < PI / 8.0 + deg_to_rad(direction_hysteresis_degrees):
			return
	_direction_index = candidate
	_show_direction()

func _show_direction() -> void:
	if _direction_index < 0 or sprite_frames == null:
		return
	var name := StringName(String(_visual_state) + "_" + DIRECTIONS[_direction_index])
	if not sprite_frames.has_animation(name):
		name = StringName("idle_" + DIRECTIONS[_direction_index])
	if animation != name:
		play(name)
