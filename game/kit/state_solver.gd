class_name StateSolver
extends RefCounted
## Generic depth-first search with a dead-state memo and a node budget, for puzzles whose states
## extend SolverState. Runs in one go (run) or in slices (begin, then step each frame) so a doom
## detector never blocks input. Assumes no move leads back to an earlier state (every move uses
## something up), so any state met twice is already known dead.

enum Status { RUNNING, SOLVED, EXHAUSTED, OUT_OF_BUDGET }

var status: Status = Status.EXHAUSTED
## The moves from the start to a goal, once SOLVED.
var solution := PackedInt32Array()
## States expanded so far.
var nodes: int = 0
## Expanded states where every move failed (lost or already known dead).
var dead_ends: int = 0
## Legal children over all expanded states (branching factor = children / nodes).
var children: int = 0

var _budget: int = 0
var _states: Array[SolverState] = []
var _moves: Array[PackedInt32Array] = []
var _next := PackedInt32Array()
var _alive := PackedInt32Array()
var _path := PackedInt32Array()
var _seen: Dictionary[int, bool] = {}


## Searches from `start` until it ends or `budget` states are expanded.
static func run(start: SolverState, budget: int) -> StateSolver:
	var solver := StateSolver.new()
	solver.begin(start, budget)
	solver.step(budget)
	return solver


func begin(start: SolverState, budget: int) -> void:
	_budget = budget
	nodes = 0
	dead_ends = 0
	children = 0
	solution = PackedInt32Array()
	_states.clear()
	_moves.clear()
	_next = PackedInt32Array()
	_alive = PackedInt32Array()
	_path = PackedInt32Array()
	_seen.clear()
	if start.solver_goal():
		status = Status.SOLVED
		return
	_seen[start.solver_key()] = true
	status = Status.RUNNING
	_push(start)


## Expands up to `max_nodes` more states and returns the status (RUNNING while unfinished).
func step(max_nodes: int) -> Status:
	if status != Status.RUNNING:
		return status
	var limit := nodes + max_nodes
	while not _states.is_empty():
		var top := _states.size() - 1
		var index := _next[top]
		var moves := _moves[top]
		if index >= moves.size():
			if _alive[top] == 0:
				dead_ends += 1
			_pop()
			continue
		_next[top] = index + 1
		var child := _states[top].solver_child(moves[index])
		if child == null:
			continue
		children += 1
		var key := child.solver_key()
		if _seen.has(key):
			continue
		_seen[key] = true
		_alive[top] += 1
		if child.solver_goal():
			solution = _path.duplicate()
			solution.append(moves[index])
			status = Status.SOLVED
			_states.clear()
			return status
		if nodes >= _budget:
			status = Status.OUT_OF_BUDGET
			_states.clear()
			return status
		_path.append(moves[index])
		_push(child)
		if nodes >= limit:
			return status
	status = Status.EXHAUSTED
	return status


## Average legal moves per expanded state (0 before anything was expanded).
func branching() -> float:
	return float(children) / float(nodes) if nodes > 0 else 0.0


func _push(state: SolverState) -> void:
	nodes += 1
	_states.append(state)
	_moves.append(state.solver_moves())
	_next.append(0)
	_alive.append(0)


func _pop() -> void:
	_states.pop_back()
	_moves.pop_back()
	_next.resize(_next.size() - 1)
	_alive.resize(_alive.size() - 1)
	if not _path.is_empty() and _path.size() >= _states.size():
		_path.resize(_path.size() - 1)
