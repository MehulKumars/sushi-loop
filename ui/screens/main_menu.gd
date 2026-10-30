extends Screen
## Home: the game's mark and name under the current restaurant's noren curtain, the restaurant as
## a card (name, twist, stars, levels won; a tap opens its levels), one big Play button for the
## next level, then Levels, How to play and Shop. The top bar holds coins, the daily streak, the
## chef's gift and Settings. A brand-new player never sees it first: the splash goes straight into
## level 1. Back asks before quitting (Android convention).

const GIFT := preload("res://assets/deco/gift.png")
const LANTERN := preload("res://assets/deco/lantern.png")
const STREAK := preload("res://assets/deco/tea.png")

@onready var _coins: CurrencyPill = %Coins
@onready var _play: Button = %PlayButton
@onready var _logo: Control = %Logo

## Built in _ready (the _build_* functions).
var _noren: SushiNoren
var _gift: Button
var _gift_badge: Label
var _streak_badge: Label


func _ready() -> void:
	_coins.value = Progress.coins()
	var next := Progress.next_level(SushiLevels.count())
	var chapter := SushiLevels.chapter(next)
	%Title.text = ProjectSettings.get_setting("application/config/name", "Sushi Loop")
	_play.text = _play_text(next)
	_play.pressed.connect(_start.bind(next))
	%SettingsButton.pressed.connect(_on_settings)
	_build_noren(chapter)
	_build_top_bar()
	_build_mark(chapter)
	_build_card(chapter)
	_build_links()
	SushiSfx.music()
	_intro()
	# The curtain stops just below the top bar, whatever the notch and screen size.
	await get_tree().process_frame
	if is_inside_tree():
		_noren.offset_bottom = (%SettingsButton as Control).get_global_rect().end.y + 6.0


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


## "Level 15", or "Level 15 · Hard" when the next level is a hard one.
static func _play_text(level: int) -> String:
	match SushiLevels.level(level).role:
		"hard":
			return "Level %d  ·  Hard" % level
		"super":
			return "Level %d  ·  Super hard" % level
	return "Level %d" % level


func _start(level: int) -> void:
	Screens.level = level
	UI.goto(Screens.GAME)


func _on_settings() -> void:
	await UI.open(load(Screens.SETTINGS) as PackedScene).closed
	_coins.value = Progress.coins()


## The curtain hangs from the very top (under the status bar), behind the top bar.
func _build_noren(chapter: int) -> void:
	_noren = SushiNoren.new()
	_noren.color = SushiPalette.shop(chapter).noren
	_noren.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_noren.offset_bottom = 230.0
	add_child(_noren)
	move_child(_noren, 1)


## The daily streak and the chef's gift, each with a badge, between the coins and Settings.
func _build_top_bar() -> void:
	var settings: Control = %SettingsButton
	var bar := settings.get_parent()
	var streak := _picture_button(STREAK, "Daily streak")
	streak.pressed.connect(_on_streak)
	bar.add_child(streak)
	bar.move_child(streak, settings.get_index())
	_streak_badge = _badge(streak)
	_gift = _picture_button(GIFT, "Chef's gift")
	_gift.pressed.connect(_on_gift)
	bar.add_child(_gift)
	bar.move_child(_gift, settings.get_index())
	_gift_badge = _badge(_gift)
	_show_badges()


## Plates gliding along a stretch of the chapter's belt, above the game's name.
func _build_mark(chapter: int) -> void:
	var mark := SushiLogo.new()
	mark.shop = SushiPalette.shop(chapter)
	mark.custom_minimum_size = Vector2(560, 120)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(mark)
	_logo.move_child(mark, 0)
	var layout := _logo.get_parent()
	layout.add_child(_spacer(true))
	layout.move_child(layout.get_child(layout.get_child_count() - 1), _logo.get_index())


## The restaurant the player is at: a tap opens its levels.
func _build_card(chapter: int) -> void:
	var card := Button.new()
	card.theme_type_variation = &"GhostButton"
	card.custom_minimum_size.y = 150.0
	card.pressed.connect(_open_levels.bind(chapter))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TilePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	head.add_child(_picture(LANTERN, 64.0))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(words)
	words.add_child(_label(SushiMeta.chapter_name(chapter), &"ValueLabel"))
	words.add_child(_label("Chapter %d  ·  %s" % [chapter, SushiChapters.label(chapter)], &"CaptionLabel"))
	var levels := SushiMeta.chapter_range(chapter)
	var count := levels.y - levels.x + 1
	var stars := _label("%d / %d" % [SushiMeta.chapter_stars(chapter), count * 3], &"ValueLabel")
	stars.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	head.add_child(stars)
	var star := _picture(Icons.STAR, 32.0)
	star.modulate = get_theme_color(&"gold", &"Tokens")
	head.add_child(star)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = count
	bar.value = SushiMeta.chapter_won(chapter)
	bar.custom_minimum_size.y = 18.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var layout := _play.get_parent()
	layout.add_child(card)
	layout.move_child(card, _play.get_index())
	layout.add_child(_spacer(false, 18.0))
	layout.move_child(layout.get_child(layout.get_child_count() - 1), _play.get_index())


