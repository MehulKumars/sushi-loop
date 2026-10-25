extends GutTest
## The UI autoload: styles, popups and Back, button press feedback, focus rings.

var _style_before: StringName


func before_all() -> void:
	_style_before = UI.current_style


func after_each() -> void:
	UI.close_all()
	Juice.motion_scale = 1.0


func after_all() -> void:
	if _style_before != &"":
		UI.apply_style(_style_before, false)


## The template's five styles plus Sushi Loop's own.
func test_six_styles_are_listed() -> void:
	var styles := UI.list_styles()
	assert_eq(styles.size(), 6)
	assert_eq(styles[0], &"candy_casual", "listed alphabetically")
	assert_eq(styles[5], &"sushi", "listed alphabetically")
	for id in [&"candy_casual", &"cozy_paper", &"neon_arcade", &"pixel_retro", &"sleek_dark", &"sushi"]:
		assert_has(styles, id)


func test_apply_style_changes_the_project_theme() -> void:
	UI.apply_style(&"candy_casual", false)
	var candy := ThemeDB.get_project_theme().get_color(&"accent", &"Tokens")
	UI.apply_style(&"neon_arcade", false)
	var neon := ThemeDB.get_project_theme().get_color(&"accent", &"Tokens")
	assert_ne(candy, neon)
	assert_eq(UI.current_style, &"neon_arcade")
	UI.apply_style(&"neon_arcade", false)
	assert_true(ThemeDB.get_project_theme().has_color(&"accent", &"Tokens"), "re-applying the current style keeps it")


func test_back_closes_the_top_popup_only() -> void:
	var first := UI.open(load(Screens.CONFIRM) as PackedScene)
	var second := UI.open(load(Screens.CONFIRM) as PackedScene)
	await wait_process_frames(2)
	_press_back()
	await wait_seconds(0.4)
	assert_false(is_instance_valid(second), "top popup closed")
	assert_true(is_instance_valid(first), "the one below stays open")


func test_back_does_not_close_a_popup_the_player_must_answer() -> void:
	var results := UI.open(load(Screens.RESULTS) as PackedScene)
	# The results popup pauses the game, so wait with timers that run while paused.
	await get_tree().create_timer(0.05, true).timeout
	_press_back()
	await get_tree().create_timer(0.3, true).timeout
	assert_true(is_instance_valid(results) and not results.is_closing)
	assert_true(get_tree().paused, "results pause the game")
	UI.close_all()
	assert_false(get_tree().paused, "closing every popup unpauses")


func test_confirm_returns_the_answer() -> void:
	var answer: Array = []
	var ask := func() -> void: answer.append(await UI.confirm("Quit?", "", "Quit"))
	ask.call()
	await wait_process_frames(2)
	var popup := UI._modals.back() as Modal
	popup.get_node(^"%ConfirmButton").emit_signal(&"pressed")
	await wait_seconds(0.3)
	assert_eq(answer, [true])


func test_pressed_button_squashes_and_springs_back() -> void:
	var button := Button.new()
	button.size = Vector2(200, 96)
	add_child_autofree(button)
	await wait_process_frames(1)
	button.button_down.emit()
	await wait_seconds(0.12)
	assert_lt(button.scale.x, 1.0)
	button.button_up.emit()
	await wait_seconds(0.3)
	assert_almost_eq(button.scale.x, 1.0, 0.001)


func test_reduce_motion_turns_the_squash_off() -> void:
	Juice.motion_scale = 0.0
	var button := Button.new()
	add_child_autofree(button)
	await wait_process_frames(1)
	button.button_down.emit()
	await wait_seconds(0.12)
	assert_eq(button.scale, Vector2.ONE)


func test_buttons_can_opt_out_of_feedback() -> void:
	var button := Button.new()
	button.set_meta(&"ui_feedback", false)
	add_child_autofree(button)
	await wait_process_frames(1)
	button.button_down.emit()
	await wait_seconds(0.12)
	assert_eq(button.scale, Vector2.ONE)


func test_focus_ring_hidden_after_touch_and_shown_after_keys() -> void:
	var button := Button.new()
	add_child_autofree(button)
	UI._track_input_mode(_touch())
	button.grab_focus()
	await wait_process_frames(2)
	assert_true(button.has_focus(), "keeps focus for keyboard and gamepad")
	assert_false(button.has_focus(true), "but the ring is hidden after a tap")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	UI._track_input_mode(key)
	await wait_process_frames(1)
	assert_true(button.has_focus(true), "ring shows once keys are used")
	UI._track_input_mode(_touch())


func test_android_back_key_is_not_keyboard_navigation() -> void:
	UI._track_input_mode(_touch())
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.pressed = true
	UI._track_input_mode(back)
	assert_false(UI.navigating)


func test_back_key_is_mapped_to_ui_cancel() -> void:
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.pressed = true
	assert_true(back.is_action(&"ui_cancel"), "Android Back must reach menus and the pause menu")


func _press_back() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	UI._input(event)


func _touch() -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	return touch
