class_name RelicData
extends Resource

@export var relic_id: StringName
@export var display_name: String
@export_multiline var identity: String
@export var behavior: RelicBehavior

func is_playable() -> bool:
	return behavior != null
