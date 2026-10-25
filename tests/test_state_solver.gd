extends GutTest
## The generic StateSolver (game/kit/) on a toy puzzle: pick numbers left to right, each at most
## once, so they add up to exactly the target.


class ToySum:
	extends SolverState
	var values: PackedInt32Array
	var target: int
	var picked: int = 0
	var last: int = -1
	var total: int = 0

	func _init(v: PackedInt32Array, t: int) -> void:
		values = v
		target = t

	func solver_key() -> int:
		return picked

	func solver_moves() -> PackedInt32Array:
		var moves := PackedInt32Array()
		for i in range(last + 1, values.size()):
			moves.append(i)
		return moves

	func solver_child(move: int) -> SolverState:
		if total + values[move] > target:
			return null
		var child := ToySum.new(values, target)
		child.picked = picked | (1 << move)
		child.last = move
		child.total = total + values[move]
		return child

	func solver_goal() -> bool:
		return total == target


func test_finds_a_solution_and_its_moves() -> void:
	var solver := StateSolver.run(ToySum.new(PackedInt32Array([3, 5, 7]), 12), 1000)
	assert_eq(solver.status, StateSolver.Status.SOLVED)
	var sum := 0
	for i in solver.solution:
		sum += [3, 5, 7][i]
	assert_eq(sum, 12)
	assert_eq(solver.solution, PackedInt32Array([1, 2]))


func test_proves_no_solution() -> void:
	var solver := StateSolver.run(ToySum.new(PackedInt32Array([3, 5, 7]), 4), 1000)
	assert_eq(solver.status, StateSolver.Status.EXHAUSTED)
	assert_eq(solver.solution.size(), 0)
	assert_gt(solver.dead_ends, 0)


func test_goal_at_the_start_is_solved_with_no_moves() -> void:
	var solver := StateSolver.run(ToySum.new(PackedInt32Array([3]), 0), 10)
	assert_eq(solver.status, StateSolver.Status.SOLVED)
	assert_eq(solver.solution.size(), 0)


func test_budget_runs_out() -> void:
	var values := PackedInt32Array()
	for i in 18:
		values.append(2)
	var solver := StateSolver.run(ToySum.new(values, 37), 50)
	assert_eq(solver.status, StateSolver.Status.OUT_OF_BUDGET, "odd target, even values: unsolvable but large")
	assert_lte(solver.nodes, 51)


func test_slices_give_the_same_answer() -> void:
	var start := ToySum.new(PackedInt32Array([4, 9, 2, 8, 6, 5, 1]), 24)
	var whole := StateSolver.run(start, 10000)
	var sliced := StateSolver.new()
	sliced.begin(start, 10000)
	var steps := 0
	while sliced.step(1) == StateSolver.Status.RUNNING:
		steps += 1
		assert_lt(steps, 10000)
	assert_eq(sliced.status, whole.status)
	assert_eq(sliced.solution, whole.solution)
	assert_eq(sliced.nodes, whole.nodes)
	assert_gt(steps, 1, "it really ran in slices")


func test_branching_factor() -> void:
	var solver := StateSolver.run(ToySum.new(PackedInt32Array([3, 5, 7]), 4), 1000)
	assert_gt(solver.branching(), 0.0)
	assert_eq(StateSolver.new().branching(), 0.0)
