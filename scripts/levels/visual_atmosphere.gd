extends Node3D

## Detalhes visuais compartilhados pelas duas áreas de gameplay. Sem colisão.
@export var training_room := false

const STONE: Material = preload("res://materials/stone.tres")
const LIGHT_STONE: Material = preload("res://materials/stone_light.tres")
const ACCENT: Material = preload("res://materials/accent_magenta.tres")
const SMOKE_SHADER: Shader = preload("res://shaders/smoke_puff.gdshader")
const SHAFT_SHADER: Shader = preload("res://shaders/light_shaft.gdshader")
const CLOUD_SHADER: Shader = preload("res://shaders/cloud_mass.gdshader")

var _beam_material: ShaderMaterial
var _cloud_material: ShaderMaterial
var _smoke_material: ShaderMaterial
var _mote_material: StandardMaterial3D

func _ready() -> void:
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = SHAFT_SHADER
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CLOUD_SHADER
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = SMOKE_SHADER
	_mote_material = StandardMaterial3D.new()
	_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_material.albedo_color = Color(0.75, 0.43, 0.9, 1)
	_mote_material.emission_enabled = true
	_mote_material.emission = Color(0.55, 0.18, 0.75, 1)
	_mote_material.emission_energy_multiplier = 1.4
	if training_room:
		_build_training()
	else:
		_build_city()

func _build_training() -> void:
	_add_beam(Vector3(0.0, 5.0, -1.5), 6.4, 1.0)
	_add_beam(Vector3(-4.0, 4.6, 11.5), 6.8, 1.5)
	_add_beam(Vector3(4.0, 4.6, 11.5), 6.8, 1.5)
	_add_smoke(Vector3(-5.6, 0.8, 9.6), 1.5)
	_add_smoke(Vector3(5.6, 0.8, 9.6), 1.5)
	_add_motes(Vector3(0.0, 2.0, 10.5), 2.3)
	_add_monolith(Vector3(-12.0, 0.0, -8.0), 2.8)
	_add_monolith(Vector3(12.0, 0.0, -8.0), 3.3)
	_add_cloud(Vector3(-10.0, 10.5, 7.0), Vector3(6.0, 0.9, 2.4))
	_add_cloud(Vector3(8.0, 12.0, 15.0), Vector3(8.0, 1.0, 2.6))

func _build_city() -> void:
	_add_beam(Vector3(0.0, 5.8, 56.5), 6.2, 1.5)
	_add_beam(Vector3(-8.5, 9.2, -3.0), 14.0, 2.8)
	_add_beam(Vector3(8.5, 9.2, -3.0), 14.0, 2.8)
	_add_smoke(Vector3(-20.0, 1.0, 35.0), 3.0)
	_add_smoke(Vector3(20.0, 1.0, 35.0), 3.0)
	_add_smoke(Vector3(-8.0, 1.0, -5.0), 2.0)
	_add_smoke(Vector3(8.0, 1.0, -5.0), 2.0)
	_add_motes(Vector3(0.0, 2.2, 55.5), 2.8)
	_add_motes(Vector3(0.0, 1.8, 20.0), 2.5)
	for side in [-1.0, 1.0]:
		_add_monolith(Vector3(side * 24.0, 0.0, 41.0), 5.2)
		_add_monolith(Vector3(side * 19.0, 0.0, -18.0), 4.5)
	_add_cloud(Vector3(-35.0, 23.0, -20.0), Vector3(24.0, 2.2, 8.0))
	_add_cloud(Vector3(35.0, 26.0, 3.0), Vector3(27.0, 2.7, 9.0))
	_add_cloud(Vector3(0.0, 30.0, -78.0), Vector3(32.0, 2.5, 9.0))

func _add_beam(where: Vector3, height: float, radius: float) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "StageLightBeam"
	beam.position = where - Vector3(0.0, height * 0.5, 0.0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	beam.mesh = mesh
	beam.material_override = _beam_material
	add_child(beam)

func _add_smoke(where: Vector3, spread: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "LowSmoke"
	particles.position = where
	particles.amount = 14
	particles.lifetime = 4.2
	particles.preprocess = 4.2
	particles.visibility_aabb = AABB(Vector3(-spread * 2.0, -0.5, -spread * 2.0), Vector3(spread * 4.0, 4.0, spread * 4.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(spread, 0.15, spread)
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 20.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.22
	process.initial_velocity_max = 0.48
	process.scale_min = 0.6
	process.scale_max = 1.25
	particles.process_material = process
	var puff := SphereMesh.new()
	puff.radius = 0.72
	puff.height = 1.1
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = _smoke_material
	particles.draw_pass_1 = puff
	add_child(particles)

func _add_motes(where: Vector3, spread: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "StageMotes"
	particles.position = where
	particles.amount = 12
	particles.lifetime = 3.0
	particles.preprocess = 3.0
	particles.visibility_aabb = AABB(Vector3(-spread, -1.0, -spread), Vector3(spread * 2.0, 4.0, spread * 2.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(spread, 1.0, spread)
	process.direction = Vector3.UP
	process.spread = 24.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.38
	process.scale_min = 0.6
	process.scale_max = 1.3
	particles.process_material = process
	var mote := SphereMesh.new()
	mote.radius = 0.035
	mote.height = 0.07
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = _mote_material
	particles.draw_pass_1 = mote
	add_child(particles)

func _add_monolith(where: Vector3, height: float) -> void:
	var base := MeshInstance3D.new()
	base.name = "RuinMarker"
	base.position = where + Vector3(0.0, height * 0.5, 0.0)
	base.rotation_degrees.y = 14.0 if where.x < 0.0 else -11.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, height, 0.8)
	base.mesh = mesh
	base.material_override = LIGHT_STONE
	add_child(base)
	var cap := MeshInstance3D.new()
	cap.name = "RuinMarkerCap"
	cap.position = where + Vector3(0.0, height + 0.1, 0.0)
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.05, 0.18, 1.05)
	cap.mesh = cap_mesh
	cap.material_override = STONE
	add_child(cap)
	var rune := MeshInstance3D.new()
	rune.name = "RuinMarkerRune"
	rune.position = where + Vector3(0.0, height * 0.7, -0.42)
	var rune_mesh := BoxMesh.new()
	rune_mesh.size = Vector3(0.11, 0.65, 0.035)
	rune.mesh = rune_mesh
	rune.material_override = ACCENT
	add_child(rune)

func _add_cloud(where: Vector3, size: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.name = "LowPolyCloud"
	cloud.position = where
	add_child(cloud)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	for index in 3:
		var puff := MeshInstance3D.new()
		puff.name = "CloudMass"
		puff.mesh = mesh
		puff.material_override = _cloud_material
		match index:
			0:
				puff.scale = Vector3(size.x * 0.52, size.y * 1.6, size.z * 0.82)
			1:
				puff.position = Vector3(-size.x * 0.42, -size.y * 0.25, 0.0)
				puff.scale = Vector3(size.x * 0.36, size.y * 1.2, size.z * 0.7)
			2:
				puff.position = Vector3(size.x * 0.39, -size.y * 0.12, size.z * 0.1)
				puff.scale = Vector3(size.x * 0.39, size.y * 1.35, size.z * 0.72)
		cloud.add_child(puff)
