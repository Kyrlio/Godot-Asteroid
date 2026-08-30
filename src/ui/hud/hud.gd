class_name HUD
extends CanvasLayer

signal start_game

@onready var message: Label = %Message
@onready var start_button: Button = %StartButton
@onready var score_label: Label = %ScoreLabel
@onready var shield_bar: TextureProgressBar = %ShieldBar

var old_score: int = 0
var score_tween: Tween

func _ready() -> void:
	score_label.text = "0"

func show_message(text: String) -> void:
	message.text = text
	message.offset_transform_scale = Vector2.ZERO
	message.show()
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_parallel(true)
	tween.tween_property(message, "offset_transform_scale", Vector2.ONE, 1.6).from(Vector2.ZERO)
	$Timer.start()


func update_score(value: int) -> void:
	if score_tween and score_tween.is_running():
		score_tween.kill()
	
	score_label.pivot_offset = score_label.size / 2.0
	
	score_tween = create_tween().set_parallel(true)
	score_tween.tween_method(
		func(val: int): score_label.text = str(val), 
		old_score, 
		value, 
		0.4
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	score_tween.tween_property(score_label, "offset_transform_scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	score_tween.chain().tween_property(score_label, "offset_transform_scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	old_score = value


func update_shield(value: float) -> void:
	shield_bar.value = value


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
