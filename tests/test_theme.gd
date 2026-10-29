extends GutTest
## Checks every built theme in core/ui/themes/: text contrast (WCAG 2.2 AA) and 48 dp touch
## targets. Runs after every theme rebuild, so a new colour that fails is caught at once.
## Rules: 4.5:1 for normal text, 3:1 for large text (48 canvas px = 24 dp and up). Text with
## a thick outline (3 px or more) is measured against its outline, per WCAG's halo note.

const THEMES_DIR := "res://core/ui/themes/"
const STYLES_DIR := "res://core/ui/styles/"
const TOUCH := 96.0

var _themes: Dictionary[String, Theme] = {}


func before_all() -> void:
	for file in ResourceLoader.list_directory(THEMES_DIR):
		if file.ends_with(".tres"):
			_themes[file.get_basename()] = load(THEMES_DIR + file) as Theme


## Sushi Loop has one style, its own; it must have a built theme.
func test_every_style_is_built() -> void:
	var styles: Array[String] = []
	for file in ResourceLoader.list_directory(STYLES_DIR):
		if file.ends_with(".tres"):
			styles.append(file.get_basename())
	assert_eq(styles, ["sushi"] as Array[String], "the game's own style only, in %s" % STYLES_DIR)
	for id in styles:
		assert_true(_themes.has(id), "style %s has no built theme in %s (run tools/build_theme.gd)" % [id, THEMES_DIR])
	assert_eq(_themes.size(), styles.size(), "themes %s vs styles %s" % [_themes.keys(), styles])


func test_tokens_exist() -> void:
	for id in _themes:
		for token in [&"bg_top", &"bg_bottom", &"surface", &"text", &"text_muted", &"accent", &"on_accent", &"gold", &"scrim"]:
			assert_true(_themes[id].has_color(token, &"Tokens"), "%s: missing Tokens colour %s" % [id, token])
		assert_eq(_themes[id].get_constant(&"touch_target", &"Tokens"), int(TOUCH), "%s: touch_target" % id)


func test_text_on_cards_is_readable() -> void:
	for id in _themes:
		var t := _themes[id]
		var surface := _token(t, &"surface")
		_check(id, "body text on cards", t.get_color(&"font_color", &"Label"), surface, 32)
		_check(id, "caption on cards", t.get_color(&"font_color", &"CaptionLabel"), surface, t.get_font_size(&"font_size", &"CaptionLabel"))
		_check(id, "header on cards", t.get_color(&"font_color", &"HeaderLabel"), surface, t.get_font_size(&"font_size", &"HeaderLabel"))
		_check(id, "numbers on cards", t.get_color(&"font_color", &"ValueLabel"), surface, t.get_font_size(&"font_size", &"ValueLabel"))


func test_text_on_background_is_readable() -> void:
	for id in _themes:
		var t := _themes[id]
		for type: StringName in [&"OnBgLabel", &"TitleLabel", &"ScreenHeaderLabel"]:
			for bg_token in [&"bg_top", &"bg_bottom"]:
				_check_label(id, t, type, _token(t, bg_token), String(bg_token))


func test_button_text_is_readable() -> void:
	for id in _themes:
		var t := _themes[id]
		for type: StringName in [&"Button", &"AccentButton", &"HeroButton", &"DangerButton", &"IconButton", &"TileButton", &"AccentTileButton"]:
			for state in [[&"normal", &"font_color"], [&"pressed", &"font_pressed_color"]]:
				var box := t.get_stylebox(state[0], type) as StyleBoxFlat
				if box == null:
					continue
				# A button may sit on a card or straight on the background; check both.
				for base_token in [&"surface", &"bg_bottom"]:
					var face := _over(box.bg_color, _token(t, base_token))
					var text := t.get_color(state[1], type)
					var size := t.get_font_size(&"font_size", type)
					_check_outlined(id, "%s %s on %s" % [type, state[0], base_token], text, face, size,
						t.get_constant(&"outline_size", type), t.get_color(&"font_outline_color", type))


func test_buttons_are_touch_sized() -> void:
	for id in _themes:
		for type: StringName in [&"Button", &"AccentButton", &"HeroButton", &"DangerButton", &"GhostButton", &"IconButton", &"AccentIconButton", &"TileButton", &"ChipButton"]:
			var button := Button.new()
			button.theme = _themes[id]
			button.theme_type_variation = type
			button.text = "Play"
			if type.contains("Icon"):
				button.text = ""
				button.icon = Icons.PLAY
			add_child_autofree(button)
			var size := button.get_combined_minimum_size()
			assert_gte(size.y, TOUCH - 0.5, "%s: %s is %.1f px tall" % [id, type, size.y])
			if type.contains("Icon"):
				assert_gte(size.x, TOUCH - 0.5, "%s: %s is %.1f px wide" % [id, type, size.x])


func test_toggles_and_sliders_are_touch_sized() -> void:
	for id in _themes:
		var toggle := CheckButton.new()
		toggle.theme = _themes[id]
		add_child_autofree(toggle)
		var toggle_size := toggle.get_combined_minimum_size()
		assert_gte(toggle_size.y, TOUCH - 0.5, "%s: switch height %.1f" % [id, toggle_size.y])
		assert_gte(toggle_size.x, TOUCH - 0.5, "%s: switch width %.1f" % [id, toggle_size.x])
		var slider := HSlider.new()
		slider.theme = _themes[id]
		add_child_autofree(slider)
		assert_gte(slider.get_combined_minimum_size().y, TOUCH - 0.5, "%s: slider height" % id)


func test_contrast_formula_matches_wcag_examples() -> void:
	assert_almost_eq(contrast(Color.BLACK, Color.WHITE), 21.0, 0.01)
	assert_almost_eq(contrast(Color("#777777"), Color.WHITE), 4.48, 0.01)
	assert_almost_eq(contrast(Color.WHITE, Color.WHITE), 1.0, 0.001)


# --- helpers -----------------------------------------------------------------------------

static func luminance(c: Color) -> float:
	var channel := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channel.call(c.r) + 0.7152 * channel.call(c.g) + 0.0722 * channel.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _token(t: Theme, name: StringName) -> Color:
	return t.get_color(name, &"Tokens")


## `top` drawn over an opaque `base`.
func _over(top: Color, base: Color) -> Color:
	return Color(base.lerp(Color(top, 1.0), top.a), 1.0)


func _needed(font_size: int) -> float:
	return 3.0 if font_size >= 48 else 4.5


func _check(id: String, what: String, text: Color, background: Color, font_size: int) -> void:
	var ratio := contrast(text, background)
	assert_gte(ratio, _needed(font_size), "%s: %s contrast %.2f (needs %.1f)" % [id, what, ratio, _needed(font_size)])


func _check_label(id: String, t: Theme, type: StringName, background: Color, where: String) -> void:
	_check_outlined(id, "%s on %s" % [type, where], t.get_color(&"font_color", type), background,
		t.get_font_size(&"font_size", type), t.get_constant(&"outline_size", type), t.get_color(&"font_outline_color", type))


func _check_outlined(id: String, what: String, text: Color, background: Color, font_size: int, outline: int, outline_color: Color) -> void:
	if outline >= 3 and outline_color.a >= 0.99:
		_check(id, what + " (against its outline)", text, outline_color, font_size)
	else:
		_check(id, what, text, background, font_size)
