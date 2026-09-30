extends Node3D

## Um cenário 3D com menu renderizado na própria tela da televisão.
const TRAINING_SCENE := "res://scenes/levels/start_room.tscn"
const SCREEN_SIZE := Vector2(3.08, 2.002)

@onready var camera: Camera3D = $Camera
@onready var tv: Node3D = $Television
@onready var stage: Node3D = $Stage
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var ui: Control = $ScreenViewport/TitleTvUi
@onready var key_light: OmniLight3D = $KeyLight
@onready var rim_light: OmniLight3D = $RimLight
@onready var screen_glow: OmniLight3D = $ScreenGlow

var screen_mesh: MeshInstance3D
var _screen_material: StandardMaterial3D
var _indicator_material: StandardMaterial3D
var _dial: MeshInstance3D
var _dial_tween: Tween
var _motes: Array[Node3D] = []
var _time := 0.0
var _mouse_offset := Vector2.ZERO
var _transitioning := false
var _camera_distance := 5.45

func _ready() -> void:
	add_to_group("title_screen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	camera.look_at(Vector3(0, 1.75, 0))
	get_viewport().size_changed.connect(_update_camera_distance)
	_update_camera_distance()
	_build_stage()
	_build_television()
	_build_motes()
	ui.choice_selected.connect(_on_choice)
	ui.selection_changed.connect(_on_selection_changed)
	ui.set_continue_available(not Progression.collected.is_empty())

func _process(delta: float) -> void:
	_time += delta
	var drift := sin(_time * 0.64)
	tv.position.y = 1.72 + 0.018 * drift
	tv.rotation.y = lerpf(tv.rotation.y, _mouse_offset.x * 0.045 + sin(_time * 0.43) * 0.009, minf(1.0, delta * 3.0))
	tv.rotation.x = lerpf(tv.rotation.x, -_mouse_offset.y * 0.025, minf(1.0, delta * 3.0))
	var desired_camera := Vector3(_mouse_offset.x * 0.13, 2.0 - _mouse_offset.y * 0.075, _camera_distance)
	if not _transitioning:
		camera.position = camera.position.lerp(desired_camera, minf(1.0, delta * 2.1))
		camera.look_at(Vector3(0, 1.75, 0))
	key_light.light_energy = 2.0 + 0.18 * sin(_time * 1.2)
	rim_light.light_energy = 2.45 + 0.28 * sin(_time * 0.87 + 1.1)
	screen_glow.light_energy = 0.85 + 0.17 * sin(_time * 2.4)
	_indicator_material.emission = Color(0.95, 0.33, 0.51).lerp(Color(0.99, 0.72, 0.47), 0.5 + 0.5 * sin(_time * 3.1))
	for index in _motes.size():
		var mote := _motes[index]
		var angle := _time * (0.21 + index * 0.007) + index * 2.399
		mote.position = Vector3(sin(angle) * (2.65 + index % 3 * 0.28), 0.7 + index % 5 * 0.57 + sin(_time * 0.8 + index) * 0.09, cos(angle) * 0.9 - 0.4)
		mote.rotation.y += delta * 0.28

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or PauseMenu.overlay.visible:
		return
	if event is InputEventMouseMotion:
		var viewport_size := get_viewport().get_visible_rect().size
		_mouse_offset = ((event.position / viewport_size) * 2.0 - Vector2.ONE).clamp(Vector2(-1, -1), Vector2.ONE)
		var point := _screen_point(event.position)
		if point != Vector2.INF:
			ui.hover_at(point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point := _screen_point(event.position)
		if point != Vector2.INF and ui.click_at(point):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_UP, KEY_W] or event.is_action_pressed("ui_up"):
			ui.select_direction(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_DOWN, KEY_S] or event.is_action_pressed("ui_down"):
			ui.select_direction(1)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or event.is_action_pressed("ui_accept"):
			ui.activate_selected()
			get_viewport().set_input_as_handled()

## Converte um ponto do mouse em pixels da SubViewport, seguindo a inclinação da TV.
func _screen_point(mouse_position: Vector2) -> Vector2:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var plane_normal := screen_mesh.global_transform.basis.z.normalized()
	var denominator := plane_normal.dot(ray_direction)
	if absf(denominator) < 0.0001:
		return Vector2.INF
	var distance := plane_normal.dot(screen_mesh.global_position - ray_origin) / denominator
	if distance <= 0.0:
		return Vector2.INF
	var local_point := screen_mesh.to_local(ray_origin + ray_direction * distance)
	var uv := Vector2(local_point.x / SCREEN_SIZE.x + 0.5, 0.5 - local_point.y / SCREEN_SIZE.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2.INF
	return uv * Vector2(screen_viewport.size)

func _on_selection_changed(index: int) -> void:
	if is_instance_valid(_dial):
		if is_instance_valid(_dial_tween):
			_dial_tween.kill()
		var target := Vector3(0, 0, float(index) * 0.35)
		_dial_tween = create_tween()
		_dial_tween.tween_property(_dial, "rotation", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_choice(choice: String) -> void:
	if _transitioning:
		return
	if choice == "options":
		PauseMenu.open_title_options()
		return
	if choice == "controls":
		PauseMenu.open_title_controls()
		return
	_transitioning = true
	ui.power_off()
	var move := create_tween().set_parallel(true)
	move.tween_property(camera, "position:z", maxf(4.5, _camera_distance - 0.95), 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	move.tween_property(screen_glow, "light_energy", 0.0, 0.42)
	await move.finished
	match choice:
		"new_game":
			Progression.clear_progress()
			GameManager.reset_style()
			GameManager.reset_equipment()
			get_tree().change_scene_to_file.call_deferred(TRAINING_SCENE)
		"continue":
			GameManager.reset_style()
			GameManager.reset_equipment()
			get_tree().change_scene_to_file.call_deferred(TRAINING_SCENE)
		"exit":
			get_tree().quit()

func _update_camera_distance() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_fov := deg_to_rad(camera.fov) * 0.5
	_camera_distance = maxf(5.45, 4.45 / (2.0 * tan(half_fov) * aspect))
	if not _transitioning:
		camera.position.z = _camera_distance
		camera.look_at(Vector3(0, 1.75, 0))

func _build_stage() -> void:
	var floor_mat := _material(Color(0.065, 0.061, 0.105), 0.05, 0.84)
	var wall_mat := _material(Color(0.032, 0.03, 0.069), 0.08, 0.92)
	var plinth_mat := _material(Color(0.14, 0.13, 0.19), 0.15, 0.63)
	var brass := _material(Color(0.57, 0.43, 0.29), 0.65, 0.35)
	var curtain := _material(Color(0.18, 0.028, 0.072), 0.03, 0.93)
	var pink := _material(Color(0.86, 0.08, 0.3), 0.16, 0.46, Color(0.75, 0.07, 0.3))
	_box(stage, "Floor", Vector3(0, -0.22, 0), Vector3(14, 0.3, 10), floor_mat)
	_box(stage, "RearWall", Vector3(0, 2.65, -3.5), Vector3(14, 5.5, 0.3), wall_mat)
	_box(stage, "StageBase", Vector3(0, 0.06, 0), Vector3(5.4, 0.23, 2.1), plinth_mat)
	_box(stage, "StageLip", Vector3(0, 0.19, 1.02), Vector3(5.44, 0.035, 0.09), brass)
	_box(stage, "BackArchTop", Vector3(0, 3.86, -1.66), Vector3(7.1, 0.16, 0.26), brass)
	for side in [-1.0, 1.0]:
		_box(stage, "Arch", Vector3(side * 3.55, 2.0, -1.66), Vector3(0.16, 3.8, 0.26), brass)
		_box(stage, "Curtain", Vector3(side * 4.75, 2.12, -2.0), Vector3(1.6, 4.3, 0.2), curtain)
		_box(stage, "CurtainFold", Vector3(side * 4.28, 2.12, -1.81), Vector3(0.16, 4.3, 0.17), pink)
		_box(stage, "SidePedestal", Vector3(side * 3.1, 0.7, 0.2), Vector3(0.72, 1.42, 0.72), plinth_mat)
		_box(stage, "PedestalCap", Vector3(side * 3.1, 1.42, 0.2), Vector3(0.87, 0.08, 0.87), brass)
		var sculpture := _gem(stage, "StageGem", Vector3(side * 3.1, 1.84, 0.2), 0.43, pink)
		sculpture.rotation.z = PI * 0.25

func _build_television() -> void:
	var casing := _material(Color(0.082, 0.091, 0.12), 0.42, 0.59)
	var edge := _material(Color(0.17, 0.2, 0.24), 0.56, 0.42)
	var shadow := _material(Color(0.009, 0.018, 0.03), 0.15, 0.82)
	var brass := _material(Color(0.73, 0.56, 0.34), 0.73, 0.27)
	var dark_brass := _material(Color(0.34, 0.29, 0.24), 0.54, 0.48)
	_indicator_material = _material(Color(0.95, 0.35, 0.52), 0.0, 0.3, Color(0.95, 0.35, 0.52))
	_box(tv, "OuterCase", Vector3.ZERO, Vector3(3.9, 2.75, 0.59), casing)
	_box(tv, "CaseInset", Vector3(0, 0.015, 0.31), Vector3(3.75, 2.6, 0.055), edge)
	_box(tv, "ScreenWell", Vector3(-0.24, 0.09, 0.344), Vector3(3.27, 2.19, 0.045), shadow)
	_box(tv, "LeftTrim", Vector3(-1.87, 0.09, 0.38), Vector3(0.035, 2.25, 0.04), brass)
	_box(tv, "RightTrim", Vector3(1.39, 0.09, 0.38), Vector3(0.035, 2.25, 0.04), brass)
	_box(tv, "TopTrim", Vector3(-0.24, 1.2, 0.38), Vector3(3.29, 0.035, 0.04), brass)
	_box(tv, "BottomTrim", Vector3(-0.24, -1.02, 0.38), Vector3(3.29, 0.035, 0.04), brass)
	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "InteractiveScreen"
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	screen_mesh.mesh = quad
	screen_mesh.position = Vector3(-0.24, 0.09, 0.382)
	_screen_material = StandardMaterial3D.new()
	_screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen_material.albedo_texture = screen_viewport.get_texture()
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_mesh.material_override = _screen_material
	tv.add_child(screen_mesh)
	_box(tv, "ControlBay", Vector3(1.64, 0.1, 0.36), Vector3(0.37, 2.17, 0.045), shadow)
	for y in [0.65, -0.28]:
		var dial_back := _cylinder(tv, "DialRim", Vector3(1.64, y, 0.42), 0.16, 0.055, brass)
		dial_back.rotation.x = PI * 0.5
		var dial := _cylinder(tv, "Dial", Vector3(1.64, y, 0.46), 0.115, 0.08, dark_brass)
		dial.rotation.x = PI * 0.5
		if _dial == null:
			_dial = dial
	_box(tv, "PowerLamp", Vector3(1.64, -0.79, 0.43), Vector3(0.12, 0.07, 0.05), _indicator_material)
	for side in [-1.0, 1.0]:
		_box(tv, "Foot", Vector3(side * 1.35, -1.46, 0.05), Vector3(0.42, 0.23, 0.7), dark_brass)
		var antenna := _cylinder(tv, "Antenna", Vector3(side * 0.51, 1.65, -0.12), 0.024, 0.86, brass)
		antenna.rotation.z = -side * 0.35
		_gem(tv, "AntennaTip", Vector3(side * 0.66, 2.05, -0.12), 0.09, _indicator_material)

func _build_motes() -> void:
	var glow := _material(Color(0.85, 0.65, 0.46), 0.12, 0.4, Color(0.45, 0.34, 0.24))
	for index in 16:
		var mote := _gem(stage, "DustLight", Vector3.ZERO, 0.018 + index % 3 * 0.008, glow)
		_motes.append(mote)

func _material(color: Color, metal: float, rough: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material

func _box(parent: Node3D, label: String, location: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, label: String, location: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance

func _gem(parent: Node3D, label: String, location: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance
