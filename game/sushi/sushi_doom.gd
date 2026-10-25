class_name SushiDoom
extends RefCounted
## The doom detector (docs/SUSHI_LOOP.md "Forgiveness"): after each take the board calls watch(),
## then tick() each frame searches a small slice. DOOMED means the solver proved the level can no
## longer be won; SAFE comes with a solution (the hint's next move). UNSURE: the budget ran out.

enum Verdict { IDLE, SEARCHING, SAFE, DOOMED, UNSURE }

const BUDGET: int = 60_000
## States per frame: small enough that a slow phone never drops a frame for it.
const SLICE: int = 400

var verdict: Verdict = Verdict.IDLE
var solution := PackedInt32Array()

var _solver: StateSolver = null


func watch(state: SushiState) -> void:
	solution = PackedInt32Array()
	_solver = StateSolver.new()
	_solver.begin(state.copy(), BUDGET)
	_settle()


func stop() -> void:
	_solver = null
	verdict = Verdict.IDLE
	solution = PackedInt32Array()


func tick(slice: int = SLICE) -> Verdict:
	if verdict == Verdict.SEARCHING and _solver != null:
		_solver.step(slice)
		_settle()
	return verdict


func _settle() -> void:
	match _solver.status:
		StateSolver.Status.RUNNING:
			verdict = Verdict.SEARCHING
		StateSolver.Status.SOLVED:
			verdict = Verdict.SAFE
			solution = _solver.solution
		StateSolver.Status.EXHAUSTED:
			verdict = Verdict.DOOMED
		StateSolver.Status.OUT_OF_BUDGET:
			verdict = Verdict.UNSURE
