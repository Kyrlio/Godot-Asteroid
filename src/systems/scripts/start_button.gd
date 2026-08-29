extends Button

var tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	if tween and tween.is_running():
		tween.kill()
	
	self.pivot_offset.x = size.x / 2.0
	self.pivot_offset.y = size.y / 2.0
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_parallel(true)
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 2).from(Vector2(1.1, 1.1))
	tween.tween_property(self, "rotation_degrees", 0, 2).from((-15 if randi_range(0,1) == 1 else 15) * 1)


func _on_pressed() -> void:
	if tween and tween.is_running():
		tween.kill()
	
	self.pivot_offset.x = size.x / 2.0
	self.pivot_offset.y = size.y / 2.0
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_parallel(true)
	tween.tween_property(self, "rotation_degrees", 0, 2).from((-10 if randi_range(0,1) == 1 else 10) * 1)
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 2).from(Vector2(0.8, 0.8))
