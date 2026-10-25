extends SceneTree
## Renders every screen and popup of the UI kit to PNG, in every style and screen size, so a
## person or Claude can review the UI without a phone. Run through tools/snapshots.ps1 (it needs
## a real window, not --headless). Writes the PC save file while it plays the screens.
##
## Args after `--`:
##   --sizes 720x1280,720x1600   canvas sizes (default: phones 16:9 and 20:9, a tablet, a foldable)
##   --styles all                style ids from core/ui/themes/, or "all" (default: the project's)
##   --only main_menu,pause      render only these screens (names in SCREENS)
##   --inset 0,64,0,32           fake notch and gesture bar in canvas px: left,top,right,bottom
##   --out build/snapshots       output folder, relative to the project
## Output: <style>_<w>x<h>_<screen>.png plus one <style>_<w>x<h>_contact.png sheet per size.

const SETTLE_FRAMES: int = 40
const SIZE_PRESETS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(960, 1280), Vector2i(1080, 1280)]
const SCREENS: PackedStringArray = [
	"splash", "main_menu", "level_select", "game", "pause", "results_win", "results_lose", "settings",
	"confirm", "credits", "gallery", "dish", "gift",
]

var _sizes: Array[Vector2i] = []
var _styles: Array[StringName] = []
var _insets: Vector4i = Vector4i.ZERO
var _only: PackedStringArray = []
var _out_dir: String = "build/snapshots"
var _ui: Node


func _initialize() -> void:
	_ui = root.get_node(^"UI")
	_parse_args()
	var out := ProjectSettings.globalize_path("res://").path_join(_out_dir)
	DirAccess.make_dir_recursive_absolute(out)
	_ignore_build_dir()
	_demo_progress()
	await _frames(3)
	SafeAreaMargin.set_simulated_insets(self, _insets)
	var written := 0
	for style in _styles:
		_ui.call(&"apply_style", style, false)
		for size in _sizes:
			await _resize(size)
			var shots: Array[Image] = []
			for screen in SCREENS:
				if not _only.is_empty() and not _only.has(screen):
					continue
				await _reset()
				if not await call("_show_" + screen):
					push_warning("snapshot %s: screen could not be opened" % screen)
					continue
				await _frames(SETTLE_FRAMES)
				# Maaack's start-up restores a saved desktop window size, so set ours again.
				await _resize(size)
				var image := root.get_texture().get_image()
				var file := out.path_join("%s_%dx%d_%s.png" % [style, size.x, size.y, screen])
				image.save_png(file)
				shots.append(image)
				written += 1
			if shots.size() > 1:
				var sheet := out.path_join("%s_%dx%d_contact.png" % [style, size.x, size.y])
				_contact_sheet(shots).save_png(sheet)
				print("snapshot ", sheet)
	await _reset()
	SaveStore.delete_save(Progress.path)
	print("snapshots written: ", written)
	quit(0 if written > 0 else 1)


## Realistic progress in a separate save file, so the screens show stars, locks, coins and a
## daily streak without touching the real PC save.
func _demo_progress() -> void:
	Progress.path = "user://snapshot_progress.json"
	Progress.reset()
	var earned: Array[int] = [3, 3, 2, 3, 1, 2, 3]
	for i in earned.size():
		Progress.record_win(i + 1, earned[i])
	var now := Time.get_unix_time_from_system()
	Progress.claim_daily(Time.get_date_string_from_unix_time(int(now) - 2 * 86400))
	# Every dish introduced already, so its card does not open over the game screen shots.
	Progress.set_count("dishes", (1 << SushiLevel.TYPE_COUNT) - 1)
	Progress.claim_daily(Time.get_date_string_from_unix_time(int(now) - 86400))
	Progress.add_coins(1250 - Progress.coins())


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1):
		var value := args[i + 1]
		match args[i]:
			"--sizes":
				for part in value.split(","):
					var wh := part.split("x")
					_sizes.append(Vector2i(int(wh[0]), int(wh[1])))
			"--styles":
				var ids: Array = _ui.call(&"list_styles")
				for id in (ids if value == "all" else Array(value.split(","))):
					_styles.append(StringName(id))
			"--inset":
				var n := value.split(",")
				_insets = Vector4i(int(n[0]), int(n[1]), int(n[2]), int(n[3]))
			"--only":
				_only = value.split(",")
			"--out":
				_out_dir = value
	if _sizes.is_empty():
		_sizes = SIZE_PRESETS.duplicate()
	if _styles.is_empty():
		_styles = [_ui.get(&"current_style")]


