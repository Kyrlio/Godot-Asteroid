class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent


func _ready() -> void:
	monitorable = true
	monitoring = false


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health_component:
		health_component.damage(amount, hit_direction)
