class_name SushiBot
extends RefCounted
## Bots that rate levels (docs/SUSHI_LOOP.md). GREEDY takes a fitting plate at random, else any
## plate at random: if it wins most mid-chapter levels, the window is not creating choices.
## CAREFUL plays the exit and the visible queue; in play() it slips into a greedy move one take in
## SLIP, so its win rate is graded instead of all-or-nothing.

const GREEDY: int = 0
const CAREFUL: int = 1
## Mindless players: always the plate at the exit end of the window, or always the one that just
## came in. A level either of them wins needs no thought (the bake keeps them losing).
const SPAM_EXIT: int = 2
const SPAM_ENTRY: int = 3
## CAREFUL without its slips: the "take what fits" rule played perfectly.
const CAREFUL_PURE: int = 4
## Chance per take that the careful bot plays a greedy move instead.
const SLIP: float = 0.1
const NOT_SHOWN: int = 99


## The window position the bot takes, -1 if the level is over.
static func choose(state: SushiState, kind: int, rng: RandomNumberGenerator) -> int:
	if state.is_over():
		return -1
	if kind == SPAM_EXIT or kind == SPAM_ENTRY:
		var order := range(state.window)
		if kind == SPAM_EXIT:
			order.reverse()
		for w: int in order:
			if state.window_plate(w) >= 0:
				return w
		return -1
	var fitting: Array[int] = []
	var others: Array[int] = []
	for w in state.window:
		var plate := state.window_plate(w)
		if plate < 0:
			continue
		if state.fits(state.plate_type(plate)):
			fitting.append(w)
		else:
			others.append(w)
	if fitting.is_empty() and others.is_empty():
		return -1
	if kind == GREEDY:
		var pool := fitting if not fitting.is_empty() else others
		return pool[rng.randi_range(0, pool.size() - 1)]
	if not fitting.is_empty():
		return fitting.max()
	var best := -1
	var best_score := Vector3i(NOT_SHOWN + 1, 0, 0)
	for w in others:
		var type := state.plate_type(state.window_plate(w))
		# Lower is better: how soon its bento opens, then more of its kind waiting, then the exit.
		var score := Vector3i(_soonest_shown(state, type), -state.counter.count_kind(state.types, type), -w)
		if score < best_score:
			best_score = score
			best = w
	return best


static func play(level: SushiLevel, kind: int, rng: RandomNumberGenerator) -> bool:
	var state := SushiState.start(level)
	while not state.is_over():
		var policy := kind
		if kind == CAREFUL and rng.randf() < SLIP:
			policy = GREEDY
		elif kind == CAREFUL_PURE:
			policy = CAREFUL
		var w := choose(state, policy, rng)
		if w < 0:
			return false
		state.take(w)
	return state.is_won()


## True if the mindless or rule-of-thumb player `kind` (SPAM_EXIT, SPAM_ENTRY, CAREFUL_PURE) wins.
static func wins(level: SushiLevel, kind: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return play(level, kind, rng)


static func win_rate(level: SushiLevel, kind: int, runs: int, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	for run in runs:
		if play(level, kind, rng):
			wins += 1
	return float(wins) / float(runs) if runs > 0 else 0.0


## How many bentos ahead the first queued bento of `type` is (0 = opens next), NOT_SHOWN if it is
## not among the `preview` bentos the player can see.
static func _soonest_shown(state: SushiState, type: int) -> int:
	for ahead in state.preview:
		var index := state.next_bento + ahead
		if index >= state.queue.size():
			break
		if state.queue[index] == type:
			return ahead
	return NOT_SHOWN
