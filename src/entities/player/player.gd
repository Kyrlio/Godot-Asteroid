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

@export_group("Life")
@export var max_lives: int = 3
@export var max_shield: float = 100.0
@export var shield_regen: float = 2.5

@export_group("Sounds")
@export var laser_sound: AudioStream
@export var impact_sound: AudioStream
@export var explosion_sound: AudioStream

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
var is_losing_life: bool = false

var lives: int = max_lives:
	set(value):
		lives = value
		lives_changed.emit(lives)
		queue_redraw()

var shield: float = 100.0:
	set(value):
		if (value < shield and state != State.ALIVE) or is_losing_life:
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
	var radius: float = 12.0
	var size: Vector2 =  Vector2(2.5, 2.5)
	
	for i in range(lives):
		var angle = orbit_angle - rotation + (i * (TAU / max(lives, 1)))
		var offset_pos = Vector2.RIGHT.rotated(angle) * radius
		draw_rect(Rect2(offset_pos - size / 2.0, size), color)


func change_state(new_state: State) -> void:
	match new_state:
		State.INIT:
			collision_shape.set_deferred("disabled", true)
		State.ALIVE:
			collision_shape.set_deferred("disabled", false)
		State.INVULNERABLE:
			if not is_losing_life:
				_trigger_invincibility()
				invulnerability_timer.start()
		State.DEAD:
			collision_shape.set_deferred("disabled", true)
			AudioManager.play_sfx(explosion_sound, -2.0, 1.0)
			$Sprite2D.hide()
			$EngineSound.stop()
			linear_velocity = Vector2.ZERO
			dead.emit()
	
	state = new_state


func _handle_shield_depleted() -> void:
	if is_losing_life:
		return
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
	if state in [State.DEAD, State.INIT] or is_losing_life:
		return
	if Input.is_action_pressed("move_forward"):
		thrust = transform.x * engine_power
		if not $EngineSound.playing:
			$EngineSound.play()
		if not gpu_particles.emitting:
			gpu_particles.emitting = true
			gpu_particles_2.emitting = true
	else:
		$EngineSound.stop()
		if gpu_particles.emitting:
			gpu_particles.emitting = false
			gpu_particles_2.emitting = false
	rotation_dir = Input.get_axis("rotate_left", "rotate_right")
	
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()


func lose_life() -> void:
	if is_losing_life or lives <= 0: return
	is_losing_life = true
	Globals.is_time_scale_locked = true
	Engine.time_scale = 1.0
	
	if Globals.camera and is_instance_valid(Globals.camera):
		var zoom_tween: Tween = Globals.camera.zoom_to(self, Vector2(1.8, 1.8), 0.25)
		await zoom_tween.finished
	
	var target_index: int = lives - 1
	var radius = 8.0
	
	var angle: float = orbit_angle - rotation + (target_index * (TAU / max(lives, 1)))
	var local_pos: Vector2 = Vector2.RIGHT.rotated(angle) * radius
	var global_pos: Vector2 = to_global(local_pos)
	
	lives -= 1
	lives_changed.emit(lives)
	queue_redraw()
	
	var temp_circle = Node2D.new()
	temp_circle.set_script(preload("uid://d14kq07auhng1"))
	temp_circle.global_position = global_pos
	
	get_tree().current_scene.add_child(temp_circle)
	
	await animate_life_loss_slowmo(temp_circle)
	
	if Globals.camera and is_instance_valid(Globals.camera):
		var restore_tween: Tween = Globals.camera.restore_zoom(0.35)
		await restore_tween.finished
	
	Globals.is_time_scale_locked = false
	is_losing_life = false
	
	if state == State.INVULNERABLE:
		_trigger_invincibility()
		invulnerability_timer.start()


func animate_life_loss_slowmo(circle_node: Node2D) -> void:
	if not is_instance_valid(circle_node):
		return
	
	Globals.is_time_scale_locked = true
	Globals.camera.target = circle_node
	Engine.time_scale = 0.2
	var tween = create_tween().set_ignore_time_scale(true)
	
	tween.set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(circle_node, "scale", Vector2(8.0, 8.0), 0.4).set_delay(0.5)
	tween.tween_property(circle_node, "global_position", Globals.camera.global_position, 0.2)
	tween.tween_property(circle_node, "rotation", circle_node.rotation + (TAU), 0.5).from(circle_node.rotation).set_delay(0.55)
	
	tween.set_parallel(false)
	tween.tween_callback(func():
		Globals.camera.shake(0.2, 40, 3)
		var explosion: GPUParticles2D = explosion_particles_scene.instantiate()
		explosion.global_position = Globals.camera.global_position
		explosion.z_index = 2
		explosion.scale = Vector2(1.8, 1.8)
		explosion.amount *= 2
		explosion.speed_scale = 1.0 / Engine.time_scale
		get_tree().current_scene.add_child(explosion)
		circle_node.queue_free()
		)
	
	tween.tween_interval(0.8)
	await tween.finished
	
	Engine.time_scale = 1.0
	Globals.camera.target = self
	if is_instance_valid(circle_node):
		circle_node.queue_free()


func shoot() -> void:
	if state == State.INVULNERABLE:
		return
	can_shoot = false
	gun_cooldown.start()
	Globals.camera.shake(0.15, 30.0, 2.0)
	animation_player.play("shoot")
	#$LaserSound.play()
	AudioManager.play_sfx(laser_sound, -5.0, randf_range(0.9, 1.1))
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
	if lives < max_lives:
		lives += 1
	shield = max_shield
	Engine.time_scale = 1.0
	is_losing_life = false
	Globals.is_time_scale_locked = false
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
	if is_losing_life:
		return
	change_state(State.ALIVE)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("rocks"):
		if state == State.ALIVE and not is_losing_life:
			AudioManager.play_sfx(impact_sound, -5.0, randf_range(0.9, 1.1))
			var damage: float = body.size * 25
			
			if shield - damage <= 0:
				var delay_timer := get_tree().create_timer(1.0, true, false, true)
				delay_timer.timeout.connect(func(): if is_instance_valid(body): body.explode())
			else:
				body.explode()
			
			shield -= damage
