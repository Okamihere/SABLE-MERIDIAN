extends Node3D

## Um cenário 3D com menu renderizado na própria tela da televisão.
const TRAINING_SCENE := "res://scenes/levels/start_room.tscn"
const SCREEN_SIZE := Vector2(3.08, 2.002)
const DIAL_DRAG_STEP := 28.0

@onready var camera: Camera3D = $Camera
@onready var tv: Node3D = $Television
@onready var stage: Node3D = $Stage
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var ui: Control = $ScreenViewport/TitleTvUi
@onready var key_light: OmniLight3D = $KeyLight
@onready var rim_light: OmniLight3D = $RimLight
@onready var screen_glow: OmniLight3D = $ScreenGlow
@onready var title_particles: GPUParticles3D = $TitleParticles

var screen_mesh: MeshInstance3D
var _screen_material: StandardMaterial3D
var _indicator_material: StandardMaterial3D
var _dial: MeshInstance3D
var _dial_tween: Tween
var _upper_knob: Node3D
var _lower_knob: Node3D
var _dragging_dial := false
var _dial_drag_amount := 0.0
var _time := 0.0
var _mouse_offset := Vector2.ZERO
var _transitioning := false
var _camera_distance := 4.3
var _props: Dictionary = {}
var _prop_tweens: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _hovered_prop: Node3D
var _screen_flicker: Tween

