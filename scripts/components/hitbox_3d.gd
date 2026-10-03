class_name Hitbox3D
extends Area3D

## Área ofensiva 3D para magias e projéteis.
##
## Detecta colisão com Hurtbox3D e aplica dano.
## Pode ser usada por projéteis ou áreas de efeito de magias.
##
## Uso típico:
##   - Adicionar como filho de um projétil ou nó de magia
##   - Configurar [member damage] no Inspector
##   - Conectar [signal hit_landed] para reagir a acertos

## Emitido quando a hitbox acerta uma hurtbox. Parâmetros: hurtbox atingida, dano aplicado.
signal hit_landed(hurtbox: Hurtbox3D, damage: float)

## Dano aplicado ao acertar.
@export var damage: float = 10.0
## Indica se a hitbox está ativa (pode causar dano).
@export var active: bool = true

## Detecta colisão com hurtboxes.
func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if area is Hurtbox3D:
		var hurtbox := area as Hurtbox3D
		if hurtbox.receive_damage(damage):
			hit_landed.emit(hurtbox, damage)
