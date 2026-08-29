class_name Main
extends Node2D

@export var rock_scene: PackedScene

@onready var rock_spawn: PathFollow2D = $RockPath/RockSpawn
@onready var camera: CustomCamera = $Camera2D
@onready var player: Player = $Player


var screen_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	Globals.camera = camera
	
	for i in 3:
		spawn_rock(3)


func spawn_rock(size: float, pos = null, vel = null) -> void:
	if pos == null:
		rock_spawn.progress = randi()
		pos = rock_spawn.position
	if vel == null:
		vel = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(10, 25)
	
	var rock: Rock = rock_scene.instantiate()
	rock.screen_size = screen_size
	rock.start(pos, vel, size)
	add_child.call_deferred(rock)
	rock.exploded.connect(self._on_rock_exploded)


func _on_rock_exploded(size: float, radius: float, pos: Vector2, vel: Vector2) -> void:
	if size <= 1.0:
		return
	
	for offset in [-1, 1]:
		var dir: Vector2 = player.position.direction_to(pos).orthogonal() * offset
		var newpos: Vector2 = pos + dir * radius
		var newvel: Vector2 = dir * vel.length() * 1.1
		spawn_rock(size - 1, newpos, newvel)
