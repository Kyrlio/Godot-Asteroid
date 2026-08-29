extends Node2D

@export var asteroid_scene: PackedScene

@onready var camera: CustomCamera = $Camera2D

func _ready() -> void:
	Globals.freeze_requested.connect(freeze_engine)
	
	Globals.camera = camera
	
	for asteroid in $Asteroids.get_children():
		asteroid.exploded.connect(_on_asteroid_exploded)


func _on_asteroid_exploded(pos: Vector2, size: Asteroid.AsteroidSize, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if size == Asteroid.AsteroidSize.SMALL:
		return
	
	var next_size = Asteroid.AsteroidSize.MEDIUM if size == Asteroid.AsteroidSize.LARGE else Asteroid.AsteroidSize.SMALL
	
	var base_dir := hit_direction.normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	
	var perp_dir := base_dir.orthogonal()
	var spawn_dirs := [perp_dir, -perp_dir]
	
	for i in range(2):
		var new_asteroid: Asteroid = asteroid_scene.instantiate()
		new_asteroid.size = next_size
		new_asteroid.direction = spawn_dirs[i]
		new_asteroid.global_position = pos
		new_asteroid.exploded.connect(_on_asteroid_exploded)
		$Asteroids.call_deferred("add_child", new_asteroid)


func freeze_engine(freeze_slow: float = 0.06, freeze_time: float = 0.2) -> void:
	if Engine.time_scale != 1.0:
		return
	
	Engine.time_scale = freeze_slow
	await get_tree().create_timer(freeze_time * freeze_slow).timeout
	Engine.time_scale = 1.0
