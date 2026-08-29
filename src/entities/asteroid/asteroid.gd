class_name Asteroid
extends Area2D

signal exploded(pos: Vector2, current_size: AsteroidSize, hit_direction: Vector2)

enum AsteroidSize { LARGE, MEDIUM, SMALL}
@export var size: AsteroidSize = AsteroidSize.LARGE

var speed: float = 30.0
var direction: Vector2 = Vector2.ZERO
var screen_size: Vector2
var margin: float = 16.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	if direction == Vector2.ZERO:
		rotation = randf_range(0.0, TAU)
		direction = Vector2.RIGHT.rotated(rotation)
	else:
		rotation = direction.angle()
	
	collision_shape.shape = collision_shape.shape.duplicate()
	
	match size:
		AsteroidSize.LARGE:
			speed = randf_range(5.0, 10.0)
			scale = Vector2(1.0, 1.0)
			sprite.region_rect = Rect2(37.0, 1.0, 29.0, 26.0)
			collision_shape.shape.radius = 14.0
		AsteroidSize.MEDIUM:
			speed = randf_range(15.0, 25.0)
			scale = Vector2(1.0, 1.0)
			sprite.region_rect = Rect2(73.0, 1.0, 15.0, 13.0)
			collision_shape.shape.radius = 7.0
		AsteroidSize.SMALL:
			speed = randf_range(30.0, 40.0)
			scale = Vector2(1.0, 1.0)
			sprite.region_rect = Rect2(95.0, 0.0, 8.0, 7.0)
			collision_shape.shape.radius = 4.0


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_screen_wrap()


func _screen_wrap() -> void:
	if global_position.x < -margin:
		global_position.x = screen_size.x + margin
	elif global_position.x > screen_size.x + margin:
		global_position.x = -margin
	
	if global_position.y < -margin:
		global_position.y = screen_size.y + margin
	elif global_position.y > screen_size.y + margin:
		global_position.y = -margin


func destroy(hit_direction: Vector2 = Vector2.ZERO) -> void:
	exploded.emit(global_position, size, hit_direction)
	Globals.freeze_requested.emit()
	Globals.camera.shake(0.3, 30, 3)
	queue_free.call_deferred()