## Without build/.gdignore Godot imports the PNGs and packs them into the next APK.
func _ignore_build_dir() -> void:
	var marker := ProjectSettings.globalize_path("res://build/.gdignore")
	if not FileAccess.file_exists(marker):
		FileAccess.open(marker, FileAccess.WRITE).close()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _resize(size: Vector2i) -> void:
	for attempt in 5:
		root.size = size
		await _frames(3)
		if root.size == size:
			return
	push_warning("window could not be resized to %s" % size)


func _reset() -> void:
	paused = false
	_ui.call(&"close_all")
	var console := root.get_node_or_null(^"LimboConsole")
	if console != null and console.call(&"is_open"):
		console.call(&"close_console")


func _open(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	change_scene_to_file(path)
	await _frames(4)
	return true


func _popup(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	return _ui.call(&"open", load(path))


func _show_splash() -> bool:
	return await _open(Screens.SPLASH)


func _show_main_menu() -> bool:
	if not await _open(Screens.MAIN_MENU):
		return false
	await _frames(2)
	_ui.call(&"close_all")
	return true


func _show_level_select() -> bool:
	return await _open(Screens.LEVEL_SELECT)


func _show_game() -> bool:
	Screens.level = 3
	return await _open(Screens.GAME)


func _show_pause() -> bool:
	return await _show_game() and _popup(Screens.PAUSE) != null


func _show_results_win() -> bool:
	if not await _show_game():
		return false
	var popup := _popup(Screens.RESULTS)
	if popup == null:
		return false
	popup.call(&"show_win", 3, 2, 50, true)
	await _frames(120)
	return true


func _show_results_lose() -> bool:
	if not await _show_game():
		return false
	var popup := _popup(Screens.RESULTS)
	if popup == null:
		return false
	popup.call(&"show_lose", 3, 50, true, true)
	return true


func _show_settings() -> bool:
	return await _show_main_menu() and _popup(Screens.SETTINGS) != null





func _show_confirm() -> bool:
	if not await _show_main_menu():
		return false
	var popup := _popup(Screens.CONFIRM)
	if popup == null:
		return false
	popup.call(&"setup", "Reset progress?", "Stars and coins on this phone are deleted.", "Reset", true)
	return true


func _show_credits() -> bool:
	return await _open(Screens.CREDITS)


func _show_gallery() -> bool:
	return await _open(Screens.GALLERY)


## All shots of one style and size, a third of their size, in SCREENS order.
func _contact_sheet(shots: Array[Image]) -> Image:
	const COLUMNS := 4
	const GAP := 8
	var cell := shots[0].get_size() / 3
	var rows := ceili(shots.size() / float(COLUMNS))
	var sheet := Image.create_empty(
		COLUMNS * (cell.x + GAP) + GAP, rows * (cell.y + GAP) + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		var at := Vector2i(GAP + (i % COLUMNS) * (cell.x + GAP), GAP + (i / COLUMNS) * (cell.y + GAP))
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell), at)
	return sheet


func _show_dish() -> bool:
	if not await _show_game():
		return false
	var popup := _popup(Screens.REWARD)
	if popup == null:
		return false
	popup.call(&"show_dish", 2)
	return true


func _show_gift() -> bool:
	if not await _show_game():
		return false
	var popup := _popup(Screens.REWARD)
	if popup == null:
		return false
	popup.call(&"show_gift", "A gift from the chef", "15 stars collected", "Coins for hints, undos and continues.",
			load("res://assets/deco/gift.png"), 100)
	await _frames(90)
	return true
