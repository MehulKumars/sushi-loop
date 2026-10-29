extends SceneTree
## Plays a Sushi Loop level in a real window with injected taps (the same input path as a finger)
## and saves frames of the key moments to build/playtest/: the start, a take in flight, the
## counter, a bento closing, the cascade, the last bento, results.
## godot --path . -s tools/sushi_playtest.gd [-- <level> [solve|doom|lose] [still] [WxH]]
##   solve: the solver's line to a win; doom: walk into a proven dead end, see the doom card,
##   step back, then finish; lose: fill the counter until it overflows. "still" = Reduce Motion.
## Needs a window (not --headless).

const OUT_DIR: String = "res://build/playtest"
const TestWindow := preload("res://tools/test_window.gd")

var _out: String = ""
var _shot: int = 0
var _board: SushiBoardView


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[0]) if args.size() > 0 else 9
	var mode := args[1] if args.size() > 1 else "solve"
	var still := args.has("still")
	var size := Vector2i(720, 1280)
	for arg in args:
		if "x" in arg and arg.split("x").size() == 2 and arg.split("x")[0].is_valid_int():
			size = Vector2i(int(arg.split("x")[0]), int(arg.split("x")[1]))
	_out = ProjectSettings.globalize_path("%s/%s_%02d" % [OUT_DIR, mode, level])
	DirAccess.make_dir_recursive_absolute(_out)
	for file in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(file))
	var marker := ProjectSettings.globalize_path("res://build/.gdignore")
	if not FileAccess.file_exists(marker):
		FileAccess.open(marker, FileAccess.WRITE).close()
	Progress.path = "user://playtest_progress.json"
	Progress.reset()
	Progress.add_coins(200)
	# Every dish, chapter and tip shown already, so no card or tip covers the board.
	Progress.set_count("dishes", (1 << SushiLevel.TYPE_COUNT) - 1)
	Progress.set_count("chapters_seen", 99)
	for tip in ["tip_counter", "tip_stars", "tip_window"]:
		Progress.set_count(tip, 1)
	TestWindow.fit(root, size)
	Screens.level = level
	change_scene_to_file(Screens.GAME)
	await _frames(30)
	TestWindow.fit(root, size)
	if still:
		Juice.motion_scale = 0.0
	await _frames(10)
	_board = current_scene.get_node(^"%SushiBoard") as SushiBoardView
	await _save("start")
	match mode:
		"doom":
			await _play_into_doom()
			await _play_solution(false)
		"lose":
			await _play_to_overflow()
		_:
			await _play_solution(true)
	await _wait(1.6)
	await _save("results")
	var state := _board.run.state
	print("playtest %s: level %d, won %s, lost %s, peak %d, stars %d, shots in %s" % [mode, level,
			state.is_won(), state.lost, state.peak, _board.run.stars(), _out])
	SaveStore.delete_save(Progress.path)
	quit()


## The solver's line from wherever the run is; `shots` saves the key moments on the way.
func _play_solution(shots: bool) -> void:
	var first := true
	var counter_shot := false
	var close_shot := false
	var warn_shot := false
	while not _board.run.state.is_over():
		var state := _board.run.state
		var solver := SushiSolver.solve(state)
		if solver.solution.is_empty():
			push_error("playtest: no solution from here")
			return
		var w := solver.solution[0]
		var closes := _closes_a_bento(state, w)
		await _tap(w)
		if shots and first:
			await _wait(0.08)
			await _save("take_in_flight")
			first = false
		if shots and closes and not close_shot:
			await _wait(0.22)
			await _save("bento_closing")
			await _wait(0.2)
			await _save("next_bento_and_cascade")
			close_shot = true
		await _settle()
		if shots and not counter_shot and _board.run.state.counter.size() > 0:
			await _save("counter")
			counter_shot = true
		if shots and not warn_shot and _board.run.state.counter.room() == 1:
			await _wait(0.3)
			await _save("counter_one_left")
			warn_shot = true
		if shots and _board.run.state.queue.size() - _board.run.state.closed == 1 and _board.run.state.closed > 0:
			if _board.run.state.plates_on_belt() <= 3:
				await _save("last_bento")
	await _wait(0.3)
	await _save("won")


## Takes a move the solver proves hopeless, waits for the doom card, then presses Step back.
func _play_into_doom() -> void:
	for step in 30:
		var state := _board.run.state
		if state.is_over():
			return
		var doomed := -1
		for w in state.window:
			var child := state.copy()
			if child.window_plate(w) < 0 or not child.take(w) or child.lost:
				continue
			if SushiSolver.solve(child, 20000).status == StateSolver.Status.EXHAUSTED:
				doomed = w
				break
		if doomed >= 0:
			await _tap(doomed)
			await _settle()
			await _wait(0.6)
			await _save("doom_card")
			var back := _find_button("Step back")
			if back != null:
				await _tap_at(back.get_global_rect().get_center())
				await _wait(0.4)
				await _save("stepped_back")
			return
		var solver := SushiSolver.solve(state)
		await _tap(solver.solution[0])
		await _settle()
	print("playtest: no doomed move found in 30 steps")


## Sends plates to the counter whenever possible until it overflows.
func _play_to_overflow() -> void:
	while not _board.run.state.is_over():
		var state := _board.run.state
		var pick := -1
		for w in state.window:
			var plate := state.window_plate(w)
			if plate >= 0:
				pick = w
				if not state.fits(state.plate_type(plate)):
					break
		await _tap(pick)
		await _settle()
		if state.counter.room() == 1:
			await _save("counter_one_left")
	await _wait(0.4)
	await _save("overflow")


func _closes_a_bento(state: SushiState, w: int) -> bool:
	var child := state.copy()
	child.take(w)
	return child.closed > state.closed


func _find_button(text: String) -> Button:
	for node in current_scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


## A press and release at window position `w`, through Input like a real tap.
func _tap(w: int) -> void:
	await _tap_at(_board.window_point(w))


func _tap_at(at: Vector2) -> void:
	# Events arrive in window pixels; the small test window shows the canvas scaled down.
	var window_at := root.get_final_transform() * at
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = window_at
		event.global_position = window_at
		Input.parse_input_event(event)
		await _frames(1)


func _settle() -> void:
	await _frames(2)
	var guard := 0
	while _board.is_busy() and guard < 600:
		await _frames(1)
		guard += 1


func _save(name: String) -> void:
	await _frames(1)
	_shot += 1
	root.get_texture().get_image().save_png(_out.path_join("%02d_%s.png" % [_shot, name]))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
