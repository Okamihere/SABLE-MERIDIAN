class_name HurtboxComponent
extends Area3D

## Área que recebe golpes e os encaminha ao personagem responsável.
## Usa HealthComponent como alternativa quando não há receptor personalizado.

signal hit_received(hitbox: HitboxComponent)

@export var receiver_path: NodePath = NodePath("..")
@export var health_component_path: NodePath

var _receiver: Node
var _health: HealthComponent
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = (1 << 3) | (1 << 4)
	monitoring = true
	monitorable = true
	_receiver = get_node_or_null(receiver_path)
	if not health_component_path.is_empty():
		_health = get_node_or_null(health_component_path) as HealthComponent
	_create_debug_mesh()

func receive_hit(hitbox: HitboxComponent) -> bool:
	if not is_instance_valid(hitbox):
		return false
	if is_instance_valid(_receiver) and _receiver.has_method("receive_hitbox"):
		var accepted: bool = _receiver.call("receive_hitbox", hitbox)
		if accepted:
			hit_received.emit(hitbox)
		return accepted
	if is_instance_valid(_health):
		var result := _health.damage(hitbox.damage)
		if result:
			hit_received.emit(hitbox)
		return result
	return false

func _process(_delta: float) -> void:
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT

func _create_debug_mesh() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugHurtbox"
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.75, 1.0, 0.16)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if shape_node.shape is CapsuleShape3D:
		var shape := shape_node.shape as CapsuleShape3D
		var mesh := CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		_debug_mesh.mesh = mesh
	elif shape_node.shape is BoxShape3D:
		var shape := shape_node.shape as BoxShape3D
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		_debug_mesh.mesh = mesh
	elif shape_node.shape is SphereShape3D:
		var shape := shape_node.shape as SphereShape3D
		var mesh := SphereMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.radius * 2.0
		_debug_mesh.mesh = mesh
	else:
		return
	_debug_mesh.material_override = material
	add_child(_debug_mesh)
