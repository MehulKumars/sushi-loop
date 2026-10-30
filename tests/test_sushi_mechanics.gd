extends GutTest
## The special plates and orders of docs/SUSHI_LOOP.md M1-M3 on small levels worked by hand:
## covered dishes, rush orders, the chef's special, and how the baked strings carry them.
## Window positions: the plate in slot w starts at position w; position 2 is the exit.

const W := SushiLevel.WILD


## Slots 0-2 dish 0 in the window, slots 9-11 dish 1 waiting; one bento at a time, 0 then 1.
static func _rush_level(limit: int) -> SushiLevel:
	var level := SushiLevel.make([0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 1, 3, 5)
	level.rush = PackedInt32Array([0, limit])
	return level


## Takes the three dish-0 plates in the order that keeps them in the window: bento 0 closes on
## the third take and the rush bento (dish 1) opens.
static func _close_first_bento(state: SushiState) -> void:
	for i in 3:
		state.take(2)


func test_covered_plates_show_once_they_reach_the_window() -> void:
	var level := SushiLevel.make([0, 1, 0, -1, -1, -1, -1, -1, -1, 1, 0, 1], [0, 1], 2, 3, 5)
	level.covers = (1 << 9) | (1 << 10) | (1 << 11)
	assert_eq(level.validate(), "")
	var state := SushiState.start(level)
	assert_true(state.is_covered(11), "outside the window the cloche stays on")
	assert_false(state.is_covered(0), "plates that were never covered show their dish")
	state.record = true
	state.take(2)
	assert_eq(state.window_plate(0), 11, "slot 11 entered the window")
	assert_false(state.is_covered(11), "the cloche lifts in the window")
	assert_true(state.is_covered(10), "the next one is still covered")
	assert_true(state.events.any(func(e: Dictionary) -> bool: return e.kind == &"reveal" and e.plate == 11))


func test_a_covered_plate_cannot_hide_nothing() -> void:
	var level := SushiLevel.make([0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 5)
	level.covers = 1 << 4
	assert_ne(level.validate(), "", "an empty slot cannot be covered")


func test_a_rush_order_closed_in_time_is_safe() -> void:
	var state := SushiState.start(_rush_level(3))
	_close_first_bento(state)
	assert_eq(state.open_type(0), 1, "the rush bento is open")
	assert_eq(state.rush_of(0), 3, "its count starts with the next take")
	for i in 3:
		state.take(2)
	assert_true(state.is_won(), "closed on its last take: in time")
	assert_false(state.lost)


func test_a_rush_order_that_runs_out_loses_the_level() -> void:
	var state := SushiState.start(_rush_level(1))
	_close_first_bento(state)
	state.record = true
	assert_true(state.take(2))
	assert_true(state.lost)
	assert_eq(state.lost_reason, &"rush")
	assert_eq(state.rush_slot, 0)
	assert_eq(state.held, SushiState.NONE, "no plate is held: the counter did not overflow")
	assert_true(state.events.any(func(e: Dictionary) -> bool: return e.kind == &"rush_out"))


func test_a_continue_gives_a_missed_rush_order_more_takes() -> void:
	var state := SushiState.start(_rush_level(1))
	_close_first_bento(state)
	state.take(2)
	var capacity := state.counter.capacity
	assert_true(state.continue_game())
	assert_false(state.lost)
	assert_eq(state.rush_of(0), SushiState.RUSH_EXTRA)
	assert_eq(state.counter.capacity, capacity, "takes, not counter slots")
	state.take(2)
	state.take(2)
	assert_true(state.is_won())


func test_a_run_keeps_no_extra_slots_after_a_rush_continue() -> void:
	var run := SushiRun.new(_rush_level(1))
	for i in 4:
		run.take(2)
	assert_true(run.state.lost)
	assert_true(run.continue_game())
	run.take(2)
	assert_true(run.undo())
	assert_eq(run.state.counter.capacity, 5, "undo does not invent counter slots")


## Slot 0 a chef's special, slots 1-2 dish 0, slots 9-11 dish 1: dish 0 is one plate short.
func test_the_chefs_special_goes_into_the_fullest_bento() -> void:
	var level := SushiLevel.make([W, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 3)
	assert_eq(level.validate(), "")
	assert_eq(level.wild_count(), 1)
	var state := SushiState.start(level)
	assert_true(state.fits(W), "it fits any open bento")
	state.take(2)
	state.take(2)
	assert_eq(state.open_fill(0), 2)
	assert_eq(state.window_plate(2), 0, "the special reached the exit")
	state.take(2)
	assert_eq(state.closed, 1, "it closed the dish-0 bento")
	assert_eq(state.counter.size(), 0, "a special never waits on the counter")
	assert_eq(SushiSolver.solve(state).status, StateSolver.Status.SOLVED)


## Dish 0 is one plate short; taking the special while the dish-1 bento is fuller wastes it.
func test_a_special_taken_too_early_fills_the_wrong_bento() -> void:
	var level := SushiLevel.make([0, W, 1, -1, -1, -1, -1, -1, -1, 0, 1, 1], [0, 1], 2, 3, 5)
	assert_eq(level.validate(), "")
	var state := SushiState.start(level)
	state.take(2)
	assert_eq(state.open_fill(1), 1, "a dish-1 plate went in")
	assert_eq(state.window_plate(2), 1, "the special is at the exit")
	state.take(2)
	assert_eq(state.open_fill(1), 2, "the special joined the fuller dish-1 bento")
	assert_eq(SushiSolver.solve(state).status, StateSolver.Status.EXHAUSTED, "dish 0 can never be completed now")


func test_specials_must_make_up_the_missing_plates() -> void:
	var level := SushiLevel.make([W, W, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 5)
	assert_eq(level.validate(), "", "two dish-0 plates missing, two specials")
	level = SushiLevel.make([W, W, 0, 0, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 5)
	assert_ne(level.validate(), "", "one plate missing but two specials")
	level = SushiLevel.make([0, 0, 0, W, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 5)
	assert_ne(level.validate(), "", "a special with nothing missing")


func test_baked_strings_carry_covers_specials_and_rush_limits() -> void:
	var level := SushiLevel.make([W, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 2, 3, 3)
	level.covers = (1 << 1) | (1 << 10)
	level.rush = PackedInt32Array([0, 6])
	var d := level.to_dict(false)
	assert_eq(d.belt, "*a0......1b1")
	assert_eq(d.rush, [0, 6])
	var back := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(back.belt, level.belt)
	assert_eq(back.covers, level.covers)
	assert_eq(back.rush, level.rush)
	assert_eq(back.validate(), "")
	assert_false(SushiLevel.from_dict(SushiLevel.make([0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1]).to_dict()).has_rush(),
			"no rush field when nothing rushes")
