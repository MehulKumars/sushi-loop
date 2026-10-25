extends GutTest
## SushiSolver: solutions replay to a win, proofs of no solution, par and hints
## (levels worked by hand in tests/sushi_helpers.gd).

const H := preload("res://tests/sushi_helpers.gd")


func test_solution_replays_to_a_win() -> void:
	var start := SushiState.start(H.cascade())
	var solver := SushiSolver.solve(start, 10000)
	assert_eq(solver.status, StateSolver.Status.SOLVED)
	var state := start.copy()
	for w in solver.solution:
		assert_true(state.take(w))
	assert_true(state.is_won())


func test_solver_leaves_the_start_alone() -> void:
	var start := SushiState.start(H.cascade())
	SushiSolver.solve(start, 10000)
	assert_eq(start.offset, 0)
	assert_eq(start.plates_on_belt(), 6)


func test_no_counter_and_no_fitting_plate_is_unsolvable() -> void:
	var solver := SushiSolver.solve(SushiState.start(H.cascade(0)), 10000)
	assert_eq(solver.status, StateSolver.Status.EXHAUSTED)


func test_one_counter_slot_is_not_enough() -> void:
	assert_eq(SushiSolver.solve(SushiState.start(H.cascade(1)), 10000).status, StateSolver.Status.EXHAUSTED)
	assert_eq(SushiSolver.solve(SushiState.start(H.cascade(2)), 10000).status, StateSolver.Status.SOLVED)


func test_par_is_the_smallest_counter_that_solves() -> void:
	assert_eq(SushiSolver.par(H.cascade(5), 10000), 2)
	assert_eq(SushiSolver.par(H.cascade(2), 10000), 2)
	# rolling: every line puts a type-1 plate in the window while bento 0 is open (take 2, 1, then
	# plate 5 is alone at offset 7), so one counter slot is needed and enough.
	assert_eq(SushiSolver.par(H.rolling(), 10000), 1)


func test_par_of_an_unsolvable_level_is_minus_one() -> void:
	assert_eq(SushiSolver.par(H.cascade(1), 10000), -1)


func test_doomed_second_move() -> void:
	# Counter 2: take(2) is fine (take(1) next solves); take(2) again leaves plate 0 alone in the
	# window with the counter full, so every line loses.
	var state := H.played(H.cascade(2), [2])
	assert_eq(SushiSolver.solve(state, 10000).status, StateSolver.Status.SOLVED)
	var doomed := H.played(H.cascade(2), [2, 2])
	assert_eq(doomed.counter.size(), 2)
	assert_eq(SushiSolver.solve(doomed, 10000).status, StateSolver.Status.EXHAUSTED)


func test_hint_keeps_the_level_solvable() -> void:
	var state := H.played(H.cascade(2), [2])
	var w := SushiSolver.hint(state, 10000)
	assert_eq(w, 1, "only plate 0 (position 1) keeps a way out")
	assert_true(state.take(w))
	assert_eq(SushiSolver.solve(state, 10000).status, StateSolver.Status.SOLVED)


func test_hint_on_a_lost_level_is_minus_one() -> void:
	var state := H.played(H.cascade(1), [0, 2])
	assert_true(state.lost)
	assert_eq(SushiSolver.hint(state, 1000), -1)
