extends Node3D

@onready var core: MeshInstance3D = $Core
@onready var ring: MeshInstance3D = $Ring
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	rotation = Vector3(randf_range(-0.8, 0.8), randf_range(0.0, TAU), randf_range(-0.8, 0.8))
	core.scale = Vector3(0.15, 0.15, 0.15)
	ring.scale = Vector3(0.1, 0.1, 0.1)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3(0.65, 0.08, 0.65), 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(1.4, 0.04, 1.4), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, 0.16)
	await tween.finished
	queue_free()
