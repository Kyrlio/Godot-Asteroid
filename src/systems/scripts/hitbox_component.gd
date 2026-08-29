class_name HitboxComponent
extends Area2D


@export var damage_amount: int = 1
@export var destroy_on_hit: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hit_direction: Vector2 = Vector2.RIGHT.rotated(global_rotation)
		var target_owner = owner if owner != null else get_parent()
		if target_owner:
			if "direction" in target_owner and target_owner.direction != Vector2.ZERO:
				hit_direction = target_owner.direction.normalized()
			elif "velocity" in target_owner and target_owner.velocity != Vector2.ZERO:
				hit_direction = target_owner.velocity.normalized()
		
		area.take_damage(damage_amount, hit_direction)
		
		if destroy_on_hit and target_owner:
			if target_owner.has_method("destroy"):
				target_owner.destroy()
			else:
				target_owner.queue_free()