## Levels, How to play and Shop under the Play button: icon over word, a thumb's reach.
func _build_links() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	for link: Array in [["Levels", Icons.GRID, _open_levels.bind(0)], ["How to play", Icons.HELP, _open_how_to],
			["Shop", Icons.SHOP, _open_shop]]:
		var button := Button.new()
		button.text = link[0]
		button.icon = link[1]
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.y = 124.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(link[2])
		row.add_child(button)
	var layout := _play.get_parent()
	layout.add_child(row)
	layout.move_child(row, _play.get_index() + 1)
	layout.add_child(_spacer(false, 16.0))
	layout.move_child(layout.get_child(layout.get_child_count() - 1), _play.get_index() + 1)


func _open_levels(chapter: int) -> void:
	var levels_script: GDScript = load("res://ui/screens/levels.gd")
	levels_script.set(&"open_chapter", chapter)
	UI.goto(Screens.LEVELS)


func _open_how_to() -> void:
	UI.goto(Screens.HOW_TO_PLAY)


func _open_shop() -> void:
	await UI.open(load(Screens.SHOP) as PackedScene).closed
	_coins.value = Progress.coins()


func _show_badges() -> void:
	var toward := SushiMeta.gift_progress()
	_gift_badge.text = "!" if SushiMeta.gifts_ready() > 0 else "%d/%d" % [toward.x, toward.y]
	_streak_badge.text = str(int(Progress.daily_status().streak))


func _on_streak() -> void:
	var status := Progress.daily_status()
	var days := int(status.streak)
	if not status.can_claim:
		UI.toast("%d-day streak. Come back tomorrow for day %d." % [days, days + 1], Icons.CHECK, 3.0)
	elif days > 0:
		UI.toast("%d-day streak. Win a level today to keep it." % days, Icons.STAR, 3.0)
	else:
		UI.toast("Win a level every day to build a streak: up to %d coins a day." % Progress.DAILY_REWARDS[-1], Icons.STAR, 3.0)


func _on_gift() -> void:
	if SushiMeta.gifts_ready() <= 0:
		var toward := SushiMeta.gift_progress()
		UI.toast("%d more stars for the chef's gift" % (toward.y - toward.x), Icons.STAR)
		return
	var coins := SushiMeta.open_gift()
	if coins <= 0:
		return
	var card := UI.open(load(Screens.REWARD) as PackedScene)
	card.call(&"show_gift", "A gift from the chef", "%d stars collected" % (Progress.count("gifts") * SushiMeta.GIFT_EVERY),
			"Coins for hints, undos and continues.", GIFT, coins)
	await card.closed
	_coins.set_value(Progress.coins())
	_show_badges()


func _picture_button(texture: Texture2D, tip: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"IconButton"
	button.icon = texture
	button.expand_icon = true
	button.custom_minimum_size = Vector2(96, 96)
	button.add_theme_constant_override(&"icon_max_width", 60)
	# Full-colour pictures: no ink tint like the line icons.
	for state: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color", &"icon_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.tooltip_text = tip
	return button


func _badge(button: Button) -> Label:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	button.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position += Vector2(10, -10)
	return label


func _picture(texture: Texture2D, side: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(side, side)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer(expand: bool, height: float = 0.0) -> Control:
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.y = height
	if expand:
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return gap


## The mark drops in, the Play button breathes, and a waiting gift nods (off with Reduce Motion).
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
	if SushiMeta.gifts_ready() > 0:
		_gift.pivot_offset_ratio = Vector2(0.5, 0.5)
		var nod := create_tween().set_loops()
		nod.tween_interval(2.0)
		for angle: float in [0.14, -0.12, 0.08, 0.0]:
			nod.tween_property(_gift, ^"rotation", angle, 0.08)
		_gift.pressed.connect(nod.kill, CONNECT_ONE_SHOT)
