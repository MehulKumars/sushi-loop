extends Node
## UI services for every screen (autoload "UI").
## - goto(path): change screen with a short fade.     - open(scene): show a popup (Modal).
## - confirm(...): yes/no popup you can await.        - toast(text): short message at the bottom.
## - apply_style(id): switch the visual style (core/ui/themes/<id>.tres) for the whole app.
## Every button also gets press feedback (a small squash and a haptic tick, following Reduce
## Motion and Haptics), and focus rings only show after keyboard or gamepad input.
## Android Back arrives as ui_cancel: it closes the top popup; with no popup open the current
## screen's _unhandled_input gets it (go back, pause, or ask to quit).

signal style_changed(id: StringName)

const THEMES_DIR: String = "res://core/ui/themes/"
const CONFIRM_SCENE: String = "res://ui/popups/confirm_popup.tscn"
const CONFIG_SECTION: String = "UI"
const CONFIG_STYLE: String = "Style"
const PRESS_SCALE: float = 0.95
const FADE_SECONDS: float = 0.16

## True after keyboard or gamepad input, false after touch or mouse input.
var navigating: bool = false
## Id of the style in use (file name in core/ui/themes/ without .tres).
var current_style: StringName = &""

var _modals: Array[Modal] = []
var _modal_layer := CanvasLayer.new()
var _toast_layer := CanvasLayer.new()
var _fade_layer := CanvasLayer.new()
var _fade := ColorRect.new()
var _changing_scene: bool = false
var _press_tweens: Dictionary[int, Tween] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_layer.layer = 50
	_toast_layer.layer = 60
	_fade_layer.layer = 100
	add_child(_modal_layer)
	add_child(_toast_layer)
	add_child(_fade_layer)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade_layer.add_child(_fade)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	current_style = _style_from_project_theme()
	var saved: String = PlayerConfig.get_config(CONFIG_SECTION, CONFIG_STYLE, "")
	if not saved.is_empty() and StringName(saved) != current_style and has_style(StringName(saved)):
		apply_style(StringName(saved), false)


# --- Screens and popups ------------------------------------------------------------------

## Changes to another screen with a short fade. Closes popups and unpauses the game first.
func goto(path: String) -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = get_theme_color_safe(&"bg_bottom")
	await _fade_to(1.0)
	close_all()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing_scene = false


## Shows a popup scene whose root is a Modal. Await `.closed` for its result.
func open(scene: PackedScene) -> Modal:
	var modal := scene.instantiate() as Modal
	assert(modal != null, "UI.open() needs a scene whose root script extends Modal")
	_modal_layer.add_child(modal)
	_modals.append(modal)
	modal.tree_exited.connect(func() -> void: _modals.erase(modal))
	return modal


## Yes/no question. Returns true if the player confirmed.
func confirm(title: String, message: String, confirm_text: String = "OK", destructive: bool = false) -> bool:
	var popup := open(load(CONFIRM_SCENE) as PackedScene)
	popup.call(&"setup", title, message, confirm_text, destructive)
	var result: Variant = await popup.closed
	return result == true


