class_name SushiSolver
extends RefCounted
## Sushi Loop on top of the generic StateSolver: solve a state, find a level's par (the smallest
## counter that still solves it) and give a hint. The doom detector (SushiDoom) uses the same
## search in slices.

const BUDGET: int = 200_000


## Searches from a copy of `state` (the state itself is never changed).
static func solve(state: SushiState, budget: int = BUDGET) -> StateSolver:
	return StateSolver.run(state.copy(), budget)


## The smallest counter size that solves `level`; -1 if none does or a smaller one stayed unknown.
static func par(level: SushiLevel, budget: int = BUDGET) -> int:
	for size in level.counter + 1:
		var state := SushiState.start(level)
		state.counter.capacity = size
		match StateSolver.run(state, budget).status:
			StateSolver.Status.SOLVED:
				return size
			StateSolver.Status.OUT_OF_BUDGET:
				return -1
	return -1


## A window position that keeps the level solvable. If the search runs out of budget, the first
## move that does not lose at once; -1 when the level is over or provably lost.
static func hint(state: SushiState, budget: int = 20_000) -> int:
	if state.is_over():
		return -1
	var solver := solve(state, budget)
	if solver.status == StateSolver.Status.SOLVED and not solver.solution.is_empty():
		return solver.solution[0]
	if solver.status == StateSolver.Status.EXHAUSTED:
		return -1
	for move in state.solver_moves():
		if state.solver_child(move) != null:
			return move
	return -1
