class_name BasicEnemy
extends CharacterBody3D

## Inimigo básico com perseguição, antecipação de ataque, dano e lançamento.
## Usa separação entre vizinhos; navegação com desvio de obstáculos ainda é futura.

enum State { IDLE, CHASE, ATTACK, HIT, LAUNCHED, DEAD }

@export var move_speed: float = 3.7
@export var acceleration: float = 14.0
@export var rotation_speed: float = 8.0
@export var gravity: float = 24.0
@export var detection_range: float = 18.0
@export var preferred_distance: float = 2.4
@export var attack_range: float = 2.8
@export var attack_cooldown: float = 1.25
@export var separation_radius: float = 1.8
@export var separation_strength: float = 2.4

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var visual: Node3D = $Visual

var state: State = State.IDLE
var _player: Node3D
var _attack_cooldown_left: float = 0.5
var _attack_elapsed: float = 0.0
var _attack_live: bool = false
var _hit_stun_left: float = 0.0
var _dead: bool = false

const ATTACK_WINDUP := 0.42
const ATTACK_ACTIVE := 0.16
const ATTACK_RECOVERY := 0.42

func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_on_died)
	attack_hitbox.damage = 12.0
	attack_hitbox.knockback = 6.0
	attack_hitbox.hit_stun = 0.32
	attack_hitbox.launch_force = 2.0
	attack_hitbox.hit_stop_duration = 0.025
	attack_hitbox.attack_id = &"enemy_swipe"
	attack_hitbox.source = self

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_player = GameManager.player as Node3D
	if not is_on_floor():
		velocity.y -= gravity * delta
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	match state:
		State.IDLE, State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.HIT:
			_update_hit(delta)
		State.LAUNCHED:
			_update_launched(delta)
	move_and_slide()
	if state == State.LAUNCHED and is_on_floor() and velocity.y <= 0.0:
		state = State.HIT
		_hit_stun_left = 0.26

func _update_chase(delta: float) -> void:
	if not is_instance_valid(_player) or (_player.has_method("is_alive") and not _player.call("is_alive")):
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance > detection_range:
		state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return
	state = State.CHASE
	if distance <= attack_range and _attack_cooldown_left <= 0.0:
		_start_attack()
		return
	var direction := to_player.normalized() if distance > 0.01 else Vector3.ZERO
	var separation := _separation_vector()
	var desired := (direction + separation * separation_strength).normalized()
	var speed_scale := clampf((distance - preferred_distance) / 3.0, 0.2, 1.0)
	velocity.x = move_toward(velocity.x, desired.x * move_speed * speed_scale, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z * move_speed * speed_scale, acceleration * delta)
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), clampf(rotation_speed * delta, 0.0, 1.0))

func _start_attack() -> void:
	state = State.ATTACK
	_attack_elapsed = 0.0
	_attack_live = false
	velocity.x = 0.0
	velocity.z = 0.0
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.08, 0.92, 1.08), ATTACK_WINDUP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "scale", Vector3.ONE, ATTACK_ACTIVE + ATTACK_RECOVERY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_attack(delta: float) -> void:
	_attack_elapsed += delta
	if is_instance_valid(_player):
		var direction := _player.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.01 and _attack_elapsed < ATTACK_WINDUP * 0.75:
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), clampf(rotation_speed * delta, 0.0, 1.0))
	if not _attack_live and _attack_elapsed >= ATTACK_WINDUP and _attack_elapsed < ATTACK_WINDUP + ATTACK_ACTIVE:
		attack_hitbox.begin_attack()
		_attack_live = true
		velocity += global_transform.basis.z * 3.0
	elif _attack_live and _attack_elapsed >= ATTACK_WINDUP + ATTACK_ACTIVE:
		attack_hitbox.end_attack()
		_attack_live = false
	if _attack_elapsed >= ATTACK_WINDUP + ATTACK_ACTIVE + ATTACK_RECOVERY:
		state = State.CHASE
		_attack_cooldown_left = attack_cooldown

func _update_hit(delta: float) -> void:
	_hit_stun_left -= delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if _hit_stun_left <= 0.0:
		state = State.CHASE

func _update_launched(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2.5 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 2.5 * delta)

func receive_hitbox(hitbox: HitboxComponent) -> bool:
	if _dead:
		return false
	if not health.damage(hitbox.damage):
		return false
	if _dead:
		return true
	attack_hitbox.end_attack()
	_attack_live = false
	var source_position := global_position - global_transform.basis.z
	if is_instance_valid(hitbox.source) and hitbox.source is Node3D:
		source_position = (hitbox.source as Node3D).global_position
	var direction := global_position - source_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = global_transform.basis.z
	direction = direction.normalized()
	velocity.x = direction.x * hitbox.knockback
	velocity.z = direction.z * hitbox.knockback
	if hitbox.launch_force > 0.0:
		velocity.y = maxf(velocity.y, hitbox.launch_force)
		state = State.LAUNCHED
	else:
		state = State.HIT
		_hit_stun_left = hitbox.hit_stun
	_flash_hit()
	return true

func is_alive() -> bool:
	return not _dead

func get_state_name() -> String:
	return State.keys()[state]

func _separation_vector() -> Vector3:
	var result := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node3D):
			continue
		var offset := global_position - (other as Node3D).global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001 and distance < separation_radius:
			result += offset.normalized() * (1.0 - distance / separation_radius)
	return result

func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.18, 0.82, 1.18), 0.045)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_died() -> void:
	_dead = true
	state = State.DEAD
	attack_hitbox.end_attack()
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", deg_to_rad(90.0), 0.22)
	tween.parallel().tween_property(visual, "scale", Vector3.ZERO, 0.42).set_delay(0.15)
	tween.tween_callback(queue_free)
