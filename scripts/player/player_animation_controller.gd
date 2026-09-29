class_name PlayerAnimationController
extends Node

## PlayerAnimationController
##
## Drives the player's AnimationTree based on the current PlayerStateMachine state.
## Uses a combination of AnimationTree (for locomotion) and procedural animation
## (for combat, dodge, hit, and death states).
##
## Architecture:
## - Skeleton3D with named bones (Hips, Spine, Head, Arms, Legs)
## - AnimationTree with AnimationNodeStateMachine for locomotion (idle/walk)
## - Procedural animation for combat/dodge/hit/death states
## - State machine drives transitions via blend times

@export var skeleton_path: NodePath = NodePath("../Skeleton3D")
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")
@export var state_machine_path: NodePath = NodePath("../StateMachine")
@export var combat_controller_path: NodePath = NodePath("../CombatController")

@export var locomotion_blend_speed: float = 8.0
@export var turn_blend_speed: float = 10.0

var _skeleton: Skeleton3D
var _animation_tree: AnimationTree
var _state_machine: PlayerStateMachine
var _combat: CombatController

# Procedural animation state
var _time: float = 0.0
var _movement_blend: float = 0.0
var _turn_blend: float = 0.0
var _airborne_blend: float = 0.0
var _attack_blend: float = 0.0
var _dodge_blend: float = 0.0
var _hit_blend: float = 0.0
var _dead_blend: float = 0.0

# Bone references for procedural animation
var _hips_bone: int = -1
var _spine_bone: int = -1
var _head_bone: int = -1
var _left_arm_bone: int = -1
var _right_arm_bone: int = -1
var _left_leg_bone: int = -1
var _right_leg_bone: int = -1

# Attack animation state
var _attack_time: float = 0.0
var _attack_duration: float = 0.0
var _attack_type: StringName = &""

# Dodge animation state
var _dodge_time: float = 0.0
var _dodge_duration: float = 0.34

# Hit animation state
var _hit_time: float = 0.0
var _hit_duration: float = 0.3

# Dead animation state
var _dead_time: float = 0.0

func _ready() -> void:
	_skeleton = get_node(skeleton_path) as Skeleton3D
	_animation_tree = get_node(animation_tree_path) as AnimationTree
	_state_machine = get_node(state_machine_path) as PlayerStateMachine
	_combat = get_node(combat_controller_path) as CombatController
	
	_cache_bones()
	_setup_animation_tree()
	_connect_signals()

func _cache_bones() -> void:
	if _skeleton == null:
		return
	_hips_bone = _skeleton.find_bone(&"Hips")
	_spine_bone = _skeleton.find_bone(&"Spine")
	_head_bone = _skeleton.find_bone(&"Head")
	_left_arm_bone = _skeleton.find_bone(&"LeftArm")
	_right_arm_bone = _skeleton.find_bone(&"RightArm")
	_left_leg_bone = _skeleton.find_bone(&"LeftLeg")
	_right_leg_bone = _skeleton.find_bone(&"RightLeg")

func _setup_animation_tree() -> void:
	if _animation_tree == null:
		return
	_animation_tree.active = true

func _connect_signals() -> void:
	if _state_machine != null:
		_state_machine.state_changed.connect(_on_state_changed)
	if _combat != null:
		# Combat signals would be connected here if needed
		pass

func _process(delta: float) -> void:
	_time += delta
	_update_blends(delta)
	_update_procedural_animation()

func _update_blends(delta: float) -> void:
	if _state_machine == null:
		return
	
	var target_movement := 0.0
	var target_airborne := 0.0
	var target_attack := 0.0
	var target_dodge := 0.0
	var target_hit := 0.0
	var target_dead := 0.0
	
	match _state_machine.state:
		PlayerStateMachine.State.IDLE:
			target_movement = 0.0
		PlayerStateMachine.State.MOVE:
			target_movement = 1.0
		PlayerStateMachine.State.JUMP:
			target_airborne = 1.0
		PlayerStateMachine.State.FALL:
			target_airborne = 1.0
		PlayerStateMachine.State.DODGE:
			target_dodge = 1.0
		PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK:
			target_attack = 1.0
		PlayerStateMachine.State.HIT:
			target_hit = 1.0
		PlayerStateMachine.State.DEAD:
			target_dead = 1.0
	
	_movement_blend = lerp(_movement_blend, target_movement, clampf(locomotion_blend_speed * delta, 0.0, 1.0))
	_airborne_blend = lerp(_airborne_blend, target_airborne, clampf(locomotion_blend_speed * delta, 0.0, 1.0))
	_attack_blend = lerp(_attack_blend, target_attack, clampf(12.0 * delta, 0.0, 1.0))
	_dodge_blend = lerp(_dodge_blend, target_dodge, clampf(14.0 * delta, 0.0, 1.0))
	_hit_blend = lerp(_hit_blend, target_hit, clampf(16.0 * delta, 0.0, 1.0))
	_dead_blend = lerp(_dead_blend, target_dead, clampf(6.0 * delta, 0.0, 1.0))

