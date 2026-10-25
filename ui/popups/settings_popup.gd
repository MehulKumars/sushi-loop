extends Modal
## Settings: music and sound volume, vibration, reduce motion, links and version.
## The style picker shows in debug builds so you can compare the five styles on a phone;
## turn on `show_style_picker` to let players choose. Values are saved through Settings.

## Replace with your game's privacy policy page before publishing (Google Play requires one).
const PRIVACY_URL: String = "https://example.com/privacy"

@export var show_style_picker: bool = false


func _ready() -> void:
	super._ready()
	_bind_slider(%MusicSlider, Settings.MUSIC_BUS)
	_bind_slider(%SoundSlider, Settings.SFX_BUS)
	%HapticsToggle.button_pressed = Settings.haptics()
	%HapticsToggle.toggled.connect(Settings.set_haptics)
	%MotionToggle.button_pressed = Settings.reduce_motion()
	%MotionToggle.toggled.connect(Settings.set_reduce_motion)
	%CloseButton.pressed.connect(close)
	%CreditsButton.pressed.connect(UI.goto.bind(Screens.CREDITS))
	%PrivacyButton.pressed.connect(OS.shell_open.bind(PRIVACY_URL))
	%ResetButton.pressed.connect(_on_reset)
	%GalleryButton.pressed.connect(UI.goto.bind(Screens.GALLERY))
	%Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	for icon: TextureRect in [%MusicIcon, %SoundIcon, %HapticsIcon, %MotionIcon]:
		icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	%StyleSection.visible = show_style_picker or OS.is_debug_build()
	if %StyleSection.visible:
		_build_style_chips()
	refit()


func _bind_slider(slider: HSlider, bus: StringName) -> void:
	slider.value = Settings.volume(bus)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))


func _build_style_chips() -> void:
	var group := ButtonGroup.new()
	for id in UI.list_styles():
		var style := load("res://core/ui/styles/%s.tres" % id) as UIStyle
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.text = style.display_name if style != null else String(id)
		chip.button_pressed = id == UI.current_style
		chip.pressed.connect(_on_style_chosen.bind(id))
		%StyleChips.add_child(chip)


func _on_style_chosen(id: StringName) -> void:
	if id == UI.current_style:
		return
	UI.apply_style(id)
	# Rebuild the screen underneath and this popup so everything picks up the new style.
	close()
	get_tree().reload_current_scene()


func _on_reset() -> void:
	if await UI.confirm("Reset progress?", "Stars and coins on this phone are deleted.", "Reset", true):
		Progress.reset()
		UI.goto(Screens.MAIN_MENU)
