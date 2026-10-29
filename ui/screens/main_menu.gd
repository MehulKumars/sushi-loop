extends Screen
## Home: the restaurant of the current chapter (its noren curtain, name and twist, arrows to look
## back at earlier chapters), the chapter's levels as a road of plates (SushiLevelRoad: replay a
## won level with a tap), a gift button in the top bar (stars to the next star gift, or "!" when
## one waits), and one big Play button for the next level in the thumb zone. A brand-new player
## never sees it first: the splash goes straight into level 1. Back asks before quitting.

const GIFT := preload("res://assets/deco/gift.png")

@onready var _coins: CurrencyPill = %Coins
@onready var _title: Label = %Title
@onready var _caption: Label = %Tagline
@onready var _play: Button = %PlayButton

## Built in _ready (the _build_* functions).
var _road: SushiLevelRoad
var _noren: SushiNoren
var _prev: Button
var _next: Button
var _gift: Button
var _gift_badge: Label
## The chapter on show (the arrows browse back to chapter 1 and up to the next level's chapter).
var _chapter: int = 1


func _ready() -> void:
	_coins.value = Progress.coins()
	var next := _next_level()
	_chapter = SushiLevels.chapter(next)
	_play.text = _play_text(next)
	_play.pressed.connect(_start.bind(next))
	%SettingsButton.pressed.connect(_on_settings)
	_build_noren()
	_build_header()
	_build_road()
	_build_gift_button()
	_show_chapter(_chapter)
	SushiSfx.music()
	_intro()
	# The curtain stops just below the top bar, whatever the notch and screen size.
	await get_tree().process_frame
	if is_inside_tree():
		_noren.offset_bottom = (%SettingsButton as Control).get_global_rect().end.y + 6.0


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


static func _next_level() -> int:
	return Progress.next_level(SushiLevels.count())


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


func _show_chapter(chapter: int) -> void:
	_chapter = clampi(chapter, 1, SushiLevels.chapter(_next_level()))
	_title.text = SushiMeta.chapter_name(_chapter)
	_caption.text = "Chapter %d  ·  %s" % [_chapter, SushiChapters.label(_chapter)]
	_noren.color = SushiPalette.shop(_chapter).noren
	_prev.disabled = _chapter <= 1
	_next.disabled = _chapter >= SushiLevels.chapter(_next_level())
	_road.show_chapter(_chapter)


## The curtain hangs from the very top (under the status bar), behind the top bar.
func _build_noren() -> void:
	_noren = SushiNoren.new()
	_noren.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_noren.offset_bottom = 230.0
	add_child(_noren)
	move_child(_noren, 1)


## The restaurant's name and twist between two arrows that page through the chapters.
func _build_header() -> void:
	var logo: Control = %Logo
	var layout := logo.get_parent()
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	layout.add_child(header)
	layout.move_child(header, logo.get_index())
	logo.reparent(header)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.theme_type_variation = &"ScreenHeaderLabel"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prev = Button.new()
	_next = Button.new()
	for pair: Array in [[_prev, Icons.ARROW_BACK, -1, "Earlier chapter"], [_next, Icons.ARROW_FORWARD, 1, "Later chapter"]]:
		var button: Button = pair[0]
		button.theme_type_variation = &"IconButton"
		button.icon = pair[1]
		button.tooltip_text = pair[3]
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func() -> void: _show_chapter(_chapter + int(pair[2])))
		header.add_child(button)
	header.move_child(_prev, 0)


func _build_road() -> void:
	var layout := _play.get_parent()
	_road = SushiLevelRoad.new()
	_road.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road.custom_minimum_size = Vector2(0, 560)
	layout.add_child(_road)
	layout.move_child(_road, _play.get_index())
	_road.chosen.connect(_start)
	_road.locked.connect(func(_level: int) -> void: UI.toast("Win level %d first" % _next_level(), Icons.LOCK))


## The chef's gift in the top bar, next to Settings: its badge counts stars to the next gift.
func _build_gift_button() -> void:
	_gift = Button.new()
	_gift.theme_type_variation = &"IconButton"
	_gift.icon = GIFT
	_gift.expand_icon = true
	_gift.custom_minimum_size = Vector2(96, 96)
	_gift.add_theme_constant_override(&"icon_max_width", 60)
	# The gift is a full-colour picture: no ink tint like the line icons.
	for state: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color", &"icon_focus_color"]:
		_gift.add_theme_color_override(state, Color.WHITE)
	_gift.tooltip_text = "Chef's gift"
	_gift.pressed.connect(_on_gift)
	var settings: Control = %SettingsButton
	settings.get_parent().add_child(_gift)
	settings.get_parent().move_child(_gift, settings.get_index())
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gift_badge = Label.new()
	_gift_badge.theme_type_variation = &"BadgeLabel"
	_gift_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(_gift_badge)
	_gift.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position += Vector2(10, -10)
	_show_gift_progress()


func _show_gift_progress() -> void:
	var toward := SushiMeta.gift_progress()
	_gift_badge.text = "!" if SushiMeta.gifts_ready() > 0 else "%d/%d" % [toward.x, toward.y]


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
	_show_gift_progress()


## The plates pop in from the bottom, then the Play button breathes gently (off with Reduce Motion).
func _intro() -> void:
	if Juice.motion_scale <= 0.0:
		return
	var delay := 0.0
	for plate in _road.get_children():
		var control := plate as Control
		control.scale = Vector2.ONE * 0.6
		control.modulate.a = 0.0
		var pop := create_tween().set_parallel()
		pop.tween_property(control, ^"scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(control, ^"modulate:a", 1.0, 0.18).set_delay(delay)
		delay += 0.035
	_play.pivot_offset_ratio = Vector2(0.5, 0.5)
	var breathe := create_tween().set_loops()
	breathe.tween_interval(1.2)
	breathe.tween_property(_play, ^"scale", Vector2.ONE * (1.0 + 0.035 * Juice.motion_scale), 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_play, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_play.button_down.connect(breathe.kill, CONNECT_ONE_SHOT)
	if SushiMeta.gifts_ready() > 0:
		# A waiting gift nods now and then.
		_gift.pivot_offset_ratio = Vector2(0.5, 0.5)
		var nod := create_tween().set_loops()
		nod.tween_interval(2.0)
		for angle: float in [0.14, -0.12, 0.08, 0.0]:
			nod.tween_property(_gift, ^"rotation", angle, 0.08)
		_gift.pressed.connect(nod.kill, CONNECT_ONE_SHOT)
