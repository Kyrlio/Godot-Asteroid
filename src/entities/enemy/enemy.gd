class_name Enemy
extends Area2D

@export var explosion_particle_scene: PackedScene
@export var bullet_scene: PackedScene
@export var speed: int = 25
@export var health: int = 3
@export var bullet_spread: float = 0.2

var follow: PathFollow2D = PathFollow2D.new()
var target: Player = null

#Hitstop
var hitstop_frames: int = 0
var hitstop_hit: int = 4
var hitstop_explode: int = 5


func _ready() -> void:
	var path = $EnemyPaths.get_children()[randi() % $EnemyPaths.get_child_count()]
	path.add_child(follow)
	follow.loop = false
	follow.rotates = false


func _physics_process(delta: float) -> void:
	if hitstop_frames > 0:
		hitstop_frames -= 1
		if hitstop_frames <= 0:
			stop_hitstop()
		return
	
	follow.progress += speed * delta
	position = follow.global_position
	if follow.progress_ratio >= 1:
		queue_free()


func shoot() -> void:
	var dir = global_position.direction_to(target.global_position)
	dir = dir.rotated(randf_range(-bullet_spread, bullet_spread))
	var bullet: EnemyBullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.start(global_position, dir)


func shoot_pulse(n: int, delay: float) -> void:
	for i in n:
		shoot()
		await get_tree().create_timer(delay).timeout


func take_damage(amount: int) -> void:
	health -= amount
	$AnimationPlayer.play("hit_flash")
	$GunCooldown.start()
	if health <= 0:
		explode()


func start_hitstop(hitstop_amount: int) -> void:
	$AnimationPlayer.pause()
	hitstop_frames = hitstop_amount


func stop_hitstop() -> void:
	$AnimationPlayer.play()
	hitstop_frames = 0


func explode() -> void:
	speed = 0
	$GunCooldown.stop()
	Globals.camera.shake(0.25, 40.0, 3.0)
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.hide()
	spawn_explosion_particles()
	start_hitstop(hitstop_explode)
	queue_free.call_deferred()


func spawn_explosion_particles() -> void:
	var instance: GPUParticles2D = explosion_particle_scene.instantiate()
	instance.global_position = global_position
	get_tree().root.add_child(instance)
	instance.restart()
	instance.emitting = true


func _on_gun_cooldown_timeout() -> void:
	shoot_pulse(3, 0.15)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("rocks"):
		return
	if body is Player:
		body.shield -= 50
		explode()
