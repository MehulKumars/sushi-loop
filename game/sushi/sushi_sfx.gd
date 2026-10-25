class_name SushiSfx
extends RefCounted
## Sushi Loop's sound cues by name (take, clink, counter, lid, chime, hop, warn, fail, win, star,
## reveal, coin, unwrap, whoosh, tick) and the music. Finds the Sound autoload at run time
## (/root/Sound), so game code and -s tool scripts compile without it (they break if a class names
## an autoload). Ladders climb the D yo pentatonic scale the cues are tuned to. Sound is never the
## only signal.

const MUSIC: PackedStringArray = ["res://assets/audio/music/first_light_particles.ogg"]
## Semitone steps of the yo pentatonic scale (D E G A B), two octaves.
const LADDER: Array[int] = [0, 2, 5, 7, 9, 12, 14, 17, 19, 21, 24]


## Plays `cue`; `step` above zero climbs the pentatonic ladder (cascade hops, chained bentos).
static func play(cue: StringName, step: int = 0) -> void:
	var sound := _sound()
	if sound == null:
		return
	if step != 0:
		sound.call(&"play_step", cue, LADDER[clampi(step, 0, LADDER.size() - 1)])
	else:
		sound.call(&"play", cue)


## Starts the calm background track (keeps playing across screens; no-op if already playing).
static func music() -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play_playlist", MUSIC, true)


## Dips the music under a fanfare.
static func duck(seconds: float = 1.6) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"duck", seconds)


static func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"Sound") if tree != null else null
