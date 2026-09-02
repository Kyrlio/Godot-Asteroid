extends Node2D

@export var asteroid_scene: PackedScene
@export var lives_max: int = 3

@onready var camera: CustomCamera = $Camera2D
@onready var player: Player = $Player

var current_lives: int
var current_wave: int = 1
var asteroids_count: int = 0

func _ready() -> void:
	Globals.freeze_requested.connect(freeze_engine)
	player.player_died.connect(_on_player_died)
	
	Globals.camera = camera
	current_lives = lives_max
	
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


var _freeze_token: int = 0

func freeze_engine(freeze_slow: float = 0.06, freeze_time: float = 0.2) -> void:
	if Globals.is_time_scale_locked or Engine.time_scale != 1.0:
		return
	
	_freeze_token += 1
	var token: int = _freeze_token
	
	Engine.time_scale = freeze_slow
	await get_tree().create_timer(freeze_time * freeze_slow).timeout
	
	if Globals.is_time_scale_locked or _freeze_token != token or Engine.time_scale != freeze_slow:
		return
	
	Engine.time_scale = 1.0


func _respawn_player_sequence() -> void:
	await get_tree().create_timer(1.5).timeout
	player.respawn(Vector2(80, 72))


func _trigger_game_over() -> void:
	print("game over")


func _on_player_died() -> void:
	camera.shake(1.0, 60.0, 4.0)
	current_lives -= 1
	
	if current_lives > 0:
		_respawn_player_sequence()
	else:
		_trigger_game_over()
