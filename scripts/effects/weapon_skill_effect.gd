extends Node3D

## Efeitos das skills de arma. Dano passa pelas hitboxes normais do combate.
const CARD := preload("res://scenes/effects/cursed_card.tscn")
const HITBOX_SCRIPT := preload("res://scripts/components/hitbox_component.gd")

var _caster: PlayerController
var _spell: SpellResource
var _age := 0.0
var _duration := 0.65
var _direction := Vector3.FORWARD
var _hitbox: HitboxComponent

func activate(caster: Node3D, spell: SpellResource) -> void:
	_caster = caster as PlayerController
	_spell = spell
	_direction = caster.global_basis.z.normalized()
	var target := _caster.get_lock_target()
	if is_instance_valid(target):
		_direction = (target.global_position - caster.global_position).normalized()
		_direction.y = 0.0
		_direction = _direction.normalized()
	global_position = caster.global_position + Vector3.UP * 1.15 + _direction * 1.1
	look_at(global_position + _direction, Vector3.UP, true)
	match spell.ability_id:
		&"dagger_q":
			_cards(3, 0.23, 1.0)
			_glyph(Color(0.8, 0.25, 1.0), 0.75, 0.35)
		&"dagger_e":
			_glyph(Color(0.8, 0.25, 1.0), 0.9, 0.45)
			_safe_advance(3.0)
			_caster.velocity.x = _direction.x * 10.0
			_caster.velocity.z = _direction.z * 10.0
			_caster._skill_guard_until = Time.get_ticks_msec() / 1000.0 + 0.22
			_hit(Vector3(1.5, 1.5, 1.7), 0.3, 3.0, 0.22, 0.0)
		&"dagger_r":
			_trap(Color(0.68, 0.13, 0.9), 1.8, 2.4, 0.95)
		&"staff_e":
			_ring(Color(0.52, 0.28, 1.0), 2.35, 0.45)
			_hit(Vector3(4.7, 1.4, 4.7), 0.38, 11.0, 0.5, 0.0)
		&"staff_r":
			_lance(Color(0.86, 0.55, 1.0), 5.0, 0.85)
			_hit(Vector3(1.25, 2.5, 5.0), 0.55, 6.0, 0.35, 10.0)
		&"strings_q":
			_lance(Color(0.34, 0.86, 0.94), 4.4, 0.22)
			_hit(Vector3(0.8, 1.5, 4.5), 0.45, -9.0, 0.45, 0.0)
		&"strings_e":
			_glyph(Color(0.36, 0.89, 0.96), 1.4, 0.6)
			_hit(Vector3(2.5, 2.2, 3.3), 0.42, 0.0, 0.4, 11.0)
		&"strings_r":
			_trap(Color(0.33, 0.8, 0.95), 2.3, 3.0, 1.4)
		&"cane_q":
			_lance(Color(1.0, 0.8, 0.44), 3.2, 0.3)
			_hit(Vector3(0.85, 1.3, 3.3), 0.25, 8.0, 0.27, 0.0)
		&"cane_e":
			_ring(Color(1.0, 0.82, 0.37), 1.2, 0.42)
			_caster._skill_guard_until = Time.get_ticks_msec() / 1000.0 + 0.42
		&"cane_r":
			_safe_advance(2.2)
			global_position = _caster.global_position + Vector3.UP * 1.15 + _direction * 0.8
			_caster.velocity.x = _direction.x * 13.0
			_caster.velocity.z = _direction.z * 13.0
			_slash(Color(1.0, 0.67, 0.36), 0.85)
			_hit(Vector3(2.6, 1.5, 3.4), 0.48, 10.0, 0.42, 0.0)
		&"grimoire_q":
			_cards(1, 0.0, 1.4)
			_glyph(Color(0.52, 0.37, 1.0), 0.9, 0.4)
		&"grimoire_e":
			_trap(Color(0.47, 0.35, 1.0), 2.0, 3.4, 0.65)
		&"grimoire_r":
			global_position = caster.global_position + Vector3.UP * 0.25
			_ring(Color(0.67, 0.38, 1.0), 3.4, 0.9)
			_hit(Vector3(6.8, 2.0, 6.8), 0.65, 15.0, 0.65, 5.0)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()

