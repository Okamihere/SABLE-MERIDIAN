extends Node3D

## Assinatura visual curta dos golpes que já passam pelo CombatController.
var _material: StandardMaterial3D

func activate(caster: Node3D, weapon_id: StringName, heavy: bool) -> void:
	var forward := caster.global_basis.z.normalized()
	global_position = caster.global_position + Vector3.UP * (0.28 if weapon_id == &"living_grimoire" and heavy else 1.25) + forward * (1.0 if heavy else 0.9)
	look_at(global_position + forward, Vector3.UP, true)
	var color := Color(0.58, 0.34, 1.0)
	match weapon_id:
		&"card_daggers": color = Color(0.85, 0.27, 0.9)
		&"puppet_strings": color = Color(0.3, 0.82, 0.94)
		&"cane_blade": color = Color(1.0, 0.69, 0.34)
		&"living_grimoire": color = Color(0.55, 0.38, 1.0)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 1.35
	match weapon_id:
		&"staff":
			if heavy:
				_ring(1.0)
				_bar(Vector3(0, 0.2, 0), Vector3(1.7, 0.07, 0.06), 0.0)
			else:
				_bar(Vector3(-0.2, 0.0, 0), Vector3(1.3, 0.06, 0.06), -0.55)
				_bar(Vector3(0.2, 0.12, 0.05), Vector3(0.8, 0.035, 0.04), -0.55)
		&"card_daggers":
			if heavy:
				_diamond(0.78)
				_bar(Vector3(0, 0, 0.1), Vector3(1.2, 0.05, 0.04), 0.7)
			else:
				_bar(Vector3(-0.25, 0.1, 0), Vector3(0.62, 0.3, 0.025), -0.4)
				_bar(Vector3(0.25, -0.1, 0.08), Vector3(0.62, 0.3, 0.025), 0.4)
		&"puppet_strings":
			if heavy:
				_ring(0.9)
				for side in [-1.0, 1.0]:
					_bar(Vector3(side * 0.54, 0, 0), Vector3(0.035, 1.1, 0.04), side * 0.3)
			else:
				for side in [-1.0, 0.0, 1.0]:
					_bar(Vector3(side * 0.18, 0, side * 0.08), Vector3(0.025, 0.025, 2.1), side * 0.1)
		&"cane_blade":
			if heavy:
				_bar(Vector3(0, 0.1, 0), Vector3(2.2, 0.075, 0.05), 0.55)
				_bar(Vector3(0, -0.08, 0.08), Vector3(1.6, 0.035, 0.04), 0.55)
			else:
				_bar(Vector3(0, 0, 0.55), Vector3(0.06, 0.055, 2.3), 0.0)
				_diamond(0.32)
		&"living_grimoire":
			if heavy:
				_ring(1.45)
				_diamond(0.85)
			else:
				_diamond(0.68)
				_bar(Vector3(-0.3, 0.0, 0.05), Vector3(0.4, 0.55, 0.025), -0.25)
				_bar(Vector3(0.3, 0.0, 0.05), Vector3(0.4, 0.55, 0.025), 0.25)
	create_tween().tween_property(_material, "albedo_color:a", 0.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	get_tree().create_timer(0.38).timeout.connect(queue_free)

func _bar(at: Vector3, size: Vector3, tilt: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = at
	visual.rotation.z = tilt
	add_child(visual)

func _ring(radius: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.055
	mesh.outer_radius = radius
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.rotation.x = PI * 0.5
	add_child(visual)

func _diamond(radius: float) -> void:
	for side in 4:
		var angle := (side + 0.5) * TAU / 4.0
		_bar(Vector3(cos(angle) * radius * 0.7, sin(angle) * radius * 0.7, 0), Vector3(radius, 0.04, 0.035), -angle)
