class_name SpellResource
extends Resource

## Dados compartilhados de uma magia; edite os arquivos em resources/spells.
##
## Define custo, cooldown, dano e cena do efeito de uma habilidade.
## Cada magia é um recurso separado que pode ser editado no Inspector.
##
## Uso típico:
##   - Criar um novo Resource do tipo SpellResource
##   - Configurar os parâmetros no Inspector
##   - Atribuir ao SpellManager para usar em combate

## Nome da magia exibido na UI.
@export var spell_name: String = "Nova Magia"
## Identificador estável, separado do texto mostrado na interface.
@export var ability_id: StringName = &""
## Custo de mana para conjurar a magia.
@export var mana_cost: float = 20.0
## Tempo de recarga entre usos (em segundos).
@export var cooldown: float = 1.0
## Dano base da magia.
@export var damage: float = 15.0
## Ícone da magia exibido na UI.
@export var icon: Texture2D
## Campo legado para recursos antigos ainda não equipados no jogador.
@export var projectile_scene: PackedScene
## Efeito de combate ativado pelo SpellManager. Pode criar projéteis ou agir na arena.
@export var effect_scene: PackedScene
## Conjuração permitida durante ataques físicos sem encerrar o combo.
@export var weave_during_attack: bool = false
