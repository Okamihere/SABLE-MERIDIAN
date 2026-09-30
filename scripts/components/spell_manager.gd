class_name SpellManager
extends Node

## Gerenciador de magias do jogador.
##
## Controla cooldowns, custo de mana e execução de magias.
## Usa contadores de cooldown e verifica ManaComponent antes de ativar efeitos.
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Configurar [member mana_component_path] para apontar ao ManaComponent
##   - Chamar [method cast_spell] para conjurar uma magia
##   - Conectar [signal spell_cast] para reagir a magias conjuradas

## Emitido quando uma magia é conjurada com sucesso. Parâmetro: magia conjurada.
signal spell_cast(spell: SpellResource)

## Caminho para o ManaComponent do jogador.
@export var mana_component_path: NodePath = NodePath("../ManaComponent")

## Referência ao ManaComponent.
var _mana: ManaComponent
## Dicionário de cooldowns restantes por magia (spell_name → tempo restante).
var _cooldowns: Dictionary = {}

## Inicializa o SpellManager: obtém referência ao ManaComponent.
func _ready() -> void:
	_mana = get_node_or_null(mana_component_path) as ManaComponent

## Processa cooldowns das magias.
func _process(delta: float) -> void:
	for spell_name in _cooldowns.keys():
		if _cooldowns[spell_name] > 0.0:
			_cooldowns[spell_name] = maxf(0.0, _cooldowns[spell_name] - delta)

## Tenta conjurar uma magia.
## Verifica mana e cooldown antes de executar.
## @param spell A magia a ser conjurada.
## @return true se a magia foi conjurada, false caso contrário.
func cast_spell(spell: SpellResource, caster: Node3D = null) -> bool:
	if spell == null:
		return false
	if caster != null and (spell.effect_scene == null or not spell.effect_scene.can_instantiate()):
		return false
	if not _can_cast(spell):
		return false
	if _mana != null and not _mana.try_spend(spell.mana_cost):
		return false
	_start_cooldown(spell)
	if caster != null:
		var effect := spell.effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		if effect.has_method("activate"):
			effect.activate(caster, spell)
	spell_cast.emit(spell)
	return true

## Verifica se uma magia pode ser conjurada (mana e cooldown).
## @param spell A magia a verificar.
## @return true se pode conjurar, false caso contrário.
func _can_cast(spell: SpellResource) -> bool:
	if _mana != null and _mana.current_mana < spell.mana_cost:
		return false
	if _cooldowns.get(_cooldown_key(spell), 0.0) > 0.0:
		return false
	return true

## Inicia o cooldown de uma magia.
## @param spell A magia em cooldown.
func _start_cooldown(spell: SpellResource) -> void:
	_cooldowns[_cooldown_key(spell)] = spell.cooldown

func _cooldown_key(spell: SpellResource) -> StringName:
	return spell.ability_id if spell.ability_id != &"" else StringName(spell.spell_name)

## Retorna o cooldown restante de uma magia.
## @param spell Recurso da habilidade.
## @return Tempo restante de cooldown (em segundos).
func get_cooldown_remaining(spell: SpellResource) -> float:
	return _cooldowns.get(_cooldown_key(spell), 0.0)

## Regras de relíquias podem devolver uma magia sem alterar seu custo ou dano.
func reset_cooldown(spell: SpellResource) -> void:
	if spell != null:
		_cooldowns[_cooldown_key(spell)] = 0.0

## Retorna se uma magia está pronta para uso.
## @param spell A magia a verificar.
## @return true se está pronta, false caso contrário.
func is_ready(spell: SpellResource) -> bool:
	return _can_cast(spell)
