class_name UpgradePod
extends Area2D

signal selected(upgrade: UpgradeData)

@export var upgrade_data: UpgradeData

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = upgrade_data.texture
	health_component.died.connect(_on_died)


func _on_died() -> void:
	selected.emit(upgrade_data)
	#TODO : explosion, juice
	queue_free()
