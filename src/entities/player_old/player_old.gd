class_name PlayerOld
extends CharacterBody2D

signal player_died

@export_group("Combat")
@export var laser_scene: PackedScene
@export var fire_cooldown: float = 0.25
@export var invincibility_duration: float = 1.5

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
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var alive: bool = true
var screen_size: Vector2
var margin: float = 8.0
var rotation_velocity: float = 0.0
var can_shoot: bool = true
var orbit_angle: float = 0.0
var is_invincile: bool = false


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	screen_size = get_viewport_rect().size


func _draw() -> void:
	if not alive: return
	
	var color = Color(0.902, 0.725, 0.353, 1.0)
	var radius = 8.0
	
	for i in range(health_component.current_health):
		var angle = orbit_angle - rotation + (i * (TAU / max(health_component.current_health, 1)))
		var offset_pos = Vector2.RIGHT.rotated(angle) * radius
		draw_circle(offset_pos, 1.2, color)


func _process(delta: float) -> void:
	orbit_angle += 3.0 * delta
	queue_redraw()


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


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	#TODO: update orbitals circles
	_trigger_invincibility()
	queue_redraw()


func _trigger_invincibility() -> void:
	is_invincile = true
	hurtbox_component.set_deferred("monitoring", false)
	hurtbox_component.set_deferred("monitorable", false)
	
	var flash_tween = create_tween().set_loops(int(invincibility_duration / 0.15))
	flash_tween.tween_property(sprite, "visible", false, 0.07)
	flash_tween.tween_property(sprite, "visible", true, 0.07)
	
	get_tree().create_timer(invincibility_duration).timeout.connect(func():
		is_invincile = false
		sprite.visible = true
		hurtbox_component.set_deferred("monitoring", true)
		hurtbox_component.set_deferred("monitorable", true)
		)


func _on_died() -> void:
	alive = false
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	hurtbox_component.set_deferred("monitoring", false)
	hurtbox_component.set_deferred("monitorable", false)
	hide()
	player_died.emit()
	#TODO: emit signal to main to handle game over or respawn


func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	alive = true
	
	health_component.current_health = health_component.max_health
	
	collision_shape.set_deferred("disabled", false)
	hurtbox_component.set_deferred("monitoring", true)
	hurtbox_component.set_deferred("monitorable", true)
	
	show()
