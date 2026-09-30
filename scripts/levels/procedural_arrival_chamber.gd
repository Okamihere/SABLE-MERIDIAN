extends Node3D

## Câmara de chegada montada antes do primeiro quadro visível da cidade.
## A planta é estável; os detalhes variam com uma semente fixa para manter a
## composição e as colisões previsíveis entre carregamentos.

const STONE: Material = preload("res://materials/stone.tres")
const LIGHT_STONE: Material = preload("res://materials/stone_light.tres")
const ACCENT: Material = preload("res://materials/accent_magenta.tres")

var _body: StaticBody3D

func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "ArchitectureCollision"
	add_child(_body)
	_build_room()

func _build_room() -> void:
	# A laje da cidade já sustenta o jogador. O tapete fino só marca a rota.
	_visual_box("Runner", Vector3(0, 0.025, 64.0), Vector3(8.0, 0.05, 18.0), LIGHT_STONE)
	_solid_box("WestWall", Vector3(-7.8, 2.8, 64.3), Vector3(0.7, 5.6, 19.0), LIGHT_STONE)
	_solid_box("EastWall", Vector3(7.8, 2.8, 64.3), Vector3(0.7, 5.6, 19.0), LIGHT_STONE)
	_solid_box("RearWall", Vector3(0, 2.8, 73.8), Vector3(16.2, 5.6, 0.7), STONE)
	_solid_box("Ceiling", Vector3(0, 5.85, 64.3), Vector3(16.2, 0.6, 19.0), STONE)
	_solid_box("ExitWest", Vector3(-6.45, 2.8, 54.8), Vector3(2.7, 5.6, 0.9), LIGHT_STONE)
	_solid_box("ExitEast", Vector3(6.45, 2.8, 54.8), Vector3(2.7, 5.6, 0.9), LIGHT_STONE)
	_solid_box("ExitLintel", Vector3(0, 5.1, 54.8), Vector3(10.2, 1.0, 0.9), LIGHT_STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 230519
	for side in [-1.0, 1.0]:
		for index in 4:
			var z := 57.2 + index * 4.6
			var width := rng.randf_range(0.42, 0.6)
			_solid_box("Pilaster_%s_%s" % [int(side), index], Vector3(side * 7.12, 2.75, z), Vector3(width, 5.5, 0.85), STONE)
			_visual_box("Inlay_%s_%s" % [int(side), index], Vector3(side * 6.79, 3.5, z), Vector3(0.07, 2.1, 0.12), ACCENT)
	_visual_box("RearSigil", Vector3(0, 3.1, 73.4), Vector3(3.4, 2.2, 0.1), ACCENT)
	_add_glow("ArrivalBlue", Vector3(0, 4.0, 68), Color(0.55, 0.64, 0.95), 2.4, 14.0)
	_add_glow("ExitRose", Vector3(0, 4.3, 56), Color(0.84, 0.22, 0.51), 1.4, 11.0)

func _solid_box(label: String, where: Vector3, size: Vector3, material: Material) -> void:
	_visual_box(label, where, size, material)
	var collision := CollisionShape3D.new()
	collision.name = label + "Shape"
	collision.position = where
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	_body.add_child(collision)

func _visual_box(label: String, where: Vector3, size: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.position = where
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = material
	add_child(piece)

func _add_glow(label: String, where: Vector3, color: Color, energy: float, radius: float) -> void:
	var glow := OmniLight3D.new()
	glow.name = label
	glow.position = where
	glow.light_color = color
	glow.light_energy = energy
	glow.omni_range = radius
	glow.shadow_enabled = false
	add_child(glow)
