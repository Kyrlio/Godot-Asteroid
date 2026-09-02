extends Node

const SFX_POOL_SIZE: int = 8
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0

var _current_music_player: AudioStreamPlayer
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		player.bus = "SFX"
		_sfx_pool.append(player)


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream: return
	
	var player = _sfx_pool[_next_player_index]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	
	_next_player_index = (_next_player_index + 1) % SFX_POOL_SIZE


func play_sfx_2d(stream: AudioStream, global_pos: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream: return
	
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = global_pos
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = "SFX"
	
	get_tree().current_scene.add_child(player)
	player.play()
	
	player.finished.connect(player.queue_free)


func play_music(new_track: AudioStream, fade_duration: float = 1.0, volume_db: float = -12.0) -> void:
	if not new_track: return
	if _current_music_player and _current_music_player.stream == new_track:
		return
		
	var new_player = AudioStreamPlayer.new()
	new_player.stream = new_track
	new_player.volume_db = -80.0
	new_player.bus = "Music"
	add_child(new_player)
	new_player.play()
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	_fade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	_fade_tween.tween_property(new_player, "volume_db", volume_db, fade_duration)
	
	if _current_music_player:
		var old_player = _current_music_player
		_fade_tween.tween_property(old_player, "volume_db", -80.0, fade_duration)
		_fade_tween.chain().tween_callback(old_player.queue_free)
		
	_current_music_player = new_player
