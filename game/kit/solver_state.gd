class_name SolverState
extends RefCounted
## Base for a puzzle state that StateSolver can search: override the four solver_* methods.
## Moves are small ints the state defines (a window slot, a tube index...). The solver never
## changes a state it was given: solver_child() returns a new one.


## A number unique to this state among the states the search can reach (the dead-state memo).
func solver_key() -> int:
	return 0


## The moves worth trying from here, most promising first (the search tries them in order).
func solver_moves() -> PackedInt32Array:
	return PackedInt32Array()


## The state after `move`, or null if the move is illegal or loses at once.
func solver_child(_move: int) -> SolverState:
	return null


func solver_goal() -> bool:
	return false
