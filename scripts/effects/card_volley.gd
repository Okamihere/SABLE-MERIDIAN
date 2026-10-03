extends Node3D

## Efeito do Baralho Maldito. Uma carta isolada vira um leque ao ser tecida no combo.
const CARD_SCENE: PackedScene = preload("res://scenes/effects/cursed_card.tscn")

func activate(caster: Node3D, spell: SpellResource) -> void:
	var forward := caster.global_basis.z.normalized()
	var target: Node3D = null
	if caster.has_method("get_lock_target"):
		target = caster.get_lock_target()
	if is_instance_valid(target):
		forward = (target.global_position + Vector3.UP * 1.0 - caster.global_position - Vector3.UP * 1.35).normalized()
	var chain := 0
	if caster.get("combat") is CombatController:
		chain = caster.combat.get_chain_index()
	var offsets: Array[float] = []
	if chain >= 2:
		offsets.assign([-0.16, 0.0, 0.16])
	else:
		offsets.append(0.0)
	for index in offsets.size():
		var card := CARD_SCENE.instantiate() as CursedCard
		var scene := get_tree().current_scene
		if scene == null:
			card.queue_free()
			return
		scene.add_child(card)
		var angle := offsets[index]
		var direction := forward.rotated(Vector3.UP, angle).normalized()
		card.global_position = caster.global_position + Vector3.UP * 1.35 + forward * 0.85 + caster.global_basis.x * (index - (offsets.size() - 1) * 0.5) * 0.22
		card.launch(caster, direction, spell.damage * (0.54 if offsets.size() > 1 else 1.0))
	_show_flourish(caster.global_position + Vector3.UP * 1.35 + forward * 0.55, forward)

func _show_flourish(origin: Vector3, forward: Vector3) -> void:
	global_position = origin
	look_at(origin + forward, Vector3.UP)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.31
	mesh.outer_radius = 0.37
	ring.mesh = mesh
	ring.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.67, 0.3, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.47, 0.1, 0.96)
	material.emission_energy_multiplier = 2.4
	ring.material_override = material
	ring.scale = Vector3.ONE * 0.4
	add_child(ring)
	for index in 8:
		var rune := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.035, 0.13, 0.035)
		rune.mesh = bar
		rune.position = Vector3(cos(index * TAU / 8.0) * 0.39, sin(index * TAU / 8.0) * 0.39, 0)
		rune.rotation.z = index * TAU / 8.0
		rune.material_override = material
		add_child(rune)
		create_tween().tween_property(rune, "position", rune.position * 1.7, 0.28)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.28)
	tween.finished.connect(queue_free)
