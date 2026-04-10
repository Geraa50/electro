extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var music_enabled: bool = true
var sfx_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

func play_music(stream: AudioStream) -> void:
	if not music_enabled:
		return
	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(stream: AudioStream) -> void:
	if not sfx_enabled:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.bus = "Master"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)

func toggle_music() -> void:
	music_enabled = not music_enabled
	if not music_enabled:
		stop_music()

func toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled
