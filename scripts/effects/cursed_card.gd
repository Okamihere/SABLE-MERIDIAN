class_name CursedCard
extends Area3D

## Carta de impacto único que usa a mesma HurtboxComponent dos golpes do cajado.
@export var speed := 22.0
@export var lifetime := 1.6
@export var homing_strength := 5.0

@onready var hitbox: HitboxComponent = $Hitbox
@onready var visual: Node3D = $Visual

var _direction := Vector3.FORWARD
var _elapsed := 0.0
var _caster: Node3D
var _target: Node3D
var _spent := false

func _ready() -> void:
	add_to_group("cursed_cards")
	body_entered.connect(_on_body_entered)
	hitbox.hit_landed.connect(_on_hit_landed)

func launch(caster: Node3D, direction: Vector3, damage: float, attack: AttackData = null) -> void:
	_caster = caster
	_direction = direction.normalized()
	if caster.has_method("get_lock_target"):
		_target = caster.get_lock_target()
	hitbox.source = caster
	if attack != null:
		hitbox.configure_from_attack(attack)
	else:
		hitbox.damage = damage
		hitbox.knockback = 5.0
		hitbox.hit_stun = 0.24
		hitbox.attack_id = &"cursed_card"
		hitbox.style_points = 55
		hitbox.hit_stop_duration = 0.022
	hitbox.begin_attack()
	_update_facing()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	if is_instance_valid(_target):
		var toward := _target.global_position + Vector3.UP * 1.0 - global_position
		if toward.length_squared() > 0.04:
			_direction = _direction.slerp(toward.normalized(), clampf(homing_strength * delta, 0.0, 1.0)).normalized()
	var next_position := global_position + _direction * speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, next_position, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		_spent = true
		_show_impact()
		hitbox.end_attack()
		queue_free()
		return
	global_position = next_position
	_update_facing()

func _update_facing() -> void:
	var flat := Vector3(_direction.x, 0.0, _direction.z)
	if flat.length_squared() > 0.001:
		rotation.y = atan2(-flat.x, -flat.z)
	var spin := Quaternion(Vector3.UP, _elapsed * 5.5)
	var wobble := Quaternion(Vector3.RIGHT, 0.055 * sin(_elapsed * 10.0))
	visual.quaternion = spin * wobble * Quaternion(Vector3.RIGHT, -PI * 0.5)

func _on_body_entered(body: Node3D) -> void:
	if _spent or body == _caster:
		return
	_spent = true
	_show_impact()
	hitbox.end_attack()
	queue_free()

func _on_hit_landed(hurtbox: HurtboxComponent, attack_hitbox: HitboxComponent) -> void:
	if _spent:
		return
	_spent = true
	_show_impact()
	if is_instance_valid(_caster) and _caster.get("combat") is CombatController:
		_caster.combat.register_magic_hit(hurtbox, attack_hitbox)
	hitbox.end_attack()
	queue_free()

func _show_impact() -> void:
	var burst := Node3D.new()
	burst.name = "CursedCardImpact"
	var scene := get_tree().current_scene
	if scene == null:
		burst.queue_free()
		return
	scene.add_child(burst)
	burst.global_position = global_position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.62, 0.25, 1.0, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.5, 0.1, 0.95)
	material.emission_energy_multiplier = 1.8
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.23
	mesh.outer_radius = 0.28
	for axis in [Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0)]:
		var seal := MeshInstance3D.new()
		seal.mesh = mesh
		seal.material_override = material
		seal.rotation = axis
		burst.add_child(seal)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 2.6, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.finished.connect(burst.queue_free)
