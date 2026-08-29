class_name HealthComponent
extends Node

signal health_changed(current: int, max_hp: int)
signal died

@export var max_health: int = 3

@onready var current_health: int = max_health
var last_hit_direction: Vector2 = Vector2.ZERO

func damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	last_hit_direction = hit_direction
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		died.emit()
