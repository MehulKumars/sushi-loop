extends Modal
## Settings: music and sound volume, vibration, reduce motion, links and version.
## Values are saved through Settings. Sushi Loop has one look (the `sushi` style), so no picker.

## Replace with your game's privacy policy page before publishing (Google Play requires one).
const PRIVACY_URL: String = "https://example.com/privacy"


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
	%Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	for icon: TextureRect in [%MusicIcon, %SoundIcon, %HapticsIcon, %MotionIcon]:
		icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	refit()


func _bind_slider(slider: HSlider, bus: StringName) -> void:
	slider.value = Settings.volume(bus)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))


func _on_reset() -> void:
	if await UI.confirm("Reset progress?", "Stars and coins on this phone are deleted.", "Reset", true):
		Progress.reset()
		UI.goto(Screens.MAIN_MENU)
