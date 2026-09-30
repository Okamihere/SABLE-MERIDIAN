extends Node3D

## Efeito curto de impacto feito com malhas e luz.
##
## Libera a instância ao terminar; pooling de efeitos ainda não foi implementado.
## O efeito consiste em um núcleo que expande, um anel que se expande e uma luz que fade out.
##
## Uso típico:
##   - Instanciar a cena hit_spark.tscn
##   - Posicionar no ponto de impacto
##   - O efeito se auto-destrói ao terminar

## Referência ao núcleo do efeito.
@onready var core: MeshInstance3D = $Core
## Referência ao anel do efeito.
@onready var ring: MeshInstance3D = $Ring
## Referência à luz do efeito.
@onready var light: OmniLight3D = $OmniLight3D
@onready var shards: GPUParticles3D = $Shards

## Inicializa e anima o efeito de impacto.
func _ready() -> void:
	rotation = Vector3(randf_range(-0.8, 0.8), randf_range(0.0, TAU), randf_range(-0.8, 0.8))
	core.scale = Vector3(0.15, 0.15, 0.15)
	ring.scale = Vector3(0.1, 0.1, 0.1)
	shards.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3(0.65, 0.08, 0.65), 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(1.4, 0.04, 1.4), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, 0.16)
	await tween.finished
	await get_tree().create_timer(0.07, false).timeout
	queue_free()
