extends AnimatedSprite3D

## Representação visual do player com oito ângulos de idle e ciclos de caminhada disponíveis.
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
const WALK_FRONT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/front_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/front_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/front_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/front_4.png"),
]
const WALK_BACK: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/back_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/back_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/back_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/back_4.png"),
]
const WALK_LEFT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/left_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/left_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/left_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/left_4.png"),
]
const WALK_RIGHT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/right_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/right_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/right_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/right_4.png"),
]
const WALK_FPS := 6.0
const WALK_MIN_SPEED_SQUARED := 0.0225
## Ajustes em pixels: centro do tronco e linha opaca dos pés alinhados ao idle.
## Não alteram escala, pixel_size, posição do nó nem espelham o desenho.
const WALK_FRAME_OFFSETS := {
	&"walk_front": [Vector2(4, 6), Vector2(0, 7), Vector2(0, 6), Vector2(5, 4)],
	&"walk_back": [Vector2(2, -2), Vector2(2, -2), Vector2(-1, -2), Vector2(-6, -2)],
	&"walk_left": [Vector2(7, -14), Vector2(37, -15), Vector2(27, -12), Vector2(24, -11)],
	&"walk_right": [Vector2(-38, -1), Vector2(-43, 3), Vector2(-59, -2), Vector2(-38, -8)],
}

@export_range(0.0, 15.0, 0.5) var direction_hysteresis_degrees := 8.0

var _direction_index := -1
var _visual_state: StringName = &"idle"
var _base_offset := Vector2.ZERO
@onready var _fill_light: OmniLight3D = get_node_or_null("../SpriteFillLight") as OmniLight3D
@onready var _state_machine: PlayerStateMachine = get_node_or_null("../StateMachine") as PlayerStateMachine

func _ready() -> void:
	_base_offset = offset
	frame_changed.connect(_apply_frame_offset)
	var idle_frames := SpriteFrames.new()
	idle_frames.remove_animation(&"default")
	for index in DIRECTIONS.size():
		var name := StringName("idle_" + DIRECTIONS[index])
		idle_frames.add_animation(name)
		idle_frames.add_frame(name, IDLE_TEXTURES[index])
	for walk_name in [&"walk_front", &"walk_back", &"walk_left", &"walk_right"]:
		idle_frames.add_animation(walk_name)
		idle_frames.set_animation_speed(walk_name, WALK_FPS)
		idle_frames.set_animation_loop(walk_name, true)
		var textures: Array[Texture2D]
		match walk_name:
			&"walk_front": textures = WALK_FRONT
			&"walk_back": textures = WALK_BACK
			&"walk_left": textures = WALK_LEFT
			&"walk_right": textures = WALK_RIGHT
		for texture in textures:
			idle_frames.add_frame(walk_name, texture)
	sprite_frames = idle_frames
	_update_direction()

func _process(_delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var on_ground := _state_machine != null and _state_machine.state in [PlayerStateMachine.State.IDLE, PlayerStateMachine.State.MOVE]
	var moving := on_ground and body != null and Vector2(body.velocity.x, body.velocity.z).length_squared() > WALK_MIN_SPEED_SQUARED
	var next_state: StringName = &"walk" if moving else &"idle"
	if next_state != _visual_state:
		set_visual_state(next_state)
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
		# Ângulos sem quadros de walk mantêm o idle correto, sem espelhar lados.
		name = StringName("idle_" + DIRECTIONS[_direction_index])
	if animation != name:
		play(name)
		_apply_frame_offset()

func _apply_frame_offset() -> void:
	var corrections: Array = WALK_FRAME_OFFSETS.get(animation, [])
	offset = _base_offset + (corrections[frame] if frame < corrections.size() else Vector2.ZERO)
