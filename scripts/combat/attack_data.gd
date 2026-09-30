class_name AttackData
extends Resource

## Dados compartilhados de um golpe; edite os arquivos em resources/attacks.
##
## Tempos são segundos; forças alteram velocidade. Não guarda estado de execução.
## Cada ataque é um recurso separado que pode ser editado no Inspector.
##
## Uso típico:
##   - Criar um novo Resource do tipo AttackData
##   - Configurar os parâmetros no Inspector
##   - Atribuir ao CombatController para usar em combos

## Identificador único do ataque (usado para estilo e debug).
@export var attack_id: StringName = &"attack"
## Permite escolher a pose sem inferir estilo a partir do dano.
@export_enum("auto", "light", "heavy") var animation_style: String = "auto"
## Alterna o sentido do corte procedural sem codificar IDs de armas na animação.
@export var reverse_sweep: bool = false
## Dano base do golpe.
@export var damage: float = 10.0
## Força de knockback aplicada ao atingido.
@export var knockback: float = 4.0
## Duração do hit stun (em segundos).
@export var hit_stun: float = 0.22
## Força de lançamento vertical (0 = sem lançamento).
@export var launch_force: float = 0.0
## Duração do hit stop (em segundos).
@export var hit_stop_duration: float = 0.035
## Tempo de startup do ataque (em segundos).
@export var startup: float = 0.08
## Tempo ativo do ataque (janela de acerto, em segundos).
@export var active: float = 0.10
## Tempo de recovery do ataque (em segundos).
@export var recovery: float = 0.20
## Início da janela de combo (em segundos).
@export var combo_window_start: float = 0.16
## Janela para cancelar ataque com esquiva (em segundos).
@export var attack_cancel_window: float = 0.20
## Pontos de estilo concedidos ao acertar.
@export var style_points: int = 100
## Impulso frontal aplicado ao atacar.
@export var forward_impulse: float = 1.5
