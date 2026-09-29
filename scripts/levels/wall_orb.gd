extends Area3D

## Coletável de melhoria permanente. Defina um ID diferente para cada instância.
@export var orb_id: String = ""
var _collected: bool = false
var _elapsed: float = 0.0
@onready var visual: MeshInstance3D = $Visual

func _ready() -> void:
	if orb_id.is_empty():
		push_warning("Orbe sem ID: configure orb_id no inspetor.")
	if Progression.collected.has(orb_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_elapsed += delta
	visual.position.y = sin(_elapsed * 2.5) * 0.15
	visual.rotation.y += delta

func _on_body_entered(body: Node3D) -> void:
	if _collected or not (body is PlayerController) or not body.is_alive():
		return
	if Progression.collect(orb_id):
		_collected = true
		set_deferred("monitoring", false)
		hide()
		queue_free()