## Short message at the top of the screen, for example "+50 coins". It sits under the top bar,
## away from the thumb zone, so it never covers the buttons the player is about to tap.
func toast(text: String, icon: Texture2D = null, seconds: float = 2.2) -> void:
	for old in _toast_layer.get_children():
		old.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	panel.add_child(row)
	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.custom_minimum_size = Vector2(44, 44)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.modulate = get_theme_color_safe(&"gold")
		row.add_child(image)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_toast_layer.add_child(panel)
	# A long message wraps inside the screen's margins instead of running off both edges.
	var view := panel.get_viewport_rect().size
	var room := view.x - 2.0 * panel.get_theme_constant(&"screen_margin", &"Tokens") \
			- panel.get_theme_stylebox(&"panel").get_minimum_size().x - (60.0 if icon != null else 0.0)
	var font := label.get_theme_font(&"font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
	if width > room:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = room
	await get_tree().process_frame
	var top := SafeAreaMargin.get_insets(panel.get_viewport()).y
	panel.position = Vector2((view.x - panel.size.x) / 2.0, top + 150.0)
	panel.modulate.a = 0.0
	var rest_y := panel.position.y
	panel.position.y -= 40.0 * Juice.motion_scale
	var tween := panel.create_tween()
	tween.tween_property(panel, ^"modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(panel, ^"position:y", rest_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(seconds)
	tween.tween_property(panel, ^"modulate:a", 0.0, 0.25)
	tween.tween_callback(panel.queue_free)


func has_modal() -> bool:
	return not _modals.is_empty()


## The popup on top, or null.
func top_modal() -> Modal:
	return null if _modals.is_empty() else _modals.back()


## Removes every popup at once (no animation). Popups that paused the game unpause it.
func close_all() -> void:
	for modal in _modals.duplicate():
		if is_instance_valid(modal):
			modal.get_parent().remove_child(modal)
			modal.queue_free()
	_modals.clear()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", alpha, FADE_SECONDS)
	await tween.finished


# --- Styles ------------------------------------------------------------------------------

## Ids of the styles in core/ui/themes/, for example &"sleek_dark".
func list_styles() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file in ResourceLoader.list_directory(THEMES_DIR):
		if file.ends_with(".tres"):
			ids.append(StringName(file.get_basename()))
	# StringName.sort() orders by internal id, not alphabetically.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func has_style(id: StringName) -> bool:
	return ResourceLoader.exists(THEMES_DIR + String(id) + ".tres")


## Switches every screen to another style. The game's default is the project theme
## (Project Settings > GUI > Theme > Custom); `remember` keeps the choice for next launch.
func apply_style(id: StringName, remember: bool = true) -> void:
	# A fresh copy: the cached one may be the project theme itself, which is cleared below.
	var theme := ResourceLoader.load(THEMES_DIR + String(id) + ".tres", "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	if theme == null:
		push_warning("UI.apply_style: no theme for style '%s'" % id)
		return
	var project := ThemeDB.get_project_theme()
	if project == null:
		push_warning("UI.apply_style: set Project Settings > GUI > Theme > Custom first")
		return
	project.clear()
	project.merge_with(theme)
	project.default_font = theme.default_font
	project.default_font_size = theme.default_font_size
	current_style = id
	if remember:
		PlayerConfig.set_config(CONFIG_SECTION, CONFIG_STYLE, String(id))
	style_changed.emit(id)


## A Tokens colour from the active style, usable from code that is not a Control.
func get_theme_color_safe(token: StringName) -> Color:
	var project := ThemeDB.get_project_theme()
	if project != null and project.has_color(token, &"Tokens"):
		return project.get_color(token, &"Tokens")
	return Color.BLACK


func _style_from_project_theme() -> StringName:
	var path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	return StringName(path.get_file().get_basename()) if path.begins_with(THEMES_DIR) else &""


# --- Input: Back, focus rings, button feedback --------------------------------------------

func _input(event: InputEvent) -> void:
	_track_input_mode(event)
	if event.is_action_pressed(&"ui_cancel") and has_modal():
		var top: Modal = _modals.back()
		if top.dismissible and not top.is_closing:
			top.close()
		get_viewport().set_input_as_handled()


func _track_input_mode(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pointer := event is InputEventScreenTouch or event is InputEventMouseButton
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var keyboard := key != null and key.pressed and key.keycode != KEY_BACK
	if pointer and navigating:
		_set_navigating(false)
	elif (pad or keyboard) and not navigating:
		_set_navigating(true)


func _set_navigating(value: bool) -> void:
	navigating = value
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.grab_focus(not navigating)


## Menus grab focus when they open (for gamepads); after a tap, keep the focus but hide the ring.
func _on_focus_changed(control: Control) -> void:
	if not navigating and control.has_focus(true):
		control.grab_focus.call_deferred(true)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"_ui_feedback") or not button.get_meta(&"ui_feedback", true):
		return
	button.set_meta(&"_ui_feedback", true)
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: BaseButton) -> void:
	Haptics.tick()
	if button is CheckButton or button is CheckBox or Juice.motion_scale <= 0.0:
		return
	if button.pivot_offset == Vector2.ZERO:
		button.pivot_offset_ratio = Vector2(0.5, 0.5)
	_press_tween(button, Vector2.ONE * lerpf(1.0, PRESS_SCALE, Juice.motion_scale), 0.06)


func _on_button_up(button: BaseButton) -> void:
	if button.scale != Vector2.ONE:
		_press_tween(button, Vector2.ONE, 0.16)


func _press_tween(button: BaseButton, target: Vector2, seconds: float) -> void:
	var id := button.get_instance_id()
	var old: Tween = _press_tweens.get(id)
	if old != null and old.is_valid():
		old.kill()
	var tween := button.create_tween()
	tween.tween_property(button, ^"scale", target, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _press_tweens.erase(id))
	_press_tweens[id] = tween
