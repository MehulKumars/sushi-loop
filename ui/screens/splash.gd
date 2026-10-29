extends Screen
## First screen after launch: the game's name for a moment (tap to skip), then straight into
## level 1 for a player who has not won a level yet, or home for everyone else. Counts the
## session and starts the music. Android shows the app icon on its own launch splash just before
## this (export preset > splash_screen/icon), so the two together read as one short start.

const HOLD_SECONDS: float = 0.6
const MARK := preload("res://assets/icon/icon_splash_512.png")

var _leaving: bool = false


func _ready() -> void:
	%Title.text = ProjectSettings.get_setting("application/config/name", "Mobile Game")
	# One launch = one session (AdPolicy keeps the first session free of interstitials).
	Progress.set_count("sessions", Progress.count("sessions") + 1)
	SushiSfx.music()
	# The app icon's plate and loop over the name, as on Android's own launch splash.
	var mark := TextureRect.new()
	mark.texture = MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(240, 240)
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	%Logo.add_child(mark)
	%Logo.move_child(mark, 0)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = HOLD_SECONDS
	timer.timeout.connect(_continue)
	add_child(timer)
	timer.start()
	if Juice.motion_scale > 0.0:
		var logo: Control = %Logo
		logo.modulate.a = 0.0
		logo.pivot_offset_ratio = Vector2(0.5, 0.5)
		logo.scale = Vector2.ONE * 0.92
		var tween := create_tween().set_parallel()
		tween.tween_property(logo, ^"modulate:a", 1.0, 0.35)
		tween.tween_property(logo, ^"scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		_continue()


func on_back() -> void:
	_continue()


func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	UI.goto(first_screen())


## Where a launch lands: a new player plays at once, the rest see home.
static func first_screen() -> String:
	if Progress.levels_won() == 0:
		Screens.level = 1
		return Screens.GAME
	return Screens.MAIN_MENU
