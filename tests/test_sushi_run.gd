extends GutTest
## SushiRun: undo (R9), the free rewind after a doom proof, continue (R8) and stars.

const H := preload("res://tests/sushi_helpers.gd")


func test_undo_restores_the_state_before_the_take() -> void:
	var run := SushiRun.new(H.cascade())
	run.take(0)
	run.take(2)
	assert_eq(run.state.peak, 2)
	assert_eq(run.undos_left(), 1)
	assert_true(run.undo())
	assert_eq(run.undos_left(), 0)
	assert_eq(run.state.counter.items, PackedInt32Array([0]))
	assert_eq(run.state.peak, 1, "the peak comes back too")
	assert_eq(run.state.offset, 1)
	assert_true(run.state.on_belt(1))


func test_one_free_undo_then_only_extra_ones() -> void:
	var run := SushiRun.new(H.cascade())
	run.take(0)
	run.take(2)
	assert_true(run.undo())
	assert_false(run.undo(), "the free undo is used")
	assert_true(run.undo(true), "an extra undo (after a rewarded video)")
	assert_eq(run.state.offset, 0)
	assert_false(run.undo(true), "nothing left to undo")


func test_undo_after_a_loss() -> void:
	var run := SushiRun.new(H.cascade(1))
	run.take(0)
	run.take(2)
	assert_true(run.state.lost)
	assert_true(run.undo())
	assert_false(run.state.lost)
	assert_eq(run.state.held, -1)
	assert_eq(run.state.offset, 1)


func test_rewind_goes_back_to_the_last_safe_state_for_free() -> void:
	var run := SushiRun.new(H.cascade(2))
	run.take(2)
	run.mark_safe()
	run.take(2)
	assert_true(run.rewind_to_safe())
	assert_eq(run.state.offset, 1)
	assert_eq(run.state.counter.items, PackedInt32Array([2]))
	assert_true(run.state.on_belt(1))
	assert_eq(run.undos_left(), 1, "rewinding is free")


func test_rewind_without_a_safe_state_goes_to_the_start() -> void:
	var run := SushiRun.new(H.cascade(2))
	run.take(2)
	run.take(2)
	assert_true(run.rewind_to_safe())
	assert_eq(run.state.offset, 0)
	assert_eq(run.state.plates_on_belt(), 6)
	assert_false(run.rewind_to_safe(), "already at the start")


func test_rewind_skips_states_after_the_safe_one() -> void:
	var run := SushiRun.new(H.cascade())
	run.mark_safe()
	run.take(0)
	run.take(2)
	run.take(0)
	assert_true(run.rewind_to_safe())
	assert_eq(run.state.offset, 0)


func test_three_stars_for_a_clean_win_within_the_star_peak() -> void:
	var level := H.cascade()
	level.star_peak = 2
	var run := SushiRun.new(level)
	for w in H.CASCADE_PATH:
		run.take(w)
	assert_true(run.state.is_won())
	assert_eq(run.stars(), 3)


func test_two_stars_when_the_counter_went_past_the_star_peak() -> void:
	var level := H.cascade()
	level.star_peak = 1
	var run := SushiRun.new(level)
	for w in H.CASCADE_PATH:
		run.take(w)
	assert_eq(run.stars(), 2)


func test_one_star_after_a_continue() -> void:
	var level := H.cascade(1)
	level.star_peak = 5
	var run := SushiRun.new(level)
	run.take(0)
	run.take(2)
	assert_true(run.continue_game())
	for w: int in [0, 0, 0, 0]:
		run.take(w)
	assert_true(run.state.is_won())
	assert_eq(run.stars(), 1)


func test_no_stars_before_the_win() -> void:
	var run := SushiRun.new(H.cascade())
	run.take(0)
	assert_eq(run.stars(), 0)
