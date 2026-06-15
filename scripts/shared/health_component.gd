class_name HealthComponent
extends Node

signal health_changed(new_health: float, max_health: float)
signal died

@export var max_health: int = 100
var current_health: float

func _ready() -> void:
	current_health = float(max_health)

func take_damage(amount: float) -> void:
	if current_health <= 0:
		return  # já morto: não re-emite died nem health_changed
	current_health = clampf(current_health - amount, 0.0, float(max_health))
	health_changed.emit(current_health, float(max_health))
	if current_health <= 0:
		died.emit()

func heal(amount: float) -> void:
	current_health = clampf(current_health + amount, 0.0, float(max_health))
	health_changed.emit(current_health, float(max_health))

func full_heal() -> void:
	current_health = float(max_health)
	health_changed.emit(current_health, float(max_health))

func is_alive() -> bool:
	return current_health > 0
