extends GutTest
## Sushi Loop rules R1-R8 from docs/SUSHI_LOOP.md, on hand-worked levels (tests/sushi_helpers.gd).

const H := preload("res://tests/sushi_helpers.gd")


func test_window_shows_slots_by_offset() -> void:
	var state := SushiState.start(H.rolling())
	assert_eq(state.offset, 0)
	assert_eq(state.window_plate(0), 0)
	assert_eq(state.window_plate(1), 1)
	assert_eq(state.window_plate(2), 2)
	assert_eq(state.plate_type(1), 1)
	assert_eq(state.ring_position(4), 4)


func test_take_packs_a_fitting_plate_and_steps_once() -> void:
	var state := SushiState.start(H.rolling())
	assert_true(state.take(2))
	assert_false(state.on_belt(2))
	assert_eq(state.open_type(0), 0)
	assert_eq(state.open_fill(0), 1)
	assert_eq(state.offset, 1, "one take, one step")
	assert_eq(state.ring_position(0), 1)
	assert_eq(state.window_plate(0), -1, "slot 11 is empty")
	assert_eq(state.window_plate(1), 0)
	assert_eq(state.window_plate(2), 1)


func test_empty_window_rolls_on_to_the_next_plate() -> void:
	var state := H.played(H.rolling(), [2, 1])
	assert_eq(state.open_fill(0), 2)
	assert_eq(state.offset, 7)
	assert_eq(state.window_plate(0), 5)
	assert_eq(state.window_plate(1), -1)
	assert_eq(state.plates_on_belt(), 4)


func test_taps_on_empty_positions_do_nothing() -> void:
	var state := H.played(H.rolling(), [2])
	assert_false(state.take(0), "window position 0 shows an empty slot")
	assert_eq(state.offset, 1)
	assert_eq(state.plates_on_belt(), 5)
	assert_false(state.take(3), "outside the window")
	assert_false(state.take(-1))


func test_non_fitting_plate_goes_on_the_counter() -> void:
	var state := SushiState.start(H.cascade())
	assert_true(state.take(0))
	assert_eq(state.counter.items, PackedInt32Array([0]))
	assert_true(state.take(2))
	assert_eq(state.counter.items, PackedInt32Array([0, 1]), "in arrival order")
	assert_eq(state.peak, 2)
	assert_eq(state.offset, 7)


func test_closing_a_bento_opens_the_next_and_cascades_the_counter() -> void:
	var state := H.played(H.cascade(), [0, 2, 0, 0])
	assert_eq(state.open_fill(0), 2)
	assert_true(state.take(0), "plate 3 closes bento 0")
	assert_eq(state.closed, 1)
	assert_eq(state.open_type(0), 1, "bento 1 opened in the same slot")
	assert_eq(state.open_fill(0), 2, "plates 0 and 1 hopped in")
	assert_eq(state.counter.size(), 0)
	assert_eq(state.peak, 2, "the peak stays")
	assert_false(state.is_won())
	assert_eq(state.offset, 10)
	assert_eq(state.window_plate(0), 2)


func test_last_bento_closing_wins() -> void:
	var state := H.played(H.cascade(), H.CASCADE_PATH)
	assert_true(state.is_won())
	assert_true(state.is_over())
	assert_false(state.lost)
	assert_eq(state.closed, 2)
	assert_eq(state.plates_on_belt(), 0)
	assert_eq(state.open_type(0), -1, "no bento left to open")
	assert_false(state.take(0), "nothing to take after the win")


func test_routing_prefers_the_fuller_bento_then_the_lower_slot() -> void:
	var state := SushiState.start(H.twins())
	assert_eq(state.open_type(0), 0)
	assert_eq(state.open_type(1), 0)
	assert_true(state.take(2))
	assert_eq(state.open_fill(0), 1, "tie: the lower slot")
	assert_eq(state.open_fill(1), 0)
	assert_eq(state.window_plate(2), 1)
	assert_true(state.take(2))
	assert_eq(state.open_fill(0), 2, "the fuller bento")
	assert_eq(state.open_fill(1), 0)


