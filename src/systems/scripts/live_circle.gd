class_name LiveCircle
extends Node2D

var color = Color(0.902, 0.725, 0.353, 1.0)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 1.2, color)
