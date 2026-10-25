class_name SushiSfx
extends RefCounted
## Sushi Loop's sound cues by name (take, clink, counter, lid, chime, hop, warn, fail, win, tick).
## Finds the Sound autoload at run time (/root/Sound), so game code and -s tool scripts compile
## without it (they break if a class names an autoload). Sound is never the only signal.


## Plays `cue`; `semitones` above zero climbs a ladder (the cascade hops).
static func play(cue: StringName, semitones: int = 0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sound := tree.root.get_node_or_null(^"Sound")
	if sound == null:
		return
	if semitones != 0:
		sound.call(&"play_step", cue, semitones)
	else:
		sound.call(&"play", cue)