func _safe_advance(distance: float) -> void:
	var space := get_world_3d().direct_space_state
	var from := _caster.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, from + _direction * distance, 1)
	var collision := space.intersect_ray(query)
	var allowed := distance
	if not collision.is_empty():
		allowed = maxf(0.0, from.distance_to(collision.position) - 0.65)
	_caster.global_position += _direction * allowed

func _hit(size: Vector3, duration: float, knockback: float, stun: float, launch: float) -> void:
	var area := Area3D.new()
	area.set_script(HITBOX_SCRIPT)
	area.collision_layer = 8
	area.collision_mask = 32
	add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(0, 0, size.z * 0.25 if size.z > size.x else 0.0)
	_hitbox = area as HitboxComponent
	_hitbox.source = _caster
	_hitbox.damage = _spell.damage
	_hitbox.knockback = knockback
	_hitbox.hit_stun = stun
	_hitbox.launch_force = launch
	_hitbox.attack_id = _spell.ability_id
	_hitbox.style_points = 95
	_hitbox.hit_landed.connect(func(hurtbox: HurtboxComponent, box_hit: HitboxComponent) -> void: _caster.combat.register_magic_hit(hurtbox, box_hit))
	_hitbox.begin_attack()
	var hb := _hitbox
	get_tree().create_timer(duration).timeout.connect(func() -> void: if is_instance_valid(hb): hb.end_attack())

func _cards(count: int, spread: float, multiplier: float) -> void:
	for i in count:
		var card := CARD.instantiate() as CursedCard
		var scene := get_tree().current_scene
		if scene == null:
			card.queue_free()
			return
		scene.add_child(card)
		card.global_position = global_position + Vector3.UP * 0.2 + _caster.global_basis.x * (i - (count - 1) * 0.5) * 0.32
		card.launch(_caster, _direction.rotated(Vector3.UP, (i - (count - 1) * 0.5) * spread), _spell.damage * multiplier)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material

func _ring(color: Color, radius: float, time: float) -> void:
	_duration = maxf(_duration, time)
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.08
	mesh.outer_radius = radius
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.rotation.x = PI * 0.5
	add_child(visual)
	visual.scale = Vector3.ONE * 0.12
	create_tween().tween_property(visual, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_CUBIC)

func _glyph(color: Color, radius: float, time: float) -> void:
	_duration = maxf(_duration, time)
	for i in 4:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, radius * 1.5, 0.04)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = _material(color)
		visual.rotation.z = i * PI / 4.0
		add_child(visual)
		create_tween().tween_property(visual, "rotation:z", visual.rotation.z + PI * 0.5, time)

func _lance(color: Color, length: float, time: float) -> void:
	_duration = maxf(_duration, time)
	for i in 3:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.06, length)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = Vector3((i - 1) * 0.18, (i - 1) * 0.22, length * 0.35)
		visual.material_override = _material(color)
		add_child(visual)

func _slash(color: Color, time: float) -> void:
	_duration = maxf(_duration, time)
	for i in 3:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.5 - i * 0.32, 0.055, 0.06)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = Vector3(0, (i - 1) * 0.24, 0.4 + i * 0.14)
		visual.rotation.z = 0.55 + i * 0.1
		visual.material_override = _material(color)
		add_child(visual)
		create_tween().tween_property(visual, "rotation:z", visual.rotation.z + 1.15, time)

func _trap(color: Color, radius: float, time: float, stun: float) -> void:
	_duration = time
	global_position += _direction * 1.1
	global_position.y = _caster.global_position.y + 0.3
	_ring(color, radius, 0.38)
	_hit(Vector3(radius * 2.0, 1.4, radius * 2.0), time, 0.0, stun, 0.0)
