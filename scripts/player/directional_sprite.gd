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
const WALK_FRONT_RIGHT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_right_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_right_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_right_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_right_4.png"),
]
const WALK_BACK_RIGHT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_right_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_right_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_right_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_right_4.png"),
]
const WALK_BACK_LEFT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_left_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_left_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_left_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_back_left_4.png"),
]
const WALK_FRONT_LEFT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_left_1.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_left_2.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_left_3.png"),
	preload("res://assets/Sprites_persona/animation/Walking/diagonal_front_left_4.png"),
]
const IDLE_FRONT: Array[Texture2D] = [
	preload("res://assets/Sprites_persona/animation/Idle/idle_1.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_2.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_3.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_4.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_5.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_6.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_7.png"),
	preload("res://assets/Sprites_persona/animation/Idle/idle_8.png"),
]
const WALK_FPS := 3.0
const IDLE_FPS := 5.0
const IDLE_FRAME_HOLDS := [1.0, 1.0, 1.2, 1.5, 1.0, 1.3, 1.0, 1.4]
const WALK_MIN_SPEED_SQUARED := 0.25
const SPECIAL_IDLE_DELAY := 1.5
## Ajustes verticais em pixels para a linha dos pés; todos os PNGs têm 512x768.
const FRAME_FEET_OFFSETS := {
	&"idle_front": [0, 0, -1, -5, -1, 3, 1, 1],
	&"idle_front_hold": [-3],
	&"idle_front_right": [-1], &"idle_right": [2],
	&"idle_back_right": [-20], &"idle_back": [-2],
	&"idle_back_left": [4], &"idle_left": [-11], &"idle_front_left": [-14],
	&"walk_front": [-8, -9, -9, -6],
	&"walk_front_right": [-5, 14, 8, 8],
	&"walk_right": [3, 0, 4, 11],
	&"walk_back_right": [-4, 12, -5, 2],
	&"walk_back": [-1, 0, 0, -1],
	&"walk_back_left": [-11, -11, -15, -7],
	&"walk_left": [2, 3, 1, 0],
	&"walk_front_left": [4, 5, 4, 4],
}

@export_range(0.0, 15.0, 0.5) var direction_hysteresis_degrees := 8.0

var _direction_index := -1
var _visual_state: StringName = &"idle"
var _base_offset := Vector2.ZERO
var movement_direction := Vector3.ZERO
var facing_direction := Vector3.ZERO
var last_facing_direction := Vector3.ZERO
var _idle_elapsed := 0.0
var _special_idle := false
var _idle_fade: Tween
var _lock_facing_active := false
@onready var _fill_light: OmniLight3D = get_node_or_null("../SpriteFillLight") as OmniLight3D
@onready var _state_machine: PlayerStateMachine = get_node_or_null("../StateMachine") as PlayerStateMachine
@onready var _lock_on: LockOnController = get_node_or_null("../LockOnController") as LockOnController

