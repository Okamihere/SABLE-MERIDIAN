extends Area3D

@onready var staff_visual: Node3D = $FloatingStaff
@onready var glow: OmniLight3D = $Glow
@onready var nameplate: Label3D = $Nameplate

var _elapsed := 0.0
var _collected := false

func _ready() -> void:
	if GameManager.has_staff:
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta
	staff_visual.rotation.y += delta * 0.72
	staff_visual.position.y = 1.3 + sin(_elapsed * 2.3) * 0.11
	glow.light_energy = 1.55 + sin(_elapsed * 2.3) * 0.32
	nameplate.modulate.a = 0.78 + sin(_elapsed * 2.3) * 0.18

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is PlayerController or not body.is_alive():
		return
	_collected = true
	set_deferred("monitoring", false)
	body.equip_staff()
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice("CAJADO DO PALCO", "Golpes com o cajado. Q lança cartas e se mistura aos combos.", 3.4)
	staff_visual.visible = false
	nameplate.visible = false
	var fade := create_tween()
	fade.tween_property(glow, "light_energy", 0.0, 0.45)
	fade.finished.connect(queue_free)
