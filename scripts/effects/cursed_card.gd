class_name CursedCard
extends Area3D

## Carta de impacto único que usa a mesma HurtboxComponent dos golpes do cajado.
@export var speed := 22.0
@export var lifetime := 1.6

@onready var hitbox: HitboxComponent = $Hitbox
@onready var visual: Node3D = $Visual

var _direction := Vector3.FORWARD
var _elapsed := 0.0
var _caster: Node3D
var _spent := false

func _ready() -> void:
	add_to_group("cursed_cards")
	body_entered.connect(_on_body_entered)
	hitbox.hit_landed.connect(_on_hit_landed)

func launch(caster: Node3D, direction: Vector3, damage: float) -> void:
	_caster = caster
	_direction = direction.normalized()
	look_at(global_position + _direction, Vector3.UP)
	hitbox.source = caster
	hitbox.damage = damage
	hitbox.knockback = 5.0
	hitbox.hit_stun = 0.24
	hitbox.attack_id = &"cursed_card"
	hitbox.style_points = 55
	hitbox.hit_stop_duration = 0.022
	hitbox.begin_attack()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	var next_position := global_position + _direction * speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, next_position, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		_spent = true
		hitbox.end_attack()
		queue_free()
		return
	global_position = next_position
	visual.rotation.z += delta * 13.0
	visual.scale = Vector3.ONE * (1.0 + 0.12 * sin(_elapsed * 18.0))

func _on_body_entered(body: Node3D) -> void:
	if _spent or body == _caster:
		return
	_spent = true
	hitbox.end_attack()
	queue_free()

func _on_hit_landed(hurtbox: HurtboxComponent, attack_hitbox: HitboxComponent) -> void:
	if _spent:
		return
	_spent = true
	if is_instance_valid(_caster) and _caster.get("combat") is CombatController:
		_caster.combat.register_magic_hit(hurtbox, attack_hitbox)
	hitbox.end_attack()
	queue_free()
