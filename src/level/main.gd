class_name Main
extends Node2D

@export var rock_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var rock_spawn: PathFollow2D = $RockPath/RockSpawn
@onready var camera: CustomCamera = $Camera2D
@onready var player: Player = $Player
@onready var hud: HUD = $HUD


var screen_size: Vector2 = Vector2.ZERO
var level: int = 0
var score: int = 0
var playing: bool = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not playing:
			return
		get_tree().paused = not get_tree().paused
		var message = $HUD/MarginContainer/VBoxContainer/Message
		if get_tree().paused:
			message.text = "Paused"
			message.show()
		else:
			message.text = ""
			message.hide()


func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	Globals.freeze_requested.connect(freeze_engine)
	Globals.camera = camera
	
	player.hide()
	$HUD/MarginContainer/VBoxContainer/StartButton.grab_focus()


func _process(delta: float) -> void:
	if not playing:
		return
	
	if get_tree().get_nodes_in_group("rocks").size() == 0:
		new_level()


func spawn_rock(size: float, pos = null, vel = null) -> void:
	if pos == null:
		rock_spawn.progress = randi()
		pos = rock_spawn.position
	if vel == null:
		vel = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(15, 35)
	
	var rock: Rock = rock_scene.instantiate()
	rock.screen_size = screen_size
	rock.start(pos, vel, size)
	add_child.call_deferred(rock)
	rock.exploded.connect(self._on_rock_exploded)


func new_game() -> void:
	$Music.play()
	player.show()
	get_tree().call_group("rocks", "queue_free")
	level = 0
	score = 0
	hud.update_score(score)
	hud.show_message("Get Ready!")
	player.reset()
	await $HUD/Timer.timeout
	playing = true


func game_over() -> void:
	$Music.stop() 
	playing = false
	hud.game_over()


func new_level() -> void:
	$LevelUpSound.play()
	level += 1
	hud.show_message("Wave %s" % level)
	player.reset()
	$EnemyTimer.start(randf_range(5, 10))
	for i in level:
		spawn_rock(3)


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


func _on_rock_exploded(size: float, radius: float, pos: Vector2, vel: Vector2) -> void:
	$ExplosionSound.play()
	score += 10 * size
	hud.update_score(score)
	
	if size <= 1.0:
		return
	
	for offset in [-1, 1]:
		var dir: Vector2 = player.position.direction_to(pos).orthogonal() * offset
		var newpos: Vector2 = pos + dir * radius
		var newvel: Vector2 = dir * vel.length() * 1.1
		spawn_rock(size - 1, newpos, newvel)


func _on_enemy_timer_timeout() -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.target = player
	$EnemyTimer.start(randf_range(30, 50))
