class_name Player
extends CharacterBody2D

signal died

@export var laser_scene: PackedScene
@export var fire_cooldown: float = 0.25

@export_group("Linear Movement")
@export var max_speed: float = 50.0
@export var acceleration: float = 75.0
@export var friction: float = 25.0

@export_group("Angular Movement")
@export var max_rotation_speed: float = 4.5
@export var rotation_acceleration: float = 18.0
@export var rotation_friction: float = 14.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var gpu_particles: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2: GPUParticles2D = $GPUParticles2D2
@onready var muzzle: Marker2D = $Muzzle
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var alive: bool = true
var screen_size: Vector2
var margin: float = 8.0
var rotation_velocity: float = 0.0
var can_shoot: bool = true


func _ready() -> void:
	screen_size = get_viewport_rect().size


func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	# Rotation
	var rotation_input: float = Input.get_axis("rotate_left", "rotate_right")
	if rotation_input != 0:
		rotation_velocity += rotation_input * rotation_acceleration * delta
		rotation_velocity = clamp(rotation_velocity, -max_rotation_speed, max_rotation_speed)
	else:
		rotation_velocity = move_toward(rotation_velocity, 0.0, rotation_friction * delta)
	rotation += rotation_velocity * delta
	
	# Linear Acceleration
	var thrust_input: float = Input.is_action_pressed("move_forward")
	if thrust_input:
		if not gpu_particles.emitting:
			gpu_particles.emitting = true
			gpu_particles_2.emitting = true
		var forward_vector := Vector2.RIGHT.rotated(rotation)
		velocity += forward_vector * acceleration * delta
		velocity = velocity.limit_length(max_speed)
	else:
		if gpu_particles.emitting:
			gpu_particles.emitting = false
			gpu_particles_2.emitting = false
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if Input.is_action_pressed("shoot") and can_shoot:
		_shoot()
	
	move_and_slide()
	_screen_wrap()


func _shoot() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play("shoot")
	Globals.camera.shake(0.12, 30.0, 1.0)
	can_shoot = false
	var laser: Area2D = laser_scene.instantiate()
	laser.global_position = muzzle.global_position
	laser.rotation = rotation
	
	get_tree().current_scene.add_child(laser)
	
	await get_tree().create_timer(fire_cooldown).timeout
	can_shoot = true


func _screen_wrap() -> void:
	if global_position.x < -margin:
		global_position.x = screen_size.x + margin
	elif global_position.x > screen_size.x + margin:
		global_position.x = -margin
	
	if global_position.y < -margin:
		global_position.y = screen_size.y + margin
	elif global_position.y > screen_size.y + margin:
		global_position.y = -margin


func die() -> void:
	if alive:
		alive = false
		collision_shape.set_deferred("disabled", true)
		sprite.visible = false
		died.emit()


func respawn(spawn_position: Vector2) -> void:
	alive = true
	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite.visible = true
	collision_shape.set_deferred("disabled", false)