func test_third_plate_closes_and_queue_moves_into_that_slot() -> void:
	var state := H.played(H.twins(), [2, 2])
	assert_eq(state.window_plate(2), 0)
	assert_true(state.take(2))
	assert_eq(state.closed, 1)
	assert_eq(state.open_type(0), 1, "bento 2 (type 1) opened in slot 0")
	assert_eq(state.open_fill(0), 0)
	assert_eq(state.open_type(1), 0)


func test_fits_follows_the_open_bentos() -> void:
	var state := SushiState.start(H.cascade())
	assert_true(state.fits(0))
	assert_false(state.fits(1), "bento 1 is still queued")


func test_overflow_loses_and_holds_the_plate() -> void:
	var state := SushiState.start(H.cascade(1))
	assert_true(state.take(0))
	assert_eq(state.offset, 1)
	assert_true(state.take(2), "plate 1 is taken but fits nowhere")
	assert_true(state.lost)
	assert_true(state.is_over())
	assert_false(state.is_won())
	assert_eq(state.held, 1)
	assert_eq(state.counter.items, PackedInt32Array([0]))
	assert_eq(state.offset, 1, "a lost take does not move the belt")
	assert_false(state.take(1), "no more takes once lost")


func test_continue_adds_two_slots_places_the_plate_and_steps() -> void:
	var state := H.played(H.cascade(1), [0, 2])
	assert_true(state.continue_game())
	assert_false(state.lost)
	assert_eq(state.held, -1)
	assert_eq(state.counter.capacity, 3)
	assert_eq(state.counter.items, PackedInt32Array([0, 1]))
	assert_eq(state.continues, 1)
	assert_eq(state.offset, 7, "the belt advances as the take completes")
	for w: int in [0, 0, 0, 0]:
		assert_true(state.take(w))
	assert_true(state.is_won())


func test_continue_only_after_a_loss() -> void:
	var state := SushiState.start(H.cascade())
	assert_false(state.continue_game())
	assert_eq(state.counter.capacity, 5)


func test_copy_is_independent() -> void:
	var state := SushiState.start(H.cascade())
	var twin := state.copy()
	assert_true(twin.take(0))
	assert_eq(state.offset, 0)
	assert_eq(state.counter.size(), 0)
	assert_true(state.on_belt(0))
	assert_eq(twin.counter.size(), 1)


func test_invariant_counter_never_matches_an_open_bento() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for run in 30:
		var state := SushiState.start(H.cascade(6))
		while not state.is_over():
			var options: Array[int] = []
			for w in 3:
				if state.window_plate(w) >= 0:
					options.append(w)
			state.take(options[rng.randi_range(0, options.size() - 1)])
			for plate in state.counter.items:
				assert_false(state.fits(state.plate_type(plate)), "run %d: counter plate %d fits" % [run, plate])


func test_level_validate_checks_three_plates_per_bento() -> void:
	assert_eq(H.cascade().validate(), "")
	var short := SushiLevel.make([1, 1, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1], [0, 1], 1, 3, 5)
	assert_ne(short.validate(), "", "type 1 has 2 plates for 1 bento")
	var empty_window := SushiLevel.make([-1, -1, -1, 1, 1, 1, 0, 0, 0, -1, -1, -1], [0, 1], 1, 3, 5)
	assert_eq(empty_window.validate(), "", "an empty first window is allowed: the belt rolls on")
	var rolled := SushiState.start(empty_window)
	assert_eq(rolled.offset, 4, "R1: the belt rolls on at the start until plate 8 reaches position 0")
	assert_eq(rolled.window_plate(0), 8)


func test_level_round_trips_through_a_dictionary() -> void:
	var level := H.twins()
	level.id = 12
	level.role = "hard"
	level.par = 3
	level.star_peak = 4
	level.preview = 2
	level.seed = 99
	var back := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(level.to_dict())))
	assert_eq(back.belt, level.belt)
	assert_eq(back.bentos, level.bentos)
	assert_eq([back.id, back.open, back.window, back.counter, back.preview, back.par, back.star_peak, back.seed],
			[12, 2, 3, 5, 2, 3, 4, 99])
	assert_eq(back.role, "hard")


static func _any_plate(state: SushiState) -> int:
	for w in 3:
		if state.window_plate(w) >= 0:
			return w
	return -1
