class_name Player
extends RigidBody2D

signal lives_changed(lives: int)
signal dead
signal shield_changed

enum State {INIT, ALIVE, INVULNERABLE, DEAD}

@export_group("Movement")
@export var engine_power: int = 150
@export var spin_power: int = 180

@export_group("Combat")
@export var explosion_particles_scene: PackedScene
@export var muzzle_flash_particles_scene: PackedScene
@export var bullet_scene: PackedScene
@export var fire_rate = 0.25
@export var max_shield: float = 100.0
@export var shield_regen: float = 2.5

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var gun_cooldown: Timer = $GunCooldown
@onready var muzzle: Marker2D = $Muzzle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2: GPUParticles2D = $GPUParticles2D2
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

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
		queue_redraw()

var shield: float = 100.0:
	set(value):
		if value < shield and state != State.ALIVE:
			return
		var clamped_val: float = clampf(value, 0.0, max_shield)
		if is_equal_approx(shield, clamped_val): return
		shield = clamped_val
		shield_changed.emit(shield / max_shield)
		if shield <= 0:
			_handle_shield_depleted()

func _ready() -> void:
	change_state(State.ALIVE)
	screen_size = get_viewport_rect().size
	gun_cooldown.wait_time = fire_rate


func _process(delta: float) -> void:
	get_input()
	
	shield += shield_regen * delta
	
	# Lives circles
	orbit_angle += 3.0 * delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	constant_force = thrust
	constant_torque = rotation_dir * spin_power


func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	if reset_pos:
		physics_state.transform.origin = screen_size / 2.0
		reset_pos = false
	
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
			#collision_shape.set_deferred("disabled", true)
			_trigger_invincibility()
			invulnerability_timer.start()
		State.DEAD:
			collision_shape.set_deferred("disabled", true)
			$Sprite2D.hide()
			linear_velocity = Vector2.ZERO
			dead.emit()
	
	state = new_state


func _handle_shield_depleted() -> void:
	if lives > 1:
		change_state(State.INVULNERABLE)
		shield = max_shield
		lose_life()
	else:
		lives = 0
		lives_changed.emit(0)
		gpu_particles.emitting = false
		gpu_particles_2.emitting = false
		Globals.freeze_requested.emit(0.3, 2.5)
		spawn_explosion_particles()
		change_state(State.DEAD)


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


func lose_life() -> void:
	if lives <= 0: return
	
	# 1. Zoom de la caméra sur le joueur (avec suivi dynamique de self)
	if Globals.camera and is_instance_valid(Globals.camera):
		var zoom_tween: Tween = Globals.camera.zoom_to(self, Vector2(1.8, 1.8), 0.25)
		await zoom_tween.finished
	
	# 2. Calcul de la position du cercle de vie qui va se détacher
	var target_index: int = lives - 1
	var radius = 8.0
	
	var angle: float = orbit_angle - rotation + (target_index * (TAU / max(lives, 1)))
	var local_pos: Vector2 = Vector2.RIGHT.rotated(angle) * radius
	var global_pos: Vector2 = to_global(local_pos)
	
	# Décrémenter la vie pour mettre à jour l'affichage orbital
	lives -= 1
	lives_changed.emit(lives)
	queue_redraw()
	
	# Instancier le cercle temporaire dans la scène à sa position globale (reste sur place)
	var temp_circle = Node2D.new()
	temp_circle.set_script(preload("uid://d14kq07auhng1"))
	temp_circle.global_position = global_pos
	
	get_tree().current_scene.add_child(temp_circle)
	
	# 3. Lancer l'animation de perte de vie en slow motion
	await animate_life_loss_slowmo(temp_circle)
	
	# 4. Retour du zoom caméra à la normale
	if Globals.camera and is_instance_valid(Globals.camera):
		var restore_tween: Tween = Globals.camera.restore_zoom(0.35)
		await restore_tween.finished


func animate_life_loss_slowmo(circle_node: Node2D) -> void:
	if not is_instance_valid(circle_node):
		return
	
	Engine.time_scale = 0.5
	var tween = create_tween().set_ignore_time_scale(true)
	
	# Grossir le cercle temporaire et le saturer vers le blanc
	tween.set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(circle_node, "scale", Vector2(3.0, 3.0), 0.3).set_delay(0.3)
	#tween.tween_property(circle_node, "modulate", Color(15.934, 16.145, 15.652, 1.0), 0.5)
	
	# Rétrécir jusqu'à disparaître
	tween.set_parallel(false)
	tween.tween_property(circle_node, "scale", Vector2.ZERO, 0.2).set_delay(0.2)
	
	# Attendre la fin de l'effet
	await tween.finished
	await get_tree().create_timer(0.3).timeout
	
	# Rétablir le temps et détruire le nœud d'effet
	Engine.time_scale = 1.0
	if is_instance_valid(circle_node):
		circle_node.queue_free()


func shoot() -> void:
	if state == State.INVULNERABLE:
		return
	can_shoot = false
	gun_cooldown.start()
	Globals.camera.shake(0.15, 30.0, 2.0)
	animation_player.play("shoot")
	#spawn_muzzle_flash()
	var bullet: Bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.start(muzzle.global_transform)


func spawn_muzzle_flash() -> void:
	var instance: GPUParticles2D = muzzle_flash_particles_scene.instantiate()
	instance.global_transform = muzzle.global_transform
	get_tree().root.add_child(instance)
	instance.restart()
	instance.emitting = true


func spawn_explosion_particles() -> void:
	var instance: GPUParticles2D = explosion_particles_scene.instantiate()
	instance.global_position = global_position
	get_tree().root.add_child(instance)
	instance.restart()
	instance.emitting = true


func reset() -> void:
	reset_pos = true
	$Sprite2D.show()
	for child in get_children():
		if child is LiveCircle:
			child.queue_free()
	lives = 3
	shield = max_shield
	Engine.time_scale = 1.0
	if Globals.camera and is_instance_valid(Globals.camera):
		Globals.camera.reset_camera()
	change_state(State.ALIVE)


func _trigger_invincibility() -> void:
	var invincibility_duration: int = invulnerability_timer.wait_time
	var flash_tween: Tween = create_tween().set_loops(int(invincibility_duration / 0.15))
	flash_tween.tween_property($Sprite2D, "visible", false, 0.07)
	flash_tween.tween_property($Sprite2D, "visible", true, 0.07)
	
	get_tree().create_timer(invincibility_duration).timeout.connect(func():
		$Sprite2D.visible = true
		)


func _on_gun_cooldown_timeout() -> void:
	can_shoot = true


func _on_invulnerability_timer_timeout() -> void:
	change_state(State.ALIVE)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("rocks"):
		if state == State.ALIVE:
			shield -= body.size * 25
			body.explode()
