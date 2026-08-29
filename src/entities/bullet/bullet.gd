class_name Bullet
extends Area2D

@export var speed: float = 180.0

var velocity: Vector2 = Vector2.ZERO


func start(_transform) -> void:
	transform = _transform
	velocity = transform.x * speed


func _process(delta: float) -> void:
	position += velocity * delta


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("rocks"):
		body.explode()
		queue_free()
