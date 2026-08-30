class_name Rock
extends RigidBody2D

signal exploded(size: float, radius: float, position: Vector2, linear_velocity: Vector2)

@export var explosion_particles_scene: PackedScene

@export_group("Textures")
@export var big_rock_textures: Array[Texture2D]
@export var medium_rock_textures: Array[Texture2D]
@export var small_rock_textures: Array[Texture2D]

var screen_size: Vector2 = Vector2.ZERO
var size: float
var radius: float
var scale_factor: float = 1.2


func start(_position: Vector2, _velocity: Vector2, _size: float) -> void:
	position = _position
	size = _size
	mass = 1.5 * size
	
	var chosen_texture: Texture2D = null
	$Sprite2D.frame = 0
	var anim_to_play: String = "default"
	match int(size):
		3:
			if not big_rock_textures.is_empty():
				chosen_texture = big_rock_textures.pick_random()
				$Sprite2D.hframes = 8
				anim_to_play = "default"
		2:
			if not medium_rock_textures.is_empty():
				chosen_texture = medium_rock_textures.pick_random()
				$Sprite2D.hframes = 8
				anim_to_play = "default"
		1:
			if not small_rock_textures.is_empty():
				chosen_texture = small_rock_textures.pick_random()
				$Sprite2D.hframes = 4
				anim_to_play = "small_rock"
	
	if chosen_texture:
		$Sprite2D.texture = chosen_texture
	
	$AnimationPlayer.play(anim_to_play)
	
	$Sprite2D.scale = Vector2.ONE * scale_factor
	
	var texture_width: float = $Sprite2D.texture.get_size().x / $Sprite2D.hframes
	var sprite_width: float = ($Sprite2D.region_rect.size.x / $Sprite2D.hframes) if $Sprite2D.region_enabled else texture_width
	radius = int(sprite_width / 2.0 * $Sprite2D.scale.x)
	
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	linear_velocity = _velocity
	angular_velocity = randf_range(-PI / 2, PI / 2)


func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	var xform: Transform2D = physics_state.transform
	xform.origin.x = wrapf(xform.origin.x, 0 - radius, screen_size.x + radius)
	xform.origin.y = wrapf(xform.origin.y, 0 - radius, screen_size.y + radius)
	physics_state.transform = xform


func explode() -> void:
	Globals.camera.shake(0.25, 40.0, 3.0)
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.hide()
	spawn_explosion_particles()
	exploded.emit(size, radius, position, linear_velocity)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	queue_free.call_deferred()

func spawn_explosion_particles() -> void:
	var instance: GPUParticles2D = explosion_particles_scene.instantiate()
	instance.global_position = global_position
	get_tree().root.add_child(instance)
	instance.restart()
	instance.emitting = true
