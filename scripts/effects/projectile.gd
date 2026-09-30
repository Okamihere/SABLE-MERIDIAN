class_name Projectile
extends Area3D

## Projétil de magia que se move em linha reta e causa dano ao colidir.
##
## Usa [Hitbox3D] para detectar colisões e aplicar dano.
## O projétil é liberado ao colidir ou quando o tempo de vida expira.
##
## Uso típico:
##   - Instanciar a cena projectile.tscn
##   - Configurar [member direction], [member speed] e [member lifetime]
##   - Posicionar no ponto de origem
##   - O projétil se move e colide automaticamente

## Velocidade do projétil (metros/segundo).
@export var speed: float = 20.0
## Tempo de vida do projétil antes de ser liberado (em segundos).
@export var lifetime: float = 3.0
## Direção normalizada do movimento.
@export var direction: Vector3 = Vector3.FORWARD

## Referência à hitbox do projétil.
@onready var hitbox: Hitbox3D = $Hitbox3D

## Tempo decorrido desde o spawn.
var _elapsed: float = 0.0

## Inicializa o projétil: conecta sinais e configura hitbox.
func _ready() -> void:
	hitbox.hit_landed.connect(_on_hit_landed)
	hitbox.damage = _get_damage_from_parent()

## Move o projétil e verifica tempo de vida.
func _physics_process(delta: float) -> void:
	_elapsed += delta
	position += direction * speed * delta
	if _elapsed >= lifetime:
		queue_free()

## Chamado quando o projétil colide com uma hurtbox.
func _on_hit_landed(_hurtbox: Hurtbox3D, _damage: float) -> void:
	queue_free()

## Obtém o dano do projétil a partir do SpellResource pai.
## @return Dano configurado na magia.
func _get_damage_from_parent() -> float:
	var parent_node := get_parent()
	if parent_node != null and parent_node.get("damage") != null:
		return float(parent_node.damage)
	return 10.0
