class_name SushiState
extends SolverState
## The Sushi Loop rules (docs/SUSHI_LOOP.md R1-R8, M1-M3) for one level: a belt of plates that
## steps on every take, open bentos fed from a queue (some of them rush orders), covered dishes,
## chef's specials, and the counter (a Rack of plate ids). Copyable and searchable by StateSolver.
## With `record` on, take() and continue_game() log events for the view.

const NONE: int = -1
const BENTO_SIZE: int = 3
const WILD: int = SushiLevel.WILD
## Takes a continue gives a rush order that ran out (M2).
const RUSH_EXTRA: int = 5

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
## Bit i set: plate i is covered (M1). Shared between copies.
var covers: int = 0
## Bit i set: plate i has been in the window, so its cloche is off.
var revealed: int = 0
## Per queued bento: its rush limit (M2), 0 = none. Shared between copies.
var rush_limits := PackedInt32Array()
## Per open slot: takes left for its rush order, -1 when it does not rush.
var rush_left := PackedInt32Array()
## Why the level was lost: &"overflow" (R4) or &"rush" (M2); &"" while it is not.
var lost_reason: StringName = &""
## The open slot whose rush order ran out, -1 when none.
var rush_slot: int = NONE
## The level has chef's specials (the search key then also covers the counter). Shared.
var has_wild: bool = false
var record: bool = false
## {"kind": take|pack|counter|close|open|advance|reveal|lost|rush_out|won, ...} in order.
var events: Array[Dictionary] = []
## Open slots that opened during the current take (their rush count starts with the next one).
var _fresh: int = 0


static func start(level: SushiLevel) -> SushiState:
	var state := SushiState.new()
	state.types = level.belt
	state.queue = level.bentos
	state.window = level.window
	state.preview = level.preview
	state.counter = Rack.new(level.counter)
	state.covers = level.covers
	state.rush_limits = level.rush
	state.has_wild = level.belt.has(WILD)
	for i in level.belt.size():
		if level.belt[i] >= 0:
			state.belt_mask |= 1 << i
	state.open_bento.resize(level.open)
	state.open_bento.fill(NONE)
	state.rush_left.resize(level.open)
	state.rush_left.fill(NONE)
	state.open_plates.resize(level.open * BENTO_SIZE)
	state.open_plates.fill(NONE)
	for slot in level.open:
		state._open_next(slot)
	state._roll_on()
	state._reveal()
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
	state.covers = covers
	state.revealed = revealed
	state.rush_limits = rush_limits
	state.rush_left = rush_left.duplicate()
	state.lost_reason = lost_reason
	state.rush_slot = rush_slot
	state.has_wild = has_wild
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


## True while plate `plate` still wears its cloche (M1): covered and not yet in the window.
func is_covered(plate: int) -> bool:
	return (covers >> plate) & 1 == 1 and (revealed >> plate) & 1 == 0


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


## True if an open bento takes plates of `type` (a chef's special fits any open bento).
func fits(type: int) -> bool:
	for slot in open_bento.size():
		if open_type(slot) == type or (type == WILD and open_bento[slot] >= 0):
			return true
	return false


## Takes left for the rush order in open slot `slot`, -1 when it does not rush.
func rush_of(slot: int) -> int:
	return rush_left[slot] if slot >= 0 and slot < rush_left.size() and open_bento[slot] >= 0 else NONE


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
	_fresh = 0
	if record:
		events.append({"kind": &"take", "plate": plate, "position": w})
	if not _route(plate):
		lost = true
		lost_reason = &"overflow"
		held = plate
		if record:
			events.append({"kind": &"lost", "plate": plate})
		return true
	_advance()
	_tick_rush()
	if record and is_won():
		events.append({"kind": &"won"})
	return true


## R8: after an overflow, `extra` more counter slots, the held plate goes on the counter and the
## belt steps; after a missed rush order (M2), that bento gets RUSH_EXTRA more takes.
func continue_game(extra: int = 2) -> bool:
	if not lost:
		return false
	lost = false
	continues += 1
	if lost_reason == &"rush":
		lost_reason = &""
		rush_left[rush_slot] += RUSH_EXTRA
		rush_slot = NONE
		if record:
			events.append({"kind": &"continue", "extra": 0})
		return true
	lost_reason = &""
	counter.capacity += extra
	var plate := held
	held = NONE
	if record:
		events.append({"kind": &"continue", "extra": extra})
	_to_counter(plate)
	_advance()
	return true


## Belt (32 bits), offset (5), per open slot its bento and fill (8 each) and rush count (5 each).
## With chef's specials the counter's dishes are not implied by the rest, so they are mixed in.
func solver_key() -> int:
	var key := belt_mask | (posmod(offset, types.size()) << 32)
	var shift := 37
	for slot in open_bento.size():
		key |= ((open_bento[slot] + 1) | (open_fill(slot) << 6)) << shift
		shift += 8
	for slot in open_bento.size():
		key |= (rush_left[slot] + 1) << shift
		shift += 5
	if has_wild:
		var dishes := 0
		for plate in counter.items:
			dishes += 1 << (3 * types[plate])
		key = _mix(key) ^ _mix(dishes + 0x5bd1e995)
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


## R4: into the fullest open bento of its type (M3: a chef's special into the fullest open bento
## of any type), else onto the counter; false on overflow.
func _route(plate: int) -> bool:
	var type := types[plate]
	var best := NONE
	var best_fill := -1
	for slot in open_bento.size():
		if open_type(slot) == type or (type == WILD and open_bento[slot] >= 0):
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
		rush_left[slot] = NONE
		return
	open_bento[slot] = next_bento
	var limit := rush_limits[next_bento] if next_bento < rush_limits.size() else 0
	rush_left[slot] = limit if limit > 0 else NONE
	_fresh |= 1 << slot
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
	_reveal()


## M1: covered plates in the window lose their cloche for good.
func _reveal() -> void:
	if covers == 0:
		return
	for w in window:
		var plate := window_plate(w)
		if plate >= 0 and is_covered(plate):
			revealed |= 1 << plate
			if record:
				events.append({"kind": &"reveal", "plate": plate})


## M2: after a take, every rush order still open (and not just opened) has one take fewer; one
## that reaches 0 loses the level.
func _tick_rush() -> void:
	if is_won():
		return
	for slot in open_bento.size():
		if open_bento[slot] < 0 or rush_left[slot] < 0 or (_fresh >> slot) & 1 == 1:
			continue
		rush_left[slot] -= 1
		if rush_left[slot] <= 0:
			lost = true
			lost_reason = &"rush"
			rush_slot = slot
			if record:
				events.append({"kind": &"rush_out", "slot": slot})
			return


## splitmix64's finaliser: spreads a key's bits so mixed keys rarely collide.
static func _mix(x: int) -> int:
	x = (x ^ (x >> 30)) * -4658895280553007687
	x = (x ^ (x >> 27)) * -7723592293110705685
	return x ^ (x >> 31)


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
