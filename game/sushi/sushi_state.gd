class_name SushiState
extends SolverState
## The Sushi Loop rules (docs/SUSHI_LOOP.md R1-R8) for one level: a belt of plates that steps on
## every take, open bentos fed from a queue, and the counter (a Rack of plate ids). Copyable and
## searchable by StateSolver. With `record` on, take() and continue_game() log events for the view.

const NONE: int = -1
const BENTO_SIZE: int = 3

## Plate type per plate id (= belt slot), -1 for an empty slot. Shared between copies.
var types := PackedInt32Array()
## Bento types in queue order. Shared between copies.
var queue := PackedInt32Array()
var window: int = 3
## Queued bentos the player can see after the open ones (the careful bot plans with them).
var preview: int = 0
## Bit i set: plate i is still on the belt.
var belt_mask: int = 0
var offset: int = 0
var counter := Rack.new()
## Index in `queue` of the next bento to open.
var next_bento: int = 0
## Per open slot: the queue index of its bento, or -1 when empty.
var open_bento := PackedInt32Array()
## BENTO_SIZE cells per open slot: the plate ids packed so far, -1 for an empty cell.
var open_plates := PackedInt32Array()
var closed: int = 0
var lost: bool = false
## The plate that overflowed (it waits above the counter), -1 when none.
var held: int = NONE
## Most plates the counter has held at once.
var peak: int = 0
var continues: int = 0
var record: bool = false
## {"kind": take|pack|counter|close|open|advance|lost|won, ...} in the order they happened.
var events: Array[Dictionary] = []


static func start(level: SushiLevel) -> SushiState:
	var state := SushiState.new()
	state.types = level.belt
	state.queue = level.bentos
	state.window = level.window
	state.preview = level.preview
	state.counter = Rack.new(level.counter)
	for i in level.belt.size():
		if level.belt[i] >= 0:
			state.belt_mask |= 1 << i
	state.open_bento.resize(level.open)
	state.open_bento.fill(NONE)
	state.open_plates.resize(level.open * BENTO_SIZE)
	state.open_plates.fill(NONE)
	for slot in level.open:
		state._open_next(slot)
	state._roll_on()
	return state


func copy() -> SushiState:
	var state := SushiState.new()
	state.types = types
	state.queue = queue
	state.window = window
	state.preview = preview
	state.belt_mask = belt_mask
	state.offset = offset
	state.counter = counter.copy()
	state.next_bento = next_bento
	state.open_bento = open_bento.duplicate()
	state.open_plates = open_plates.duplicate()
	state.closed = closed
	state.lost = lost
	state.held = held
	state.peak = peak
	state.continues = continues
	return state


func belt_size() -> int:
	return types.size()


func plate_type(plate: int) -> int:
	return types[plate] if plate >= 0 and plate < types.size() else NONE


func on_belt(plate: int) -> bool:
	return plate >= 0 and plate < types.size() and (belt_mask >> plate) & 1 == 1


func plates_on_belt() -> int:
	var count := 0
	var mask := belt_mask
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count


## Where plate `plate` is on the ring (0 .. window-1 is the pick window).
func ring_position(plate: int) -> int:
	return posmod(plate + offset, types.size())


## The plate at window position `w`, or -1 (empty slot or outside the window).
func window_plate(w: int) -> int:
	if w < 0 or w >= window:
		return NONE
	var plate := posmod(w - offset, types.size())
	return plate if on_belt(plate) else NONE


func open_count() -> int:
	return open_bento.size()


## The bento type in open slot `slot`, -1 when the slot is empty.
func open_type(slot: int) -> int:
	var index := open_bento[slot]
	return queue[index] if index >= 0 else NONE


func open_fill(slot: int) -> int:
	var fill := 0
	for cell in BENTO_SIZE:
		if open_plates[slot * BENTO_SIZE + cell] >= 0:
			fill += 1
	return fill


## True if an open bento takes plates of `type`.
func fits(type: int) -> bool:
	for slot in open_bento.size():
		if open_type(slot) == type:
			return true
	return false


func is_won() -> bool:
	return closed == queue.size()


func is_over() -> bool:
	return lost or is_won()


