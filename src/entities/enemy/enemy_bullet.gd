class_name EnemyBullet
extends Area2D

@export var speed: float = 120.0


func start(_pos, _dir) -> void:
	position = _pos
	rotation = _dir.angle()


func _process(delta: float) -> void:
	position += transform.x * speed * delta


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	#if body.is_in_group("rocks"):
		#body.explode()
		#queue_free()
	queue_free()
