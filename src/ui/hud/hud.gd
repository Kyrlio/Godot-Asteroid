class_name HUD
extends CanvasLayer

signal start_game

@onready var message: Label = $MarginContainer/VBoxContainer/Message
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel


func show_message(text: String) -> void:
	message.text = text
	message.offset_transform_scale = Vector2.ZERO
	message.show()
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_parallel(true)
	tween.tween_property(message, "offset_transform_scale", Vector2.ONE, 1.6).from(Vector2.ZERO)
	$Timer.start()


func update_score(value: int) -> void:
	score_label.text = str(value)


func game_over() -> void:
	show_message("Game Over")
	await $Timer.timeout
	start_button.show()


func _on_start_button_pressed() -> void:
	await get_tree().create_timer(0.2).timeout
	start_button.hide()
	start_game.emit()


func _on_timer_timeout() -> void:
	message.hide()
	message.text = ""
