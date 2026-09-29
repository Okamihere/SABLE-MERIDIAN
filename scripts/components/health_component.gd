class_name HealthComponent
extends Node

signal damaged(amount: float, current_health: float, max_health: float)
signal healed(amount: float, current_health: float, max_health: float)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready() -> void:
	current_health = max_health

func damage(amount: float) -> bool:
	if current_health <= 0.0 or amount <= 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, current_health, max_health)
	if current_health <= 0.0:
		died.emit()
	return true

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var previous := current_health
	current_health = minf(max_health, current_health + amount)
	healed.emit(current_health - previous, current_health, max_health)

func reset() -> void:
	current_health = max_health
