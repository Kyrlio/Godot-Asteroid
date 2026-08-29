class_name Player
extends RigidBody2D

signal lives_changed(lives: int)
signal dead

enum State {INIT, ALIVE, INVULNERABLE, DEAD}

@export_group("Movement")
@export var engine_power: int = 150
@export var spin_power: int = 180

@export_group("Combat")
@export var bullet_scene: PackedScene
@export var fire_rate = 0.25

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var gun_cooldown: Timer = $GunCooldown
@onready var muzzle: Marker2D = $Muzzle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2: GPUParticles2D = $GPUParticles2D2

var state: State = State.INIT
var thrust: Vector2 = Vector2.ZERO
var rotation_dir: float = 0.0
var margin: float = 4.0
var screen_size: Vector2 = Vector2.ZERO
var can_shoot: bool = true
var reset_pos: bool = false
var orbit_angle: float = 0.0
var lives: int = 3:
	set(value):
		lives = value
		lives_changed.emit(lives)
		if lives <= 0:
			change_state(State.DEAD)
		else:
			change_state(State.INVULNERABLE)

func _ready() -> void:
	change_state(State.ALIVE)
	screen_size = get_viewport_rect().size
	gun_cooldown.wait_time = fire_rate


func _process(delta: float) -> void:
	get_input()
	orbit_angle += 3.0 * delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	constant_force = thrust
	constant_torque = rotation_dir * spin_power


func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	var xform: Transform2D = physics_state.transform
	xform.origin.x = wrapf(xform.origin.x, 0 - margin, screen_size.x + margin)
	xform.origin.y = wrapf(xform.origin.y, 0 - margin, screen_size.y + margin)
	physics_state.transform = xform


func _draw() -> void:
	if state == State.DEAD: return
	
	var color = Color(0.902, 0.725, 0.353, 1.0)
	var radius = 8.0
	
	for i in range(lives):
		var angle = orbit_angle - rotation + (i * (TAU / max(lives, 1)))
		var offset_pos = Vector2.RIGHT.rotated(angle) * radius
		draw_circle(offset_pos, 1.2, color)

func change_state(new_state: State) -> void:
	match new_state:
		State.INIT:
			collision_shape.set_deferred("disabled", true)
		State.ALIVE:
			collision_shape.set_deferred("disabled", false)
		State.INVULNERABLE:
			collision_shape.set_deferred("disabled", true)
		State.DEAD:
			collision_shape.set_deferred("disabled", true)
	
	state = new_state


func get_input() -> void:
	thrust = Vector2.ZERO
	if state in [State.DEAD, State.INIT]:
		return
	if Input.is_action_pressed("move_forward"):
		thrust = transform.x * engine_power
		if not gpu_particles.emitting:
			gpu_particles.emitting = true
			gpu_particles_2.emitting = true
	else:
		if gpu_particles.emitting:
			gpu_particles.emitting = false
			gpu_particles_2.emitting = false
	rotation_dir = Input.get_axis("rotate_left", "rotate_right")
	
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()


func shoot() -> void:
	if state == State.INVULNERABLE:
		return
	can_shoot = false
	gun_cooldown.start()
	Globals.camera.shake(0.15, 30.0, 2.0)
	animation_player.play("shoot")
	var bullet: Bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.start(muzzle.global_transform)


func _on_gun_cooldown_timeout() -> void:
	can_shoot = true