## Takes the plate at window position `w` (R3); false if there is none or the level is over.
func take(w: int) -> bool:
	if is_over():
		return false
	var plate := window_plate(w)
	if plate < 0:
		return false
	belt_mask &= ~(1 << plate)
	if record:
		events.append({"kind": &"take", "plate": plate, "position": w})
	if not _route(plate):
		lost = true
		held = plate
		if record:
			events.append({"kind": &"lost", "plate": plate})
		return true
	_advance()
	if record and is_won():
		events.append({"kind": &"won"})
	return true


## R8: after a loss, `extra` more counter slots, the held plate goes on the counter, the belt steps.
func continue_game(extra: int = 2) -> bool:
	if not lost:
		return false
	lost = false
	continues += 1
	counter.capacity += extra
	var plate := held
	held = NONE
	if record:
		events.append({"kind": &"continue", "extra": extra})
	_to_counter(plate)
	_advance()
	return true


func solver_key() -> int:
	var key := belt_mask | (posmod(offset, types.size()) << 32)
	var shift := 37
	for slot in open_bento.size():
		key |= ((open_bento[slot] + 1) | (open_fill(slot) << 6)) << shift
		shift += 8
	return key


## Window positions with a plate: fitting plates first, each group nearest the exit first.
func solver_moves() -> PackedInt32Array:
	var moves := PackedInt32Array()
	if is_over():
		return moves
	var rest := PackedInt32Array()
	for w in range(window - 1, -1, -1):
		var plate := window_plate(w)
		if plate < 0:
			continue
		if fits(types[plate]):
			moves.append(w)
		else:
			rest.append(w)
	moves.append_array(rest)
	return moves


func solver_child(move: int) -> SolverState:
	var child := copy()
	if not child.take(move) or child.lost:
		return null
	return child


func solver_goal() -> bool:
	return is_won()


## R4: into the fullest open bento of its type, else onto the counter; false on overflow.
func _route(plate: int) -> bool:
	var type := types[plate]
	var best := NONE
	var best_fill := -1
	for slot in open_bento.size():
		if open_type(slot) == type:
			var fill := open_fill(slot)
			if fill > best_fill:
				best = slot
				best_fill = fill
	if best >= 0:
		_pack(best, plate, &"belt")
		return true
	if counter.is_full():
		return false
	_to_counter(plate)
	return true


func _to_counter(plate: int) -> void:
	counter.push(plate)
	peak = maxi(peak, counter.size())
	if record:
		events.append({"kind": &"counter", "plate": plate, "index": counter.size() - 1})


func _pack(slot: int, plate: int, source: StringName) -> void:
	var cell := open_fill(slot)
	open_plates[slot * BENTO_SIZE + cell] = plate
	if record:
		events.append({"kind": &"pack", "plate": plate, "slot": slot, "cell": cell, "from": source})
	if cell + 1 == BENTO_SIZE:
		_close(slot)


## R6: the bento leaves, the next one opens in its slot and the counter cascades into it.
func _close(slot: int) -> void:
	closed += 1
	if record:
		var plates := open_plates.slice(slot * BENTO_SIZE, (slot + 1) * BENTO_SIZE)
		events.append({"kind": &"close", "slot": slot, "bento": open_bento[slot], "plates": plates})
	_open_next(slot)


func _open_next(slot: int) -> void:
	for cell in BENTO_SIZE:
		open_plates[slot * BENTO_SIZE + cell] = NONE
	if next_bento >= queue.size():
		open_bento[slot] = NONE
		return
	open_bento[slot] = next_bento
	next_bento += 1
	if record:
		events.append({"kind": &"open", "slot": slot, "bento": open_bento[slot]})
	for plate in counter.drain(types, queue[open_bento[slot]], BENTO_SIZE):
		_pack(slot, plate, &"counter")


## R5: one step, then on past empty stretches.
func _advance() -> void:
	offset += 1
	var steps := 1 + _roll_on()
	if record:
		events.append({"kind": &"advance", "steps": steps})


func _roll_on() -> int:
	var steps := 0
	while belt_mask != 0 and not _window_has_plate():
		offset += 1
		steps += 1
	return steps


func _window_has_plate() -> bool:
	for w in window:
		if window_plate(w) >= 0:
			return true
	return false
