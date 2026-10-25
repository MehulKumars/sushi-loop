extends GutTest
## SushiBoardView in the scene tree: a level plays to a win through tap(), the window stays
## touch-sized on every baked level, the doom detector speaks and rewinds, a tap made during an
## animation is kept, and the level count agrees with the bake.

const H := preload("res://tests/sushi_helpers.gd")
const SIZE := Vector2(672, 1000)
const TOUCH := 96.0

var _board: SushiBoardView


func before_each() -> void:
	_board = SushiBoardView.new()
	_board.size = SIZE
	add_child_autofree(_board)


func test_level_count_matches_the_bake() -> void:
	assert_eq(Progress.LEVEL_COUNT_DEFAULT, SushiLevels.count())


func test_level_one_plays_to_a_win_through_taps() -> void:
	_board.play(SushiLevels.level(1))
	watch_signals(_board)
	var guard := 0
	while not _board.run.state.is_over() and guard < 40:
		_board.tap(SushiSolver.solve(_board.run.state).solution[0])
		await _until_idle()
		guard += 1
	assert_true(_board.run.state.is_won())
	assert_signal_emitted(_board, "won")
	assert_eq(_board.run.stars(), 3)


func test_window_is_touch_sized_on_every_level() -> void:
	for level in SushiLevels.all():
		_board.play(level)
		for w in range(1, level.window):
			var gap := _board.window_point(w).distance_to(_board.window_point(w - 1))
			assert_gte(gap, TOUCH, "level %d" % level.id)
		assert_eq(_board.window_at(_board.get_global_transform_with_canvas().affine_inverse() * _board.window_point(0)), 0)


func test_a_tap_beside_the_window_takes_nothing() -> void:
	_board.play(SushiLevels.level(1))
	assert_eq(_board.window_at(Vector2(4, 4)), -1)
	assert_eq(_board.window_at(SIZE * 0.5), -1, "the middle of the counter")


func test_doom_detector_reports_a_dead_end_and_rewinds() -> void:
	_board.play(H.cascade(2))
	watch_signals(_board)
	_board.tap(2)
	await _until_idle()
	await wait_process_frames(10)
	assert_true(_board.run.safe, "the detector proved the state after one take solvable")
	_board.tap(2)
	await _until_idle()
	await wait_process_frames(10)
	assert_signal_emitted(_board, "doomed")
	assert_true(_board.rewind())
	assert_eq(_board.run.state.offset, 1)
	assert_eq(_board.run.state.counter.items, PackedInt32Array([2]))


func test_a_tap_during_an_animation_is_kept() -> void:
	_board.play(H.cascade())
	_board.tap(0)
	assert_true(_board.is_busy())
	_board.tap(2)
	await _until_idle()
	await _until_idle()
	assert_eq(_board.run.state.counter.items, PackedInt32Array([0, 1]))


func test_undo_and_continue_through_the_board() -> void:
	_board.play(H.cascade(1))
	watch_signals(_board)
	_board.tap(0)
	await _until_idle()
	_board.tap(2)
	await _until_idle()
	assert_signal_emitted(_board, "lost")
	assert_true(_board.continue_game())
	await _until_idle()
	assert_eq(_board.run.state.counter.capacity, 3)
	assert_eq(_board.run.state.offset, 7)
	assert_true(_board.undo())
	assert_eq(_board.run.state.counter.capacity, 3, "the continue's slots survive undo")


func _until_idle() -> void:
	await wait_process_frames(2)
	var guard := 0
	while _board.is_busy() and guard < 400:
		await wait_process_frames(1)
		guard += 1
