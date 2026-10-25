extends Screen
## Level select: one section per chapter (a strip in the restaurant's noren colour with its name
## and stars, then its tiles: best stars, locks, "Hard" and "Super hard" badges), 4 columns on
## phones and up to 6 on tablets. The next level to play is highlighted and scrolled into view.
## Tap to play. The scene's %Grid is the template each chapter's grid is copied from.

@export var level_count: int = Progress.LEVEL_COUNT_DEFAULT

const LANTERN := preload("res://assets/deco/lantern.png")


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%Stars.value = Progress.total_stars()
	level_count = mini(level_count, SushiLevels.count())
	var next := Progress.next_level(level_count)
	var next_tile: LevelTile = null
	var template: Container = %Grid
	var scroll: ScrollContainer = %Scroll
	scroll.remove_child(template)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 18)
	scroll.add_child(column)
	for chapter in range(1, SushiMeta.chapter_count() + 1):
		var levels := SushiMeta.chapter_range(chapter)
		if levels.x > level_count:
			break
		column.add_child(_header(chapter, Progress.is_unlocked(levels.x)))
		var grid := template.duplicate() as Container
		grid.unique_name_in_owner = false
		column.add_child(grid)
		for level in range(levels.x, mini(levels.y, level_count) + 1):
			var tile := LevelTile.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(tile)
			tile.level = level
			tile.stars = Progress.stars(level)
			tile.locked = not Progress.is_unlocked(level)
			tile.current = level == next
			tile.pressed.connect(_play.bind(level))
			_add_role_badge(tile, SushiLevels.level(level).role)
			if level == next:
				next_tile = tile
	template.free()
	if next_tile != null:
		await get_tree().process_frame
		scroll.ensure_control_visible(next_tile)


func _play(level: int) -> void:
	Screens.level = level
	UI.goto(Screens.GAME)


## The chapter's strip: lantern, name and stars on the noren colour.
func _header(chapter: int, open: bool) -> PanelContainer:
	var shop := SushiPalette.shop(chapter)
	var strip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = shop.noren if open else Color(shop.noren, 0.45)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	strip.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	strip.add_child(row)
	var lantern := TextureRect.new()
	lantern.texture = LANTERN if open else Icons.LOCK
	lantern.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lantern.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lantern.custom_minimum_size = Vector2(48, 48)
	lantern.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not open:
		lantern.modulate = SushiPalette.CREAM
	row.add_child(lantern)
	var name_label := Label.new()
	name_label.text = "%d · %s" % [chapter, SushiMeta.chapter_name(chapter)]
	name_label.theme_type_variation = &"ValueLabel"
	name_label.add_theme_color_override(&"font_color", SushiPalette.CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var levels := SushiMeta.chapter_range(chapter)
	var stars := Label.new()
	stars.text = "%d / %d" % [SushiMeta.chapter_stars(chapter), (levels.y - levels.x + 1) * 3]
	stars.theme_type_variation = &"ValueLabel"
	stars.add_theme_color_override(&"font_color", SushiPalette.CREAM)
	stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(stars)
	var star := TextureRect.new()
	star.texture = Icons.STAR
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(30, 30)
	star.modulate = SushiPalette.GOLD
	row.add_child(star)
	return strip


## A small "Hard" or "Super" badge in the tile's top corner (the sawtooth, visible ahead).
func _add_role_badge(tile: LevelTile, role: String) -> void:
	if role != "hard" and role != "super":
		return
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.text = "Hard" if role == "hard" else "Super hard"
	badge.add_child(label)
	tile.add_child(badge)
	# Centred on the tile's top edge, like a ribbon (placed again whenever the grid sizes the tile).
	var place := func() -> void:
		badge.reset_size()
		badge.position = Vector2((tile.size.x - badge.size.x) * 0.5, -badge.size.y * 0.45)
	tile.resized.connect(place)
	place.call_deferred()
