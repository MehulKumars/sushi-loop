class_name SushiSfx
extends RefCounted
## Sushi Loop's sound cues by name (take, clink, counter, lid, cascade, warn, fail, win, tick).
## Finds the Sound autoload at run time (/root/Sound), so game code and -s tool scripts compile
## without it, and stays silent until it exists. Sound is never the only signal of an event.


static func play(cue: StringName, semitones: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sound := tree.root.get_node_or_null(^"Sound")
	if sound != null and sound.has_method(&"play"):
		sound.call(&"play", cue, semitones)
