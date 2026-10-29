class_name Settings
extends RefCounted
## The player's settings in one place (user://settings.cfg): music and sound volume, vibration,
## reduce motion. Used by the settings and pause popups, AppLifecycle (applies them at start and
## on resume) and game code. A missing file or key means the default.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const AUDIO: String = "audio"
const FEEL: String = "feel"

## Where the settings live; tests point it elsewhere and call load_from_disk().
static var path: String = "user://settings.cfg"
static var _config: ConfigFile = null


## Linear volume 0..1 of an audio bus ("Music", "SFX").
static func volume(bus: StringName) -> float:
	return clampf(float(_cfg().get_value(AUDIO, String(bus), 1.0)), 0.0, 1.0)


static func set_volume(bus: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_cfg().set_value(AUDIO, String(bus), linear)
	_save()
	_apply_bus(bus, linear)


## Pushes the saved volumes into the audio buses (at start).
static func apply_audio() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		_apply_bus(bus, volume(bus))


static func haptics() -> bool:
	return bool(_cfg().get_value(FEEL, "haptics", true))


static func set_haptics(enabled: bool) -> void:
	_cfg().set_value(FEEL, "haptics", enabled)
	_save()
	_apply()
	if enabled:
		Haptics.tick()


static func reduce_motion() -> bool:
	return bool(_cfg().get_value(FEEL, "reduce_motion", false))


static func set_reduce_motion(enabled: bool) -> void:
	_cfg().set_value(FEEL, "reduce_motion", enabled)
	_save()
	_apply()


## Forgets the cached values and reads `path` again.
static func load_from_disk() -> void:
	_config = ConfigFile.new()
	if FileAccess.file_exists(path):
		_config.load(path)


## Deletes the saved settings (back to the defaults).
static func clear() -> void:
	_config = ConfigFile.new()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _cfg() -> ConfigFile:
	if _config == null:
		load_from_disk()
	return _config


static func _save() -> void:
	_config.save(path)


static func _apply_bus(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


static func _apply() -> void:
	AppLifecycle.apply_settings()
