extends Screen
## Home screen: the shop's noren curtain in the current chapter's colour, plates gliding along a
## stretch of belt, the title, a card with the chapter's progress and the stars to the next gift,
## then the big Play button and Levels in the thumb zone. Play starts the next level not yet won.
## Back asks before quitting (Android convention). No shop, daily reward or ranks.

const LANTERN := preload("res://assets/deco/lantern.png")
const GIFT := preload("res://assets/deco/gift.png")

@onready var _coins: CurrencyPill = %Coins
@onready var _title: Label = %Title
@onready var _logo: Control = %Logo
@onready var _play: Button = %PlayButton


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Mobile Game")
	_coins.value = Progress.coins()
	var next := Progress.next_level(SushiLevels.count())
	var chapter := SushiLevels.chapter(next)
	_play.text = "Play  Level %d" % next
	_play.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_on_settings)
	%LevelsButton.pressed.connect(UI.goto.bind(Screens.LEVEL_SELECT))
	_build_noren(chapter)
	_build_mark(chapter)
	_build_progress(chapter)
	SushiSfx.music()
	_intro()


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


func _on_play() -> void:
	Screens.level = Progress.next_level(SushiLevels.count())
	UI.goto(Screens.GAME)


func _on_settings() -> void:
	await UI.open(load(Screens.SETTINGS) as PackedScene).closed
	_coins.value = Progress.coins()


## The curtain hangs from the very top (under the status bar), behind the top bar.
func _build_noren(chapter: int) -> void:
	var noren := SushiNoren.new()
	noren.color = SushiPalette.shop(chapter).noren
	noren.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	noren.offset_bottom = 230.0
	add_child(noren)
	move_child(noren, 1)


## Plates gliding along a stretch of the chapter's belt, above the title.
func _build_mark(chapter: int) -> void:
	var mark := SushiLogo.new()
	mark.shop = SushiPalette.shop(chapter)
	mark.custom_minimum_size = Vector2(560, 120)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(mark)
	_logo.move_child(mark, 0)


## The chapter card: where the player is (restaurant, levels won) and what comes next (a gift).
func _build_progress(chapter: int) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"TilePanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	var levels := SushiMeta.chapter_range(chapter)
	var won := SushiMeta.chapter_won(chapter)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	box.add_child(head)
	head.add_child(_picture(LANTERN, 64.0))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	head.add_child(words)
	words.add_child(_label(SushiMeta.chapter_name(chapter), &"ValueLabel"))
	words.add_child(_label("Chapter %d  ·  %d of %d levels" % [chapter, won, levels.y - levels.x + 1], &"CaptionLabel"))
	var stars := _label("%d / %d" % [SushiMeta.chapter_stars(chapter), (levels.y - levels.x + 1) * 3], &"ValueLabel")
	head.add_child(stars)
	var star_icon := _picture(Icons.STAR, 32.0)
	star_icon.modulate = get_theme_color(&"gold", &"Tokens")
	head.add_child(star_icon)
	box.add_child(_bar(won, levels.y - levels.x + 1))
	var gift := HBoxContainer.new()
	gift.add_theme_constant_override(&"separation", 14)
	box.add_child(gift)
	gift.add_child(_picture(GIFT, 44.0))
	var line := _label("", &"CaptionLabel")
	gift.add_child(line)
	var gift_bar := _bar(0, 1)
	gift_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gift.add_child(gift_bar)
	var open := Button.new()
	open.text = "Open"
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift.add_child(open)
	open.pressed.connect(_open_gift.bind(line, gift_bar, open))
	_show_gift_progress(line, gift_bar, open)
	var layout := _play.get_parent()
	layout.add_child(card)
	layout.move_child(card, _play.get_index())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(gap)
	layout.move_child(gap, _play.get_index())


## Stars towards the next gift, or an Open button while one is waiting.
func _show_gift_progress(line: Label, bar: ProgressBar, open: Button) -> void:
	var waiting := SushiMeta.gifts_ready() > 0
	var toward := SushiMeta.gift_progress()
	line.text = "A gift is waiting!" if waiting else "Next gift  %d / %d stars" % [toward.x, toward.y]
	bar.max_value = toward.y
	bar.value = toward.x
	bar.visible = not waiting
	open.visible = waiting


func _open_gift(line: Label, bar: ProgressBar, open: Button) -> void:
	var coins := SushiMeta.open_gift()
	if coins <= 0:
		return
	var card := UI.open(load(Screens.REWARD) as PackedScene)
	card.call(&"show_gift", "A gift from the chef", "%d stars collected" % (Progress.count("gifts") * SushiMeta.GIFT_EVERY),
			"Coins for hints, undos and continues.", GIFT, coins)
	await card.closed
	_coins.set_value(Progress.coins())
	_show_gift_progress(line, bar, open)


func _picture(texture: Texture2D, side: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(side, side)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return picture


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _bar(value: int, total: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(total, 1)
	bar.value = value
	bar.custom_minimum_size.y = 18.0
	return bar


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
