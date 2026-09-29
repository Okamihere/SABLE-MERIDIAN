extends Node

## Persistência exclusiva das orbes. Não substitui o futuro save completo do jogo.
## Cada orbe tem ID estável; o mesmo ID só concede uma melhoria.
signal upgraded(maximum: int)
const SAVE_PATH := "user://wall_orbs.cfg"
var collected: Dictionary = {}
var save_path: String = SAVE_PATH
var notice_time: float = 0.0

func _ready() -> void:
	load_progress()

func max_wall_jumps() -> int:
	return 2 + collected.size()

func collect(id: String) -> bool:
	if id.is_empty() or collected.has(id):
		return false
	collected[id] = true
	var config := ConfigFile.new()
	config.set_value("wall_orbs", "ids", collected.keys())
	if config.save(save_path) != OK:
		push_warning("Não foi possível salvar as orbes; melhoria mantida nesta sessão.")
	notice_time = 4.0
	upgraded.emit(max_wall_jumps())
	return true

func load_progress() -> void:
	collected.clear()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var ids = config.get_value("wall_orbs", "ids", [])
	if ids is Array:
		for id in ids:
			if id is String and not id.is_empty():
				collected[id] = true

func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
