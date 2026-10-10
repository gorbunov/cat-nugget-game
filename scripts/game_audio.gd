extends Node
## Scene-owned playback. The game decides when tracks, pauses and effects occur.

const EFFECT_VOICES := 10
const EFFECT_NAMES := [
	"catch", "combo", "miss", "throw", "tick", "finish",
	"reaction_eww", "reaction_yay", "reaction_nom",
]

var playback_enabled := true
var music: AudioStreamPlayer
var finale: AudioStreamPlayer
var reaction: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	music = _create_player("Music")
	finale = _create_player("Finale")
	reaction = _create_player("Reaction")
	for i in range(EFFECT_VOICES):
		_voices.append(_create_player("Effect%d" % i))
	for effect in EFFECT_NAMES:
		_sounds[effect] = load("res://assets/%s.wav" % effect)


func select_track(track: Dictionary, rate: float, paused: bool) -> void:
	music.stop()
	finale.stop()
	music.stream = _looped("res://assets/%s.wav" % track.file)
	finale.stream = _looped("res://assets/%s.wav" % track.panic)
	set_rate(rate)
	if playback_enabled:
		music.play()
		music.stream_paused = paused


func restart_music() -> void:
	if playback_enabled:
		music.play()


func set_rate(rate: float) -> void:
	# Speed and pitch rise together; both stems must stay in tune.
	music.pitch_scale = rate
	finale.pitch_scale = rate


func pause() -> void:
	music.stream_paused = true
	finale.stream_paused = true


func resume_music() -> void:
	music.stream_paused = false


func start_finale() -> void:
	if playback_enabled:
		finale.stream_paused = false
		finale.play(fmod(music.get_playback_position(), finale.stream.get_length()))


func stop_finale() -> void:
	finale.stop()


func play_effect(key: String, pitch: float = 1.0) -> void:
	if not playback_enabled:
		return
	if key.begins_with("reaction_"):
		# A dedicated voice prevents overlapping vocals and SFX-pool exhaustion.
		_play_on(reaction, key, pitch)
		return
	for voice in _voices:
		if not voice.playing:
			_play_on(voice, key, pitch)
			return


func set_volumes(master: float, soundtrack: float, effects: float) -> void:
	# This component owns the application's Master bus volume and mute state.
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(0.0001, master)))
	AudioServer.set_bus_mute(master_bus, master <= 0)
	music.volume_linear = soundtrack
	finale.volume_linear = soundtrack * 0.18
	reaction.volume_linear = effects * 0.55
	for voice in _voices:
		voice.volume_linear = effects * 0.45


func _create_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player


func _play_on(player: AudioStreamPlayer, key: String, pitch: float) -> void:
	player.stream = _sounds[key]
	player.pitch_scale = pitch
	player.play()


func _looped(path: String) -> AudioStreamWAV:
	var stream := load(path).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