func _ready() -> void:
	_base_offset = offset
	frame_changed.connect(_apply_frame_offset)
	var idle_frames := SpriteFrames.new()
	idle_frames.remove_animation(&"default")
	for index in DIRECTIONS.size():
		var name := StringName("idle_" + DIRECTIONS[index])
		idle_frames.add_animation(name)
		idle_frames.set_animation_speed(name, IDLE_FPS)
		if index == 0:
			idle_frames.set_animation_loop(name, true)
			for frame_index in IDLE_FRONT.size():
				idle_frames.add_frame(name, IDLE_FRONT[frame_index], IDLE_FRAME_HOLDS[frame_index])
		else:
			idle_frames.add_frame(name, IDLE_TEXTURES[index])
	idle_frames.add_animation(&"idle_front_hold")
	idle_frames.set_animation_speed(&"idle_front_hold", IDLE_FPS)
	idle_frames.add_frame(&"idle_front_hold", IDLE_TEXTURES[0])
	for direction in DIRECTIONS:
		var walk_name := StringName("walk_" + direction)
		idle_frames.add_animation(walk_name)
		idle_frames.set_animation_speed(walk_name, WALK_FPS)
		idle_frames.set_animation_loop(walk_name, true)
		var textures: Array[Texture2D]
		match walk_name:
			&"walk_front": textures = WALK_FRONT
			&"walk_front_right": textures = WALK_FRONT_RIGHT
			&"walk_right": textures = WALK_RIGHT
			&"walk_back_right": textures = WALK_BACK_RIGHT
			&"walk_back": textures = WALK_BACK
			&"walk_back_left": textures = WALK_BACK_LEFT
			&"walk_left": textures = WALK_LEFT
			&"walk_front_left": textures = WALK_FRONT_LEFT
		for texture in textures:
			idle_frames.add_frame(walk_name, texture)
	sprite_frames = idle_frames
	var player := get_parent() as Node3D
	last_facing_direction = player.global_basis.z.normalized()
	facing_direction = last_facing_direction
	_update_direction()

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var on_ground := _state_machine != null and _state_machine.state in [PlayerStateMachine.State.IDLE, PlayerStateMachine.State.MOVE]
	var horizontal_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z) if body != null else Vector3.ZERO
	var moving := on_ground and horizontal_velocity.length_squared() > WALK_MIN_SPEED_SQUARED
	var target := _lock_on.get_target() if _lock_on != null else null
	var locked := is_instance_valid(target)
	if locked != _lock_facing_active:
		_lock_facing_active = locked
		_direction_index = -1
	if moving or locked:
		_clear_special_idle()
	if moving:
		movement_direction = horizontal_velocity.normalized()
		last_facing_direction = movement_direction
		if not locked:
			facing_direction = movement_direction
	else:
		movement_direction = Vector3.ZERO
		facing_direction = last_facing_direction
		if on_ground and not locked and not _special_idle:
			_idle_elapsed += delta
			if _idle_elapsed >= SPECIAL_IDLE_DELAY:
				_enter_special_idle()
		elif not on_ground:
			_idle_elapsed = 0.0
	if locked:
		var toward_target: Vector3 = target.global_position - body.global_position
		toward_target.y = 0.0
		if toward_target.length_squared() > 0.001:
			facing_direction = toward_target.normalized()
	var next_state: StringName = &"walk" if moving else &"idle"
	if next_state != _visual_state:
		set_visual_state(next_state)
	_update_direction()

func _clear_special_idle() -> void:
	_idle_elapsed = 0.0
	if _special_idle or is_instance_valid(_idle_fade):
		if is_instance_valid(_idle_fade):
			_idle_fade.kill()
		_idle_fade = null
		modulate.a = 1.0
	_special_idle = false

func _enter_special_idle() -> void:
	_special_idle = true
	if _direction_index != 0:
		modulate.a = 0.78
		_idle_fade = create_tween()
		_idle_fade.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_show_direction()

func set_visual_state(state: StringName) -> void:
	if _visual_state == state:
		return
	_visual_state = state
	_show_direction()

func _update_direction() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var player := get_parent() as Node3D
	var direction := facing_direction if _lock_facing_active else (movement_direction if _visual_state == &"walk" else facing_direction)
	if direction.length_squared() < 0.001:
		direction = player.global_basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	if _fill_light != null:
		var facing := Vector3(camera.global_position.x - player.global_position.x, 0.0, camera.global_position.z - player.global_position.z).normalized()
		_fill_light.global_position = player.global_position + Vector3(0.0, 1.35, 0.0) + facing * 1.35
	if _visual_state == &"idle" and not _lock_facing_active and _direction_index >= 0:
		return
	var camera_right := camera.global_basis.x
	var camera_back := camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0
	camera_right = camera_right.normalized()
	camera_back = camera_back.normalized()
	var angle := atan2(direction.dot(camera_right), direction.dot(camera_back))
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
	var name := &"idle_front" if _special_idle and _visual_state == &"idle" else StringName(String(_visual_state) + "_" + DIRECTIONS[_direction_index])
	if name == &"idle_front" and not _special_idle:
		name = &"idle_front_hold"
	if animation != name:
		play(name)
		_apply_frame_offset()

func _apply_frame_offset() -> void:
	var corrections: Array = FRAME_FEET_OFFSETS.get(animation, [])
	offset = _base_offset + Vector2(0.0, corrections[frame] if frame < corrections.size() else 0.0)
