extends Area2D

@export var speed: float = 180.0


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()


func destroy() -> void:
	queue_free()
