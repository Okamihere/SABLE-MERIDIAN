extends CanvasLayer

## Névoa persistente que esconde a troca de cena e revela a chegada.
signal transition_finished

@onready var curtain: ColorRect = $Curtain

var is_travelling := false
var _coverage := 0.0
var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _audio_phase := 0.0
var _requested_scene_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.16
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "SFX"
	_audio_player.stream = generator
	_audio_player.volume_db = -24.0
	add_child(_audio_player)

func _process(_delta: float) -> void:
	if not is_travelling or _playback == null:
		return
	var frames := _playback.get_frames_available()
	for index in frames:
		_audio_phase += 0.008 + _coverage * 0.004
		var noise := randf_range(-1.0, 1.0) * 0.11
		var sample := (sin(_audio_phase) * 0.23 + noise) * (0.45 + 0.55 * sin(_coverage * PI))
		_playback.push_frame(Vector2(sample, sample))

func prepare_scene(scene_path: String) -> void:
	if scene_path == _requested_scene_path:
		return
	_requested_scene_path = scene_path
	var result := ResourceLoader.load_threaded_request(scene_path)
	if result != OK:
		_requested_scene_path = ""

func travel_to(scene_path: String) -> void:
	if is_travelling:
		return
	is_travelling = true
	curtain.visible = true
	prepare_scene(scene_path)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var cover := create_tween()
	cover.tween_method(_set_coverage, 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await cover.finished
	var packed_scene: PackedScene
	if _requested_scene_path == scene_path:
		while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
			packed_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		packed_scene = load(scene_path) as PackedScene
	if packed_scene == null or get_tree().change_scene_to_packed(packed_scene) != OK:
		push_error("Não foi possível atravessar a névoa para %s" % scene_path)
		_reset_transition()
		return
	_requested_scene_path = ""
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	var reveal := create_tween()
	reveal.tween_method(_set_coverage, 1.0, 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	_reset_transition()
	transition_finished.emit()

func _set_coverage(value: float) -> void:
	_coverage = value
	(curtain.material as ShaderMaterial).set_shader_parameter("coverage", value)

func _reset_transition() -> void:
	_set_coverage(0.0)
	curtain.visible = false
	_playback = null
	_audio_player.stop()
	_audio_player.queue_free()
	_audio_player = null
	is_travelling = false
