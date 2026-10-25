extends GutTest
## SushiBot: the greedy and careful policies from docs/SUSHI_LOOP.md and their win rates.

const H := preload("res://tests/sushi_helpers.gd")


func test_greedy_takes_a_fitting_plate_when_there_is_one() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = i
		var state := SushiState.start(H.rolling())
		var w := SushiBot.choose(state, SushiBot.GREEDY, rng)
		assert_true(w == 0 or w == 2, "positions 0 and 2 hold type 0, which fits")


func test_greedy_takes_any_plate_when_none_fits() -> void:
	var rng := RandomNumberGenerator.new()
	var seen: Dictionary[int, bool] = {}
	for i in 40:
		rng.seed = i
		seen[SushiBot.choose(SushiState.start(H.cascade()), SushiBot.GREEDY, rng)] = true
	assert_eq(seen.size(), 3, "all three type-1 plates get picked sometimes")


func test_careful_takes_the_fitting_plate_nearest_the_exit() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(SushiBot.choose(SushiState.start(H.rolling()), SushiBot.CAREFUL, rng), 2)


func test_careful_stashes_the_plate_whose_bento_comes_soonest() -> void:
	# Bentos [0, 1, 2], one open (type 0), two shown in the queue. Window: type 2, type 1, nothing
	# fits; bento 1 comes before bento 2, so the type-1 plate goes on the counter.
	var level := SushiLevel.make([2, 1, -1, 0, 0, 0, 1, 1, 2, 2, -1, -1], [0, 1, 2], 1, 3, 5)
	level.preview = 2
	var state := SushiState.start(level)
	assert_eq(state.window_plate(0), 0)
	assert_eq(state.window_plate(1), 1)
	assert_eq(SushiBot.choose(state, SushiBot.CAREFUL, RandomNumberGenerator.new()), 1)


func test_careful_prefers_a_kind_already_on_the_counter() -> void:
	# Same level, but no bento is shown in the queue: a type-1 plate already waits on the counter,
	# so the next type-1 plate joins it rather than starting a second kind.
	var level := SushiLevel.make([2, 1, 1, 0, 0, 0, 2, 2, 1, -1, -1, -1], [0, 1, 2], 1, 3, 5)
	assert_eq(level.validate(), "")
	level.preview = 0
	var state := SushiState.start(level)
	assert_true(state.take(2), "plate 2 (type 1) onto the counter")
	assert_eq(state.window_plate(1), 0, "plate 0 (type 2)")
	assert_eq(state.window_plate(2), 1, "plate 1 (type 1)")
	assert_eq(SushiBot.choose(state, SushiBot.CAREFUL, RandomNumberGenerator.new()), 2)


func test_choose_returns_minus_one_when_over() -> void:
	var state := H.played(H.cascade(), H.CASCADE_PATH)
	assert_eq(SushiBot.choose(state, SushiBot.GREEDY, RandomNumberGenerator.new()), -1)


func test_win_rate_is_repeatable_and_a_fraction() -> void:
	var a := SushiBot.win_rate(H.cascade(2), SushiBot.GREEDY, 50, 3)
	var b := SushiBot.win_rate(H.cascade(2), SushiBot.GREEDY, 50, 3)
	assert_eq(a, b)
	assert_between(a, 0.0, 1.0)


func test_an_open_level_is_always_won() -> void:
	# Six counter slots: nothing can overflow.
	assert_eq(SushiBot.win_rate(H.cascade(6), SushiBot.GREEDY, 30, 1), 1.0)
	assert_eq(SushiBot.win_rate(H.cascade(6), SushiBot.CAREFUL, 30, 1), 1.0)


func test_an_unsolvable_level_is_never_won() -> void:
	assert_eq(SushiBot.win_rate(H.cascade(1), SushiBot.GREEDY, 30, 1), 0.0)
	assert_eq(SushiBot.win_rate(H.cascade(1), SushiBot.CAREFUL, 30, 1), 0.0)
