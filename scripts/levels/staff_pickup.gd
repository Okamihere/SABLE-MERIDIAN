extends Area3D

@onready var staff_visual: Node3D = $FloatingStaff
@onready var glow: OmniLight3D = $Glow
@onready var nameplate: Label3D = $Nameplate

var _elapsed := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_elapsed += delta
	staff_visual.rotation.y += delta * 0.72
	staff_visual.position.y = 1.3 + sin(_elapsed * 2.3) * 0.11
	glow.light_energy = 1.55 + sin(_elapsed * 2.3) * 0.32
	nameplate.modulate.a = 0.78 + sin(_elapsed * 2.3) * 0.18

func _on_body_entered(body: Node3D) -> void:
	if not body is PlayerController or not body.is_alive():
		return
	body.equip_staff()
	body.equipment.request_weapon(&"staff")
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice("CAJADO DO PALCO", "Q cartas malditas  •  E recuo em área  •  R lança alvos", 3.4)
