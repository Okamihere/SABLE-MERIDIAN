class_name AttackData
extends Resource

## Dados compartilhados de um golpe; edite os arquivos em resources/attacks.
## Tempos são segundos; forças alteram velocidade. Não guarda estado de execução.

@export var attack_id: StringName = &"attack"
@export var damage: float = 10.0
@export var knockback: float = 4.0
@export var hit_stun: float = 0.22
@export var launch_force: float = 0.0
@export var hit_stop_duration: float = 0.035
@export var startup: float = 0.08
@export var active: float = 0.10
@export var recovery: float = 0.20
@export var combo_window_start: float = 0.16
@export var attack_cancel_window: float = 0.20
@export var style_points: int = 100
@export var forward_impulse: float = 1.5
