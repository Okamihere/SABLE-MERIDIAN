class_name HitboxComponent
extends Area3D

signal hit_landed(hurtbox: HurtboxComponent, hitbox: HitboxComponent)

@export var damage: float = 10.0
@export var knockback: float = 4.0
@export var hit_stun: float = 0.2
@export var launch_force: float = 0.0
@export var hit_stop_duration: float = 0.03
@export var attack_id: StringName = &"attack"
@export var style_points: int = 100
@export var source_path: NodePath = NodePath("../..")

var source: Node
var _already_hit: Dictionary = {}
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	monitoring = false
	monitorable = false
	source = get_node_or_null(source_path)
	area_entered.connect(_on_area_entered)
	_create_debug_mesh()

func configure_from_attack(data: AttackData) -> void:
	damage = data.damage
	knockback = data.knockback
	hit_stun = data.hit_stun
	launch_force = data.launch_force
	hit_stop_duration = data.hit_stop_duration
	attack_id = data.attack_id
	style_points = data.style_points

func begin_attack() -> void:
	_already_hit.clear()
	monitoring = true
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT

func end_attack() -> void:
	monitoring = false

func _process(_delta: float) -> void:
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT and monitoring

func _on_area_entered(area: Area3D) -> void:
	if not (area is HurtboxComponent):
		return
	var hurtbox := area as HurtboxComponent
	var instance_id := hurtbox.get_instance_id()
	if _already_hit.has(instance_id):
		return
	if is_instance_valid(source) and hurtbox.is_ancestor_of(source):
		return
	_already_hit[instance_id] = true
	if hurtbox.receive_hit(self):
		hit_landed.emit(hurtbox, self)

func _create_debug_mesh() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugHitbox"
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.18, 0.25, 0.28)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if shape_node.shape is BoxShape3D:
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
	elif shape_node.shape is CapsuleShape3D:
		var shape := shape_node.shape as CapsuleShape3D
		var mesh := CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		_debug_mesh.mesh = mesh
	else:
		return
	_debug_mesh.material_override = material
	add_child(_debug_mesh)
