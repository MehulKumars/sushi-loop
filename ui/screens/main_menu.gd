extends Screen
## Home screen: the Sushi Loop title up top, the big Play button and Levels in the thumb zone.
## Play starts the next level not yet won. Back asks before quitting (Android convention).
## v1 is free: no shop, daily reward or ranks.

@onready var _coins: CurrencyPill = %Coins
@onready var _title: Label = %Title
@onready var _logo: Control = %Logo
@onready var _play: Button = %PlayButton


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Mobile Game")
	_coins.value = Progress.coins()
	_play.text = "Play  Level %d" % Progress.next_level()
	_play.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_on_settings)
	%LevelsButton.pressed.connect(UI.goto.bind(Screens.LEVEL_SELECT))
	_build_mark()
	_intro()


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


func _on_play() -> void:
	Screens.level = Progress.next_level()
	UI.goto(Screens.GAME)


func _on_settings() -> void:
	await UI.open(load(Screens.SETTINGS) as PackedScene).closed
	_coins.value = Progress.coins()


## Three plates on a stretch of belt above the title.
func _build_mark() -> void:
	var mark := SushiLogo.new()
	mark.custom_minimum_size = Vector2(360, 120)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(mark)
	_logo.move_child(mark, 0)


## Logo drops in, then the Play button breathes gently to draw the eye (off with Reduce Motion).
func _intro() -> void:
	if Juice.motion_scale <= 0.0:
		return
	_logo.modulate.a = 0.0
	_logo.pivot_offset_ratio = Vector2(0.5, 0.5)
	_logo.scale = Vector2.ONE * 0.85
	var tween := create_tween().set_parallel()
	tween.tween_property(_logo, ^"modulate:a", 1.0, 0.35)
	tween.tween_property(_logo, ^"scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play.pivot_offset_ratio = Vector2(0.5, 0.5)
	var breathe := create_tween().set_loops()
	breathe.tween_interval(1.2)
	breathe.tween_property(_play, ^"scale", Vector2.ONE * (1.0 + 0.035 * Juice.motion_scale), 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_play, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_play.button_down.connect(breathe.kill, CONNECT_ONE_SHOT)
