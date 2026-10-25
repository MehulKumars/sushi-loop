class_name SushiRun
extends RefCounted
## One attempt at a level for the game screen: the state plus undo history (R9), the free rewind
## to the last state the doom detector proved solvable, continues and stars. A continue's extra
## counter slots survive undo, so the player never loses what the video gave.

const FREE_UNDOS: int = 1
const CONTINUE_SLOTS: int = 2

var level: SushiLevel
var state: SushiState
## The current state is proven solvable (set by the doom detector through mark_safe()).
var safe: bool = false
var continues: int = 0
## Passed to every state this run plays, so the view gets events after undo too.
var record: bool = false:
	set(value):
		record = value
		state.record = value

var _history: Array[SushiState] = []
var _history_safe: Array[bool] = []
var _free_undos: int = FREE_UNDOS


func _init(level_data: SushiLevel) -> void:
	level = level_data
	state = SushiState.start(level_data)


func take(w: int) -> bool:
	if state.is_over() or state.window_plate(w) < 0:
		return false
	_history.append(state.copy())
	_history_safe.append(safe)
	safe = false
	state.events.clear()
	return state.take(w)


func can_undo() -> bool:
	return not _history.is_empty()


func undos_left() -> int:
	return _free_undos


## Back one take: the free undo, or an extra one (`extra`, after a rewarded video).
func undo(extra: bool = false) -> bool:
	if _history.is_empty():
		return false
	if not extra:
		if _free_undos <= 0:
			return false
		_free_undos -= 1
	var was_safe: bool = _history_safe.pop_back()
	_restore(_history.pop_back())
	safe = was_safe
	return true


func mark_safe() -> void:
	safe = true


## Back to the most recent state proven solvable (or the start), for free. False if already there.
func rewind_to_safe() -> bool:
	if safe or _history.is_empty():
		return false
	while not _history.is_empty():
		var previous: SushiState = _history.pop_back()
		var was_safe: bool = _history_safe.pop_back()
		if was_safe or _history.is_empty():
			_restore(previous)
			safe = was_safe
			return true
	return false


## R8 after a loss; the history keeps the extra slots.
func continue_game() -> bool:
	state.events.clear()
	if not state.continue_game(CONTINUE_SLOTS):
		return false
	continues += 1
	safe = false
	return true


## 3: clean win within the star peak; 2: clean win; 1: won after a continue; 0: not won yet.
func stars() -> int:
	if not state.is_won():
		return 0
	if continues > 0:
		return 1
	return 3 if state.peak <= level.star_peak else 2


func _restore(previous: SushiState) -> void:
	previous.counter.capacity = level.counter + continues * CONTINUE_SLOTS
	previous.continues = continues
	previous.record = record
	previous.events.clear()
	state = previous
