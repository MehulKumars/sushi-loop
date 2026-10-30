extends Screen
## Levels: every chapter as a row (its restaurant, twist and stars, or a lock), and the open row's
## ten levels as tiles; one chapter is open at a time, the next level's at first, scrolled into
## view. A won level or the next one plays on a tap. Reached from home; Back goes home.

## The chapter to open first (0 = the next level's chapter). Set it before UI.goto(Screens.LEVELS).
static var open_chapter: int = 0

var _rows: Array[PanelContainer] = []
var _grid: HFlowContainer = null
var _open: int = 0
var _reached: int = 1


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	var next := Progress.next_level(SushiLevels.count())
	_reached = SushiLevels.chapter(next)
	for chapter in range(1, SushiMeta.chapter_count() + 1):
		var row := _row(chapter)
		%List.add_child(row)
		_rows.append(row)
	var first := open_chapter if open_chapter > 0 else _reached
	open_chapter = 0
	_toggle(first)
	await get_tree().process_frame
	if is_inside_tree():
		(%Scroll as ScrollContainer).ensure_control_visible(_rows[first - 1])


## A chapter's row: a full-width button with the restaurant's colour, name, twist and stars.
func _row(chapter: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"TilePanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	row.add_child(box)
	var head := Button.new()
	head.theme_type_variation = &"GhostButton"
	head.custom_minimum_size.y = 104.0
	head.pressed.connect(_toggle.bind(chapter))
	box.add_child(head)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 16)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12.0
	line.offset_right = -12.0
	head.add_child(line)
	var swatch := ColorRect.new()
	swatch.color = SushiPalette.shop(chapter).noren
	swatch.custom_minimum_size = Vector2(14, 64)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(swatch)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override(&"separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	words.add_child(_label(SushiMeta.chapter_name(chapter), &"ValueLabel"))
	words.add_child(_label("Chapter %d  ·  %s" % [chapter, SushiChapters.label(chapter)], &"CaptionLabel"))
	var locked := chapter > _reached
	var right := _label("" if locked else "%d / %d" % [SushiMeta.chapter_stars(chapter), SushiLevels.CHAPTER * 3], &"ValueLabel")
	right.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	line.add_child(right)
	var icon := TextureRect.new()
	icon.texture = Icons.LOCK if locked else Icons.STAR
	icon.modulate = get_theme_color(&"text_muted" if locked else &"gold", &"Tokens")
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	if locked:
		row.modulate.a = 0.6
	return row


## Opens `chapter`'s tiles (closing the open one); a second tap closes it. A locked chapter says so.
func _toggle(chapter: int) -> void:
	if chapter > _reached:
		UI.toast("Win the levels before it first", Icons.LOCK)
		return
	if _grid != null:
		_grid.queue_free()
		_grid = null
	if _open == chapter:
		_open = 0
		return
	_open = chapter
	# Tiles flow to the width there is: five a row on a wide phone, fewer on a narrow one.
	_grid = HFlowContainer.new()
	_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	var next := Progress.next_level(SushiLevels.count())
	var levels := SushiMeta.chapter_range(chapter)
	for id in range(levels.x, levels.y + 1):
		var tile := LevelTile.new()
		tile.level = id
		tile.stars = Progress.stars(id)
		tile.locked = id > next
		tile.current = id == next
		tile.custom_minimum_size.x = 104.0
		tile.pressed.connect(_play.bind(id))
		_grid.add_child(tile)
	_rows[chapter - 1].get_child(0).add_child(_grid)


func _play(level: int) -> void:
	if level > Progress.next_level(SushiLevels.count()):
		UI.toast("Win level %d first" % Progress.next_level(SushiLevels.count()), Icons.LOCK)
		return
	Screens.level = level
	UI.goto(Screens.GAME)


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
