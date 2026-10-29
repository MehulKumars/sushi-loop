extends GutTest
## Every screen and popup at a 16:9 phone, a tall 20:9 phone and a 3:4 tablet: each tappable
## control is at least 96 px (48 dp) in both directions, sits inside the screen (unless it is
## in a scroll area), and does not overlap another tappable control. The game screen is also
## checked with its doom card up (step back, retry, keep going).
## Popups pause the game, so this test waits with timers that keep running while paused.

const TOUCH := 96.0
const SIZES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(960, 1280)]
const PAGES: Array[String] = [
	Screens.SPLASH, Screens.MAIN_MENU, Screens.LEVEL_SELECT, Screens.GAME, Screens.CREDITS,
	Screens.PAUSE, Screens.RESULTS, Screens.SETTINGS, Screens.CONFIRM,
]


func before_all() -> void:
	Progress.path = "user://test_screens_progress.json"
	Progress.reset()
	for level in range(1, 6):
		Progress.record_win(level, 1 + level % 3)


func after_all() -> void:
	UI.close_all()
	Progress.reset()
	Progress.path = SaveStore.DEFAULT_PATH
	Progress.load_from_disk()


func test_every_page_fits_every_size() -> void:
	for size in SIZES:
		for path in PAGES:
			var problems := await _layout_problems(path, size)
			assert_eq(problems, [] as Array[String], "%s at %dx%d" % [path.get_file(), size.x, size.y])


func test_level_select_shows_every_level() -> void:
	var viewport := _viewport(Vector2i(720, 1280))
	var page := (load(Screens.LEVEL_SELECT) as PackedScene).instantiate()
	viewport.add_child(page)
	await _settle()
	var tiles := page.find_children("*", "LevelTile", true, false)
	assert_eq(tiles.size(), Progress.LEVEL_COUNT_DEFAULT)
	var unlocked := tiles.filter(func(tile: Node) -> bool: return not (tile as LevelTile).locked)
	assert_eq(unlocked.size(), 6, "five won levels plus the next one")
	viewport.free()


func test_the_doom_card_offers_step_back_retry_and_keep_going_at_every_size() -> void:
	for size in SIZES:
		var problems := await _layout_problems(Screens.GAME, size, true)
		assert_eq(problems, [] as Array[String], "doom card at %dx%d" % [size.x, size.y])
	var viewport := _viewport(Vector2i(720, 1280))
	var page := (load(Screens.GAME) as PackedScene).instantiate()
	viewport.add_child(page)
	(page.get_node(^"%SushiBoard") as SushiBoardView).doomed.emit()
	await _settle()
	var shown: Array[String] = []
	for node in page.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree():
			shown.append((node as Button).text)
	for text in ["Step back", "Retry", "Keep going"]:
		assert_has(shown, text)
	viewport.free()


func _layout_problems(path: String, size: Vector2i, doom: bool = false) -> Array[String]:
	var viewport := _viewport(size)
	var page := (load(path) as PackedScene).instantiate()
	viewport.add_child(page)
	if path == Screens.RESULTS:
		page.call(&"show_win", 3, 2, 20)
	if path == Screens.CONFIRM:
		page.call(&"setup", "Reset progress?", "Stars and coins on this phone are deleted.", "Reset", true)
	if doom:
		(page.get_node(^"%SushiBoard") as SushiBoardView).doomed.emit()
	await _settle()
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var tappable: Array[Control] = []
	for node in page.find_children("*", "Control", true, false):
		var control := node as Control
		# Scroll bars are thin indicators; on a phone you drag the content itself.
		if (control is BaseButton or control is Range) and control.is_visible_in_tree() and not (control is ProgressBar or control is ScrollBar):
			tappable.append(control)
	for control in tappable:
		var name := String(page.get_path_to(control))
		if control.size.y < TOUCH - 0.5 or control.size.x < TOUCH - 0.5:
			problems.append("%s is %.0fx%.0f px, under 96" % [name, control.size.x, control.size.y])
		if not _in_scroll(control) and not screen.grow(1.0).encloses(control.get_global_rect()):
			problems.append("%s is off screen at %s" % [name, control.get_global_rect()])
	for i in tappable.size():
		for j in range(i + 1, tappable.size()):
			var overlap := tappable[i].get_global_rect().intersection(tappable[j].get_global_rect())
			if overlap.get_area() > 1.0 and not tappable[i].is_ancestor_of(tappable[j]) and not tappable[j].is_ancestor_of(tappable[i]):
				problems.append("%s overlaps %s" % [page.get_path_to(tappable[i]), page.get_path_to(tappable[j])])
	viewport.free()
	UI.close_all()
	return problems


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	add_child(viewport)
	return viewport


## Layout plus popup open animations (about 0.3 s), with a timer that runs while paused.
func _settle() -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout


func _in_scroll(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func test_credits_carry_licences_and_no_tappable_links() -> void:
	var viewport := _viewport(Vector2i(720, 1280))
	var page := (load(Screens.CREDITS) as PackedScene).instantiate()
	viewport.add_child(page)
	await _settle()
	var label := page.get_node(^"%CreditsText") as RichTextLabel
	var text := label.get_parsed_text()
	assert_string_contains(text, "Permission is hereby granted", "MIT notices are shown")
	assert_string_contains(text, "Godot Engine")
	assert_false(label.text.contains("[url"), "links are plain text so a tap never opens a browser")
	viewport.free()
