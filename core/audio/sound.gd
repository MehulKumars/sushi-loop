extends Node
## Autoload Sound: named one-shot effects from a pool of players (pitch variation, semitone steps
## for combos), a click on every button press, and music playlists on two players of its own that
## crossfade between tracks and keep playing across scenes and pauses (songs in turn, or rotating
## loops). Volumes are the Settings buses. An effect is `id.wav`, or recorded variants
## `id_1.wav`, `id_2.wav` ... of which each play picks one (no machine-gun repeats).

const SFX_PATH: String = "res://assets/audio/sfx/%s.wav"
const MAX_VARIANTS: int = 9
const POOL_SIZE: int = 12
const MUSIC_FADE: float = 1.2
## Volume of a music player that is faded all the way out.
const SILENT_DB: float = -40.0
## Sounds that carry a meaning players learn (confirm tones, the combo ladder) keep their pitch.
const STEADY: Array[StringName] = [&"tick", &"click", &"chime", &"hop", &"warn", &"fail", &"win", &"star", &"reveal"]

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary[StringName, Array] = {}
var _last_variant: Dictionary[StringName, int] = {}
var _playlist := PackedStringArray()
var _loops: bool = false
var _rotate_seconds: float = 0.0
var _track: int = 0
var _rotate := Timer.new()
var _rng := RandomNumberGenerator.new()
## Two music players: the one playing (`_music[_current]`) and the one fading out.
var _music: Array[AudioStreamPlayer] = []
var _current: int = 0
var _fade: Tween
var _duck: Tween


func _init() -> void:
	# Menus pause the game; clicks, fanfares and music keep playing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_music.append(player)
	_rotate.one_shot = true
	_rotate.timeout.connect(_next_track)
	add_child(_rotate)


func _ready() -> void:
	_rng.randomize()
	get_tree().node_added.connect(_on_node_added)


## Plays effect `id` (a file in assets/audio/sfx/). `pitch` multiplies the natural pitch.
func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch if STEADY.has(id) else pitch * _rng.randf_range(0.96, 1.04)
	player.play()


## The same effect `semitones` higher (combo chains climb one step per snap).
func play_step(id: StringName, semitones: int, volume_db: float = 0.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pow(2.0, semitones / 12.0)
	player.play()


## Plays `paths` in turn, crossfading from whatever plays now. With `loops`, each file loops and
## the next takes over after `rotate_seconds` (soundscapes). The same list keeps playing.
func play_playlist(paths: PackedStringArray, loops: bool = false, rotate_seconds: float = 0.0) -> void:
	if paths.is_empty() or paths == _playlist:
		return
	_playlist = paths
	_loops = loops
	_rotate_seconds = rotate_seconds
	_track = _rng.randi_range(0, paths.size() - 1)
	_play_track()


func stop_music() -> void:
	_playlist = PackedStringArray()
	_rotate.stop()
	_crossfade(null)


func _play_track() -> void:
	_rotate.stop()
	var path := _playlist[_track]
	var stream := load(path) as AudioStreamOggVorbis if ResourceLoader.exists(path) else null
	if stream == null:
		return
	stream.loop = _loops
	var player := _crossfade(stream)
	if _loops:
		if _playlist.size() > 1 and _rotate_seconds > 0.0:
			_rotate.start(_rotate_seconds)
	else:
		player.finished.connect(_next_track.bind(_playlist), CONNECT_ONE_SHOT)


## Fades the playing track out and `stream` in on the other player (null: just fade out).
func _crossfade(stream: AudioStream) -> AudioStreamPlayer:
	if _fade != null:
		_fade.kill()
	if _duck != null:
		_duck.kill()
	var old := _music[_current]
	for connection in old.finished.get_connections():
		old.finished.disconnect(connection.callable)
	_fade = create_tween().set_parallel()
	if old.playing:
		_fade.tween_property(old, ^"volume_db", SILENT_DB, MUSIC_FADE)
	if stream == null:
		_fade.chain().tween_callback(old.stop)
		return old
	_current = 1 - _current
	var player := _music[_current]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade.tween_property(player, ^"volume_db", 0.0, MUSIC_FADE)
	_fade.chain().tween_callback(old.stop)
	return player


## The next song (or soundscape), unless the player picked another list meanwhile.
func _next_track(list: PackedStringArray = PackedStringArray()) -> void:
	if _playlist.is_empty() or (not list.is_empty() and list != _playlist):
		return
	_track = (_track + 1) % _playlist.size()
	_play_track()


## Lowers the music for a moment so a fanfare reads clearly, then brings it back.
func duck(seconds: float = 1.4, depth_db: float = -8.0) -> void:
	var player := _music[_current]
	if _playlist.is_empty() or not player.playing or (_fade != null and _fade.is_running()):
		return
	if _duck != null:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_property(player, ^"volume_db", depth_db, 0.15)
	_duck.tween_interval(seconds)
	_duck.tween_property(player, ^"volume_db", 0.0, 0.8)


## One of the effect's variants, never the same one twice in a row.
func _stream(id: StringName) -> AudioStream:
	if not _streams.has(id):
		var found: Array[AudioStream] = []
		var path := SFX_PATH % id
		if ResourceLoader.exists(path):
			found.append(load(path))
		for i in range(1, MAX_VARIANTS + 1):
			path = SFX_PATH % ("%s_%d" % [id, i])
			if not ResourceLoader.exists(path):
				break
			found.append(load(path))
		_streams[id] = found
	var streams: Array = _streams[id]
	if streams.is_empty():
		return null
	var pick := _rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and pick == _last_variant.get(id, -1):
		pick = (pick + 1) % streams.size()
	_last_variant[id] = pick
	return streams[pick]


## A soft click on every button press; buttons opt out with the meta `ui_sound = false`.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and button.get_meta(&"ui_sound", true):
		play(&"click", 1.0, -2.0)
