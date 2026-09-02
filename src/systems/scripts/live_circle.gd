class_name LiveCircle
extends Node2D

var color = Color(0.902, 0.725, 0.353, 1.0)
var size: Vector2 = Vector2(2.5, 2.5)

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), color)
