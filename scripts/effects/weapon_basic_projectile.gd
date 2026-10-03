extends Node3D

## Projétil/área dos ataques básicos; usa a mesma HitboxComponent dos golpes.
const HITBOX_SCRIPT := preload("res://scripts/components/hitbox_component.gd")

var _caster: PlayerController
var _target: Node3D
var _attack: AttackData
var _weapon_id: StringName
var _mode: String
var _direction := Vector3.FORWARD
var _speed := 20.0
var _range := 10.0
var _travelled := 0.0
var _elapsed := 0.0
var _spent := false
var _hitbox: HitboxComponent
var _visual: Node3D
var _color: Color

func activate(caster: PlayerController, weapon_id: StringName, attack: AttackData, mode: String, range: float, speed: float, direction: Vector3) -> void:
	_caster = caster
	_weapon_id = weapon_id
	_attack = attack
	_mode = mode
	_range = range
	_speed = speed
	_direction = direction.normalized()
	_target = caster.get_lock_target()
	var forward := caster.global_basis.z.normalized()
	global_position = caster.global_position + Vector3.UP * 1.2 + forward * 0.85
	if mode == "seal":
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + forward * range, 1 | 4)
		query.exclude = [caster.get_rid()]
		var wall := get_world_3d().direct_space_state.intersect_ray(query)
		var distance := range
		if not wall.is_empty():
			var clearance := 0.1 if wall.collider is Node and wall.collider.is_in_group("enemies") else 0.55
			distance = minf(range, global_position.distance_to(wall.position) - clearance)
		global_position = caster.global_position + Vector3.UP * 0.3 + forward * maxf(1.0, distance)
	else:
		look_at(global_position + _direction, Vector3.UP)
	_build_visual()
	_build_hitbox()

func _physics_process(delta: float) -> void:
	if _spent:
		return
	_elapsed += delta
	if _mode == "seal":
		_visual.rotation.y += delta * 2.8
		if _elapsed >= 0.36:
			_hitbox.end_attack()
			queue_free()
		return
	if is_instance_valid(_target):
		var toward := _target.global_position + Vector3.UP - global_position
		if toward.length_squared() > 0.04:
			_direction = _direction.slerp(toward.normalized(), clampf(3.5 * delta, 0.0, 1.0)).normalized()
	var step := _direction * _speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	ray.exclude = [_caster.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		_impact()
		return
	global_position += step
	_travelled += step.length()
	look_at(global_position + _direction, Vector3.UP)
	_visual.rotation.z += delta * (6.0 if _weapon_id == &"living_grimoire" else 3.0)
	if _travelled >= _range:
		_hitbox.end_attack()
		queue_free()

func _build_hitbox() -> void:
	var area := Area3D.new()
	area.set_script(HITBOX_SCRIPT)
	area.collision_layer = 8
	area.collision_mask = 32
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.25 if _mode == "seal" else (0.34 if _mode == "tether" else 0.42)
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	_hitbox = area as HitboxComponent
	_hitbox.source = _caster
	_hitbox.configure_from_attack(_attack)
	_hitbox.hit_landed.connect(_on_hit_landed)
	_hitbox.begin_attack()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "ArcaneVisual"
	add_child(_visual)
	match _weapon_id:
		&"staff": _color = Color(0.63, 0.34, 0.98) if _mode == "projectile" and _attack == _caster.equipment.weapon.heavy else Color(0.46, 0.27, 0.92)
		&"puppet_strings": _color = Color(0.35, 0.89, 0.95)
		&"living_grimoire": _color = Color(0.55, 0.42, 1.0)
		_: _color = Color(0.66, 0.35, 1.0)
	if _mode == "seal":
		_add_ring(1.9, false)
		_add_ring(1.35, false)
		for index in 8:
			var angle := index * TAU / 8.0
			_add_bar(Vector3(cos(angle) * 1.5, 0.06, sin(angle) * 1.5), Vector3(0.16, 0.035, 0.42), angle)
	elif _mode == "tether":
		for side in [-1.0, 0.0, 1.0]:
			_add_bar(Vector3(side * 0.1, 0, 0), Vector3(0.025, 0.025, 1.15), 0.0)
		if _attack.knockback < 0.0:
			_add_ring(0.26, true)
	elif _weapon_id == &"living_grimoire":
		_add_bar(Vector3(-0.19, 0, 0), Vector3(0.31, 0.43, 0.035), -0.22)
		_add_bar(Vector3(0.19, 0, 0), Vector3(0.31, 0.43, 0.035), 0.22)
		_add_ring(0.36, true)
	else:
		_add_ring(0.27 if _attack == _caster.equipment.weapon.heavy else 0.18, true)
		_add_bar(Vector3.ZERO, Vector3(0.42, 0.04, 0.04), PI * 0.25)
		_add_bar(Vector3.ZERO, Vector3(0.42, 0.04, 0.04), -PI * 0.25)

func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _color
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = 1.5
	return material

func _add_bar(at: Vector3, size: Vector3, tilt: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = at
	visual.rotation.y = tilt if _mode == "seal" else 0.0
	visual.rotation.z = 0.0 if _mode == "seal" else tilt
	_visual.add_child(visual)

func _add_ring(radius: float, vertical: bool) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.045
	mesh.outer_radius = radius
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.rotation.x = PI * 0.5 if vertical else 0.0
	_visual.add_child(visual)

func _on_hit_landed(hurtbox: HurtboxComponent, box: HitboxComponent) -> void:
	if is_instance_valid(_caster):
		_caster.combat.register_magic_hit(hurtbox, box)
	if _mode != "seal":
		_impact()

func _impact() -> void:
	if _spent:
		return
	_spent = true
	_hitbox.end_attack()
	var burst := Node3D.new()
	burst.name = "BasicArcaneImpact"
	var scene := get_tree().current_scene
	if scene == null:
		burst.queue_free()
		return
	scene.add_child(burst)
	burst.global_position = global_position
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.24
	mesh.outer_radius = 0.3
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = _material()
	burst.add_child(ring)
	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.4, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(burst.queue_free)
	queue_free()
