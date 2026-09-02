class_name EnemyBullet
extends Area2D

@export var speed: float = 120.0
@export var damage: float = 15.0
@export var hit_particles_scene: PackedScene


func start(_pos, _dir) -> void:
	position = _pos
	rotation = _dir.angle()


func _process(delta: float) -> void:
	position += transform.x * speed * delta


func spawn_hit_particles() -> void:
	var instance: GPUParticles2D = hit_particles_scene.instantiate()
	instance.global_position = global_position
	get_tree().root.add_child(instance)
	instance.restart()
	instance.emitting = true


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.state == Player.State.ALIVE and not body.is_losing_life:
			body.shield -= damage
			if body.state == Player.State.ALIVE and not body.is_losing_life and body.shield > 0:
				Globals.freeze_requested.emit(0.1, 0.2)
	spawn_hit_particles()
	queue_free.call_deferred()
