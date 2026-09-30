class_name MaskData
extends Resource

@export var mask_id: StringName
@export var display_name: String
@export_multiline var identity: String
@export var behavior: MaskBehavior

func is_playable() -> bool:
	return behavior != null
