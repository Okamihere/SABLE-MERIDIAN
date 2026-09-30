extends Node

## Aplica o mesmo modelo de luz toon aos materiais físicos já usados pelo projeto.
## Preserva cores, texturas, vertex colors, emissão e recursos compartilhados.
## Efeitos transparentes e telas sem iluminação continuam com seu shader próprio.

func _ready() -> void:
	get_tree().node_added.connect(_style_node)
	_style_existing(get_tree().root)

func _style_existing(branch: Node) -> void:
	_style_node(branch)
	for child in branch.get_children():
		_style_existing(child)

func _style_node(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		_style_material(instance.material_override)
		if instance.mesh != null:
			for surface in instance.mesh.get_surface_count():
				_style_material(instance.get_surface_override_material(surface))
				_style_material(instance.mesh.surface_get_material(surface))
	elif node is CSGBox3D:
		_style_material((node as CSGBox3D).material)
	elif node is CSGCylinder3D:
		_style_material((node as CSGCylinder3D).material)

func _style_material(material: Material) -> void:
	if not material is StandardMaterial3D:
		return
	var standard := material as StandardMaterial3D
	if standard.has_meta(&"sable_cel_styled"):
		return
	standard.set_meta(&"sable_cel_styled", true)
	if standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	standard.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	standard.specular_mode = BaseMaterial3D.SPECULAR_TOON
