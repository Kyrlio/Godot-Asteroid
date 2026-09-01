class_name ShieldBar
extends Control

@onready var damage_bar: TextureProgressBar = %DamageBar
@onready var shield_bar: TextureProgressBar = %ShieldBar

@export_group("Juice Settings")
@export var max_shake_offset: Vector2 = Vector2(1.5, 1.0)
@export var trauma_decay: float = 3.5
@export var punch_scale: Vector2 = Vector2(1.15, 1.25)
@export var damage_delay: float = 0.25
@export var damage_catchup_speed: float = 0.35

var current_ratio: float = 1.0
var trauma: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var is_ready_layout: bool = false

var punch_tween: Tween
var damage_catchup_tween: Tween

func _ready() -> void:
	pivot_offset = custom_minimum_size / 2.0
	shield_bar.value = 1.0
	damage_bar.value = 1.0
	current_ratio = 1.0
	
	await get_tree().process_frame
	base_position = position
	is_ready_layout = true


func _process(delta: float) -> void:
	if not is_ready_layout:
		return
		
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)
		var shake_power: float = trauma * trauma
		var offset: Vector2 = Vector2(
			randf_range(-1.0, 1.0) * max_shake_offset.x * shake_power,
			randf_range(-1.0, 1.0) * max_shake_offset.y * shake_power
		)
		position = base_position + offset
	else:
		position = base_position


func update_shield(new_ratio: float) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	var diff: float = new_ratio - current_ratio
	
	# Taking damage
	if diff < -0.001:
		current_ratio = new_ratio
		shield_bar.value = new_ratio
		_trigger_damage_juice(new_ratio)
		
	# Heal
	elif diff > 0.0001:
		current_ratio = new_ratio
		shield_bar.value = new_ratio
		
		if damage_catchup_tween == null or not damage_catchup_tween.is_running():
			damage_bar.value = new_ratio
		else:
			damage_bar.value = max(damage_bar.value, shield_bar.value)


func _trigger_damage_juice(target_ratio: float) -> void:
	trauma = min(trauma + 0.8, 1.0)
	
	if punch_tween and punch_tween.is_running():
		punch_tween.kill()
	offset_transform_scale = punch_scale
	punch_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.3)

	if damage_catchup_tween and damage_catchup_tween.is_running():
		damage_catchup_tween.kill()
		
	damage_catchup_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	damage_catchup_tween.tween_interval(damage_delay)
	damage_catchup_tween.tween_property(damage_bar, "value", target_ratio, damage_catchup_speed)
