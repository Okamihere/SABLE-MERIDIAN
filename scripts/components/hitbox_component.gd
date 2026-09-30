class_name HitboxComponent
extends Area3D

## Área ofensiva: aceita um acerto por hurtbox em cada ativação.
##
## Ignora o próprio dono e adia mudanças de monitoramento para fora da física.
## Cada ativação ([method begin_attack]) permite um acerto por hurtbox.
##
## Uso típico:
##   - Adicionar como filho de um CharacterBody3D
##   - Chamar [method configure_from_attack] com um AttackData antes de atacar
##   - Chamar [method begin_attack] para abrir a janela de acerto
##   - Chamar [method end_attack] para fechar a janela de acerto

## Emitido quando um golpe acerta uma hurtbox. Parâmetros: hurtbox atingida, hitbox que acertou.
signal hit_landed(hurtbox: HurtboxComponent, hitbox: HitboxComponent)

## Dano base do golpe.
@export var damage: float = 10.0
## Força de knockback aplicada ao atingido.
@export var knockback: float = 4.0
## Duração do hit stun (em segundos).
@export var hit_stun: float = 0.2
## Força de lançamento vertical (0 = sem lançamento).
@export var launch_force: float = 0.0
## Duração do hit stop (em segundos).
@export var hit_stop_duration: float = 0.03
## Identificador do ataque (usado para estilo e debug).
@export var attack_id: StringName = &"attack"
## Pontos de estilo concedidos ao acertar.
@export var style_points: int = 100
## Caminho para o nó que é a fonte do golpe (para ignorar auto-impacto).
@export var source_path: NodePath = NodePath("../..")

## Indica se a hitbox está ativa (janela de acerto aberta).
var _attack_enabled: bool = false
## Referência ao nó fonte do golpe.
var source: Node
## Dicionário de IDs de instâncias já atingidas nesta ativação.
var _already_hit: Dictionary = {}
## Malha de debug visual (visível apenas com DEBUG_COMBAT ativo).
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	monitoring = false
	monitorable = false
	source = get_node_or_null(source_path)
	area_entered.connect(_on_area_entered)
	_create_debug_mesh()

## Configura os parâmetros da hitbox a partir de um recurso AttackData.
## @param data Recurso AttackData com os parâmetros do golpe.
func configure_from_attack(data: AttackData) -> void:
	damage = data.damage
	knockback = data.knockback
	hit_stun = data.hit_stun
	launch_force = data.launch_force
	hit_stop_duration = data.hit_stop_duration
	attack_id = data.attack_id
	style_points = data.style_points

## Abre uma nova janela de acerto e esquece os alvos atingidos no golpe anterior.
func begin_attack() -> void:
	_already_hit.clear()
	_attack_enabled = true
	set_deferred("monitoring", true)
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT

## Bloqueia dano imediatamente; a alteração física é aplicada de forma adiada.
func end_attack() -> void:
	_attack_enabled = false
	set_deferred("monitoring", false)

## Atualiza a visibilidade da malha de debug.
func _process(_delta: float) -> void:
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT and monitoring

## Detecta colisão com hurtboxes e aplica o golpe.
func _on_area_entered(area: Area3D) -> void:
	if not _attack_enabled or not (area is HurtboxComponent):
		return
	var hurtbox := area as HurtboxComponent
	var instance_id := hurtbox.get_instance_id()
	if _already_hit.has(instance_id):
		return
	if is_instance_valid(source) and source.is_ancestor_of(hurtbox):
		return
	_already_hit[instance_id] = true
	if hurtbox.receive_hit(self):
		hit_landed.emit(hurtbox, self)

## Cria a malha de debug visual baseada na forma da collision shape.
func _create_debug_mesh() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugHitbox"
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.18, 0.25, 0.28)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if shape_node.shape is BoxShape3D:
		var shape := shape_node.shape as BoxShape3D
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		_debug_mesh.mesh = mesh
	elif shape_node.shape is SphereShape3D:
		var shape := shape_node.shape as SphereShape3D
		var mesh := SphereMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.radius * 2.0
		_debug_mesh.mesh = mesh
	elif shape_node.shape is CapsuleShape3D:
		var shape := shape_node.shape as CapsuleShape3D
		var mesh := CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		_debug_mesh.mesh = mesh
	else:
		return
	_debug_mesh.material_override = material
	add_child(_debug_mesh)