func _update_procedural_animation() -> void:
	if _skeleton == null:
		return
	
	# Reset to rest pose
	_reset_bones()
	
	# Apply locomotion
	if _movement_blend > 0.01:
		_apply_locomotion()
	
	# Apply airborne
	if _airborne_blend > 0.01:
		_apply_airborne()
	
	# Apply attack
	if _attack_blend > 0.01:
		_apply_attack()
	
	# Apply dodge
	if _dodge_blend > 0.01:
		_apply_dodge()
	
	# Apply hit
	if _hit_blend > 0.01:
		_apply_hit()
	
	# Apply dead
	if _dead_blend > 0.01:
		_apply_dead()

func _reset_bones() -> void:
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3.ZERO)
		_skeleton.set_bone_pose_rotation(_hips_bone, Quaternion.IDENTITY)
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.IDENTITY)
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.IDENTITY)
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.IDENTITY)
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.IDENTITY)
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.IDENTITY)
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.IDENTITY)

func _apply_locomotion() -> void:
	var walk_cycle := _time * 8.0
	var swing := sin(walk_cycle) * 0.4 * _movement_blend
	
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(swing, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(-swing, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-swing * 0.6, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(swing * 0.6, 0.0, 0.0)))
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(0.05 * _movement_blend, 0.0, 0.0)))

func _apply_airborne() -> void:
	var t := clampf(_airborne_blend, 0.0, 1.0)
	
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(-0.3 * t, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(0.2 * t, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-0.4 * t, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-0.4 * t, 0.0, 0.0)))
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-0.1 * t, 0.0, 0.0)))

func _apply_attack() -> void:
	if _attack_duration <= 0.0:
		return
	
	var t := clampf(_attack_time / _attack_duration, 0.0, 1.0)
	
	# Attack curve: windup -> strike -> recover
	var windup := 0.25
	var strike := 0.45
	
	var attack_angle: float
	if t < windup:
		attack_angle = -1.2 * (t / windup)
	elif t < strike:
		attack_angle = -1.2 + 2.4 * ((t - windup) / (strike - windup))
	else:
		attack_angle = 1.2 * (1.0 - (t - strike) / (1.0 - strike))
	
	var heavy := _attack_type == &"heavy" or _attack_type == &"launcher"
	var multiplier := 1.3 if heavy else 1.0
	
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(attack_angle * multiplier, 0.0, 0.0)))
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(0.0, -0.3 * multiplier * sin(t * PI), 0.0)))

func _apply_dodge() -> void:
	var t := clampf(_dodge_time / _dodge_duration, 0.0, 1.0)
	var roll := sin(t * PI) * 0.5
	
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(roll, 0.0, 0.0)))
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3(0.0, -0.2 * sin(t * PI), 0.0))
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-0.5 * sin(t * PI), 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-0.5 * sin(t * PI), 0.0, 0.0)))

func _apply_hit() -> void:
	var t := clampf(_hit_time / _hit_duration, 0.0, 1.0)
	var flinch := sin(t * PI) * 0.4
	
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-flinch, 0.0, 0.0)))
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.from_euler(Vector3(-flinch * 0.5, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-flinch * 0.3, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-flinch * 0.3, 0.0, 0.0)))

func _apply_dead() -> void:
	var t := clampf(_dead_time / 1.0, 0.0, 1.0)
	var ease := 1.0 - (1.0 - t) * (1.0 - t)
	
	if _spine_bone >= 0:
		_skeleton.set_bone_pose_rotation(_spine_bone, Quaternion.from_euler(Vector3(-ease * 1.2, 0.0, 0.0)))
	if _head_bone >= 0:
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion.from_euler(Vector3(-ease * 0.4, 0.0, 0.0)))
	if _left_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_arm_bone, Quaternion.from_euler(Vector3(-ease * 0.8, 0.0, 0.0)))
	if _right_arm_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_arm_bone, Quaternion.from_euler(Vector3(-ease * 0.8, 0.0, 0.0)))
	if _left_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_left_leg_bone, Quaternion.from_euler(Vector3(ease * 0.3, 0.0, 0.0)))
	if _right_leg_bone >= 0:
		_skeleton.set_bone_pose_rotation(_right_leg_bone, Quaternion.from_euler(Vector3(ease * 0.3, 0.0, 0.0)))
	if _hips_bone >= 0:
		_skeleton.set_bone_pose_position(_hips_bone, Vector3(0.0, -ease * 0.5, 0.0))

func _on_state_changed(previous: PlayerStateMachine.State, current: PlayerStateMachine.State) -> void:
	match current:
		PlayerStateMachine.State.ATTACK, PlayerStateMachine.State.AIR_ATTACK:
			_attack_time = 0.0
			_attack_duration = 0.4
			_attack_type = &"light"
		PlayerStateMachine.State.DODGE:
			_dodge_time = 0.0
		PlayerStateMachine.State.HIT:
			_hit_time = 0.0
		PlayerStateMachine.State.DEAD:
			_dead_time = 0.0

func notify_attack_started(attack_data: AttackData) -> void:
	_attack_time = 0.0
	_attack_duration = attack_data.startup + attack_data.active + attack_data.recovery
	_attack_type = &"heavy" if attack_data.damage >= 20.0 or attack_data.launch_force > 4.0 else &"light"

func notify_dodge_started(duration: float) -> void:
	_dodge_time = 0.0
	_dodge_duration = duration

func notify_hit_started(duration: float) -> void:
	_hit_time = 0.0
	_hit_duration = duration

func notify_dead() -> void:
	_dead_time = 0.0