func _ready() -> void:
	add_to_group("title_screen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	camera.look_at(Vector3(0, 1.75, 0))
	if get_viewport().is_connected("size_changed", _update_camera_distance):
		get_viewport().size_changed.disconnect(_update_camera_distance)
	get_viewport().size_changed.connect(_update_camera_distance)
	_update_camera_distance()
	_build_stage()
	_build_television()
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
	if not _transitioning:
		key_light.light_energy = 1.35 + 0.08 * sin(_time * 1.2)
		rim_light.light_energy = 0.82 + 0.08 * sin(_time * 0.87 + 1.1)
		screen_glow.light_energy = 1.1 + 0.08 * sin(_time * 2.4)
		_indicator_material.emission = Color(0.95, 0.33, 0.51).lerp(Color(0.99, 0.72, 0.47), 0.5 + 0.5 * sin(_time * 3.1))
	
	# Atualizar partículas com posição do mouse no espaço mundial
	_update_particles_mouse_pos()

func _update_particles_mouse_pos() -> void:
	if not is_instance_valid(title_particles) or not is_instance_valid(title_particles.process_material):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	# Intersectar com plano Y=0 (nível do chão) para posição mundial
	if absf(ray_dir.y) > 0.001:
		var t := -ray_origin.y / ray_dir.y
		if t > 0.0:
			var world_pos := ray_origin + ray_dir * t
			# Limitar para área relevante
			world_pos.x = clampf(world_pos.x, -5.0, 5.0)
			world_pos.z = clampf(world_pos.z, -4.0, 4.0)
			world_pos.y = clampf(world_pos.y, -1.0, 5.0)
			var shader_mat := title_particles.process_material as ShaderMaterial
			if shader_mat:
				shader_mat.set_shader_parameter("mouse_world_pos", world_pos)

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or PauseMenu.overlay.visible:
		return
	if event is InputEventMouseMotion:
		if _dragging_dial:
			var drag_delta: float = event.relative.y if absf(event.relative.y) >= absf(event.relative.x) else event.relative.x
			_dial_drag_amount += drag_delta
			while absf(_dial_drag_amount) >= DIAL_DRAG_STEP:
				var step := 1 if _dial_drag_amount > 0.0 else -1
				ui.select_direction(step)
				_dial_drag_amount -= step * DIAL_DRAG_STEP
			get_viewport().set_input_as_handled()
			return
		var viewport_size := get_viewport().get_visible_rect().size
		_mouse_offset = ((event.position / viewport_size) * 2.0 - Vector2.ONE).clamp(Vector2(-1, -1), Vector2.ONE)
		var point := _screen_point(event.position)
		if point != Vector2.INF:
			ui.hover_at(point)
			_set_hovered_prop(null)
		else:
			_set_hovered_prop(_pick_prop(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if _dragging_dial:
					_dragging_dial = false
					get_viewport().set_input_as_handled()
				return
			var point := _screen_point(event.position)
			if point != Vector2.INF:
				ui.click_at(point)
				get_viewport().set_input_as_handled()
			else:
				var prop := _pick_prop(event.position)
				if prop == _upper_knob:
					_dragging_dial = true
					_dial_drag_amount = 0.0
					_react_prop(prop)
				elif prop == _lower_knob:
					_power_off_exit()
				elif prop != null:
					_react_prop(prop)
				if prop != null:
					get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if _screen_point(event.position) == Vector2.INF and _pick_prop(event.position) == _upper_knob:
				ui.select_direction(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
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

## Um único tipo de reação para todos os objetos físicos do título.
func _register_prop(node: Node3D, center: Vector3, size: Vector3, kind: StringName) -> void:
	var body := StaticBody3D.new()
	body.name = "ClickTarget"
	body.collision_layer = 1
	body.collision_mask = 0
	node.add_child(body)
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_props[body] = {"node": node, "kind": kind, "position": node.position, "rotation": node.rotation}

func _pick_prop(mouse_position: Vector2) -> Node3D:
	var origin := camera.project_ray_origin(mouse_position)
	var end := origin + camera.project_ray_normal(mouse_position) * 20.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var data: Dictionary = _props.get(hit.get("collider"), {})
	return data.get("node") as Node3D

func _set_hovered_prop(prop: Node3D) -> void:
	if prop == _hovered_prop:
		return
	if is_instance_valid(_hovered_prop):
		var previous: Tween = _hover_tweens.get(_hovered_prop)
		if is_instance_valid(previous):
			previous.kill()
		var old_tween := create_tween()
		old_tween.tween_property(_hovered_prop, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var previous_prop := _hovered_prop
		old_tween.finished.connect(func(): _hover_tweens.erase(previous_prop))
		_hover_tweens[_hovered_prop] = old_tween
	_hovered_prop = prop
	if is_instance_valid(prop):
		var previous: Tween = _hover_tweens.get(prop)
		if is_instance_valid(previous):
			previous.kill()
		var hover_tween := create_tween()
		hover_tween.tween_property(prop, "scale", Vector3.ONE * 1.018, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hover_tween.finished.connect(func(): _hover_tweens.erase(prop))
		_hover_tweens[prop] = hover_tween

func _react_prop(prop: Node3D) -> void:
	var data: Dictionary
	for entry in _props.values():
		if entry.node == prop:
			data = entry
			break
	if data.is_empty():
		return
	var previous: Tween = _prop_tweens.get(prop)
	if is_instance_valid(previous):
		previous.kill()
	var kind: StringName = data.kind
	var direction := -1.0 if prop.global_position.x < 0.0 else 1.0
	if kind == &"case":
		var case_reaction := create_tween()
		case_reaction.tween_property(prop, "rotation:z", direction * 0.012, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		case_reaction.tween_property(prop, "rotation:z", 0.0, 0.58).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		case_reaction.finished.connect(func(): _prop_tweens.erase(prop))
		_prop_tweens[prop] = case_reaction
		return
	var tilt := Vector3.ZERO
	var shift := Vector3.ZERO
	match kind:
		&"curtain":
			tilt = Vector3(0, direction * 0.18, -direction * 0.055)
			shift = Vector3(direction * 0.11, 0, -0.035)
		&"crown": tilt = Vector3(0.045, 0, 0.012)
		&"tassel": tilt = Vector3(0, 0, -direction * 0.34)
		&"antenna": tilt = Vector3(0, 0, -direction * 0.24)
		&"knob":
			tilt = Vector3(0, 0, 0.65)
			shift = Vector3(0, 0, -0.018)
			_flicker_screen()
	var rest_rotation: Vector3 = data.rotation
	var rest_position: Vector3 = data.position
	var reaction := create_tween().set_parallel(true)
	reaction.tween_property(prop, "rotation", rest_rotation + tilt, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.tween_property(prop, "position", rest_position + shift, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.chain().set_parallel(true)
	reaction.tween_property(prop, "rotation", rest_rotation, 0.58).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reaction.tween_property(prop, "position", rest_position, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reaction.finished.connect(func(): _prop_tweens.erase(prop))
	_prop_tweens[prop] = reaction

func _flicker_screen() -> void:
	if is_instance_valid(_screen_flicker):
		_screen_flicker.kill()
	_screen_material.albedo_color = Color.WHITE
	_screen_flicker = create_tween()
	_screen_flicker.tween_property(_screen_material, "albedo_color", Color(0.72, 0.76, 0.86), 0.055)
	_screen_flicker.tween_property(_screen_material, "albedo_color", Color.WHITE, 0.11).set_trans(Tween.TRANS_SINE)

func _on_selection_changed(index: int) -> void:
	if is_instance_valid(_dial):
		if is_instance_valid(_dial_tween):
			_dial_tween.kill()
		var target := Vector3(PI * 0.5, 0, float(index) * 0.35)
		_dial_tween = create_tween()
		_dial_tween.tween_property(_dial, "rotation", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _power_off_exit() -> void:
	if _transitioning:
		return
	_transitioning = true
	_dragging_dial = false
	_set_hovered_prop(null)
	if is_instance_valid(_screen_flicker):
		_screen_flicker.kill()
	ui.power_off()
	var shutdown := create_tween().set_parallel(true)
	shutdown.tween_property(_lower_knob, "rotation:z", -0.8, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shutdown.tween_property(_screen_material, "albedo_color", Color.BLACK, 0.52).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shutdown.tween_property(screen_glow, "light_energy", 0.0, 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shutdown.tween_property(_indicator_material, "emission", Color.BLACK, 0.45).set_delay(0.16)
	shutdown.tween_property(key_light, "light_energy", 0.24, 0.68)
	shutdown.tween_property(rim_light, "light_energy", 0.12, 0.68)
	await shutdown.finished
	get_tree().quit()

func _on_choice(choice: String) -> void:
	if _transitioning:
		return
	if choice == "options":
		PauseMenu.open_title_options()
		return
	if choice == "controls":
		PauseMenu.open_title_controls()
		return
	if choice == "exit":
		_power_off_exit()
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

func _update_camera_distance() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_fov := deg_to_rad(camera.fov) * 0.5
	_camera_distance = maxf(4.3, 4.45 / (2.0 * tan(half_fov) * aspect))
	if not _transitioning:
		camera.position.z = _camera_distance
		camera.look_at(Vector3(0, 1.75, 0))

func _build_stage() -> void:
	var cloth := _material(Color(0.34, 0.075, 0.17), 0.0, 0.96)
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var deep_cloth := _material(Color(0.25, 0.045, 0.13), 0.0, 0.96)
	deep_cloth.vertex_color_use_as_albedo = true
	deep_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var brass := _material(Color(0.49, 0.34, 0.19), 0.45, 0.48)
	var backdrop := _material(Color(0.026, 0.012, 0.033), 0.0, 1.0)
	_box(stage, "DarkBackdrop", Vector3(0, 1.9, -0.8), Vector3(8.0, 5.2, 0.12), backdrop)
	for side in [-1.0, 1.0]:
		var panel := Node3D.new()
		panel.name = "CurtainLeft" if side < 0.0 else "CurtainRight"
		panel.position = Vector3(side * 2.9, 1.72, 0.67)
		stage.add_child(panel)
		var panel_width := 1.0 if side < 0.0 else 1.32
		_curtain_mesh(panel, side, panel_width, 3.7, cloth)
		_register_prop(panel, Vector3(-side * 0.5, -0.05, 0), Vector3(1.0, 3.7, 0.2), &"curtain")
		var cord := Node3D.new()
		cord.name = "TasselLeft" if side < 0.0 else "TasselRight"
		cord.position = Vector3(side * 2.02, 1.0, 0.81)
		stage.add_child(cord)
		_cylinder(cord, "Cord", Vector3(0, 0.22, 0), 0.018, 0.49, brass)
		_gem(cord, "Tassel", Vector3(0, -0.09, 0), 0.085, brass)
		_register_prop(cord, Vector3(0, 0.13, 0), Vector3(0.2, 0.65, 0.2), &"tassel")
	var crown := Node3D.new()
	crown.name = "CurtainCrown"
	crown.position = Vector3(0, 3.88, 0.69)
	stage.add_child(crown)
	_crown_mesh(crown, deep_cloth)
	for side in [-1.0, 1.0]:
		_box(crown, "GoldHem", Vector3(side * 2.13, -0.84, 0.055), Vector3(1.65, 0.025, 0.025), brass)
		_register_prop(crown, Vector3(side * 2.13, -0.42, 0), Vector3(1.7, 0.9, 0.18), &"crown")

func _build_television() -> void:
	var casing := _material(Color(0.082, 0.091, 0.12), 0.42, 0.59)
	var edge := _material(Color(0.17, 0.2, 0.24), 0.56, 0.42)
	var shadow := _material(Color(0.009, 0.018, 0.03), 0.15, 0.82)
	var brass := _material(Color(0.73, 0.56, 0.34), 0.73, 0.27)
	var dark_brass := _material(Color(0.34, 0.29, 0.24), 0.54, 0.48)
	_indicator_material = _material(Color(0.95, 0.35, 0.52), 0.0, 0.3, Color(0.95, 0.35, 0.52))
	_box(tv, "OuterCase", Vector3.ZERO, Vector3(3.9, 2.75, 0.59), casing)
	_register_prop(tv, Vector3.ZERO, Vector3(3.9, 2.75, 0.59), &"case")
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
		var knob := Node3D.new()
		knob.name = "UpperKnob" if y > 0.0 else "LowerKnob"
		knob.position = Vector3(1.64, y, 0.46)
		tv.add_child(knob)
		var dial := _cylinder(knob, "Dial", Vector3.ZERO, 0.115, 0.08, dark_brass)
		dial.rotation.x = PI * 0.5
		_box(dial, "DialMark", Vector3(0, 0.046, 0.075), Vector3(0.025, 0.012, 0.05), brass)
		_register_prop(knob, Vector3.ZERO, Vector3(0.28, 0.28, 0.17), &"knob")
		if _dial == null:
			_upper_knob = knob
			_dial = dial
		else:
			_lower_knob = knob
	_box(tv, "PowerLamp", Vector3(1.64, -0.79, 0.43), Vector3(0.12, 0.07, 0.05), _indicator_material)
	for side in [-1.0, 1.0]:
		_box(tv, "Foot", Vector3(side * 1.35, -1.46, 0.05), Vector3(0.42, 0.23, 0.7), dark_brass)
		var aerial := Node3D.new()
		aerial.name = "AntennaLeft" if side < 0.0 else "AntennaRight"
		aerial.position = Vector3(side * 0.51, 1.22, 0.46)
		tv.add_child(aerial)
		var antenna := _cylinder(aerial, "Antenna", Vector3.ZERO, 0.024, 0.34, brass)
		antenna.rotation.z = -side * 0.35
		_gem(aerial, "AntennaTip", Vector3(side * 0.06, 0.18, 0), 0.06, brass)
		_register_prop(aerial, Vector3(side * 0.035, 0.09, 0), Vector3(0.2, 0.4, 0.2), &"antenna")

func _curtain_mesh(parent: Node3D, side: float, width: float, height: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 10:
		for row in 3:
			var u0 := float(column) / 10.0
			var u1 := float(column + 1) / 10.0
			var v0 := float(row) / 3.0
			var v1 := float(row + 1) / 3.0
			var shade := Color(0.72, 0.72, 0.72) if column % 2 == 0 else Color(1.0, 0.91, 0.95)
			var a := _curtain_point(side, width, height, u0, v0)
			var b := _curtain_point(side, width, height, u1, v0)
			var c := _curtain_point(side, width, height, u1, v1)
			var d := _curtain_point(side, width, height, u0, v1)
			_cloth_quad(surface, a, b, c, d, shade)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "FacetedFabric"
	mesh.mesh = surface.commit()
	mesh.material_override = material
	parent.add_child(mesh)

func _curtain_point(side: float, width: float, height: float, u: float, v: float) -> Vector3:
	var fold := sin(u * PI * 10.0) * 0.07
	var hem := sin(u * PI * 5.0) * 0.065
	return Vector3(-side * width * u, height * (0.5 - v) + hem * v, fold + 0.035 * v)

func _crown_mesh(parent: Node3D, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 16:
		var x0 := -2.98 + float(column) / 16.0 * 5.96
		var x1 := -2.98 + float(column + 1) / 16.0 * 5.96
		if x0 > -1.25 and x1 < 1.25:
			continue
		var z0 := 0.075 * sin(float(column) * PI * 0.5)
		var z1 := 0.075 * sin(float(column + 1) * PI * 0.5)
		var bottom0 := -0.85 + 0.055 * sin(float(column) * PI * 0.25)
		var bottom1 := -0.85 + 0.055 * sin(float(column + 1) * PI * 0.25)
		var shade := Color(0.76, 0.76, 0.76) if column % 2 == 0 else Color(1.0, 0.94, 0.96)
		_cloth_quad(surface, Vector3(x0, 0.1, z0), Vector3(x1, 0.1, z1), Vector3(x1, bottom1, z1), Vector3(x0, bottom0, z0), shade)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "FacetedCrown"
	mesh.mesh = surface.commit()
	mesh.material_override = material
	parent.add_child(mesh)

func _cloth_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for point in [a, b, c, a, c, d]:
		surface.set_color(color)
		surface.add_vertex(point)

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
