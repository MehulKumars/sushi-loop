class_name SushiGenerator
extends RefCounted
## Offline Sushi Loop level generator (docs/SUSHI_LOOP.md "Levels"): deals a bento queue and a belt
## from a seeded RNG, rates the deal with the solver (solvable, par, search size) and the bots
## (200 runs each), and searches deals until one lands in the plan's band (search()).
## Used by tools/levelgen/generate_sushi.gd and bench_sushi.gd; never at run time.

const GEN_VERSION: int = SushiPlan.GEN_VERSION
const RUNS: int = 200
const SOLVE_BUDGET: int = 150_000
## Deals tried per level before keeping the nearest miss.
const MAX_ATTEMPTS: int = 900
## Stop once this many deals are in the band.
const ENOUGH: int = 8
## A quick look first: after QUICK_RUNS runs, a deal more than QUICK_MARGIN outside its band is
## dropped without the remaining runs (the full count only goes to deals that may fit).
const QUICK_RUNS: int = 40
const QUICK_MARGIN: float = 0.2


## When the planned knobs land no deal in the band, search() tries these counter steps (from the
## planned counter) crossed with SPREAD_TRIES, ATTEMPTS_PER_TRY deals each. Which way helps depends
## on the twists (one bento and a two-plate window may need plates in better order to get harder),
## so the grid is tried rather than guessed.
const COUNTER_STEPS: Array[int] = [0, -1, 1, -2, 2]
const SPREAD_TRIES: Array[Array] = [[0.1, 0.5], [0.3, 0.8], [0.6, 1.0]]
const ATTEMPTS_PER_TRY: int = 300
## A kept level's careful win rate is never below this (no level is one narrow line).
const CAREFUL_FLOOR: float = 0.35
## On hard and super-hard levels the careful bot beats the greedy one by more than this.
const CARE_PAYS: float = 0.2


## Deals level `spec.id` (SushiPlan.spec()) until ENOUGH deals land in its band and keeps the one
## nearest the band's middle. With no deal in the band, tries the counter and spread grid
## (COUNTER_STEPS x SPREAD_TRIES) until one lands, keeping the nearest miss otherwise. Returns
## {"level": SushiLevel or null, "nodes", "dead_ends", "attempts", "in_band", "miss" (0 when in
## the band), "rounds"}.
static func search(spec: Dictionary) -> Dictionary:
	var tries: Array[Dictionary] = [spec]
	for step in COUNTER_STEPS:
		for spread in SPREAD_TRIES:
			var counter := int(spec.counter) + step
			if counter < 3 or counter > 7:
				continue
			var variant := spec.duplicate()
			variant.counter = counter
			variant.spread = spread
			tries.append(variant)
	var best := {}
	var attempts := 0
	for round_ in tries.size():
		var found := _search_round(tries[round_], round_, MAX_ATTEMPTS if round_ == 0 else ATTEMPTS_PER_TRY)
		attempts += int(found.attempts)
		var level: SushiLevel = found.level
		if level != null and level.careful >= CAREFUL_FLOOR and (best.is_empty() or found.miss < best.miss):
			best = found
			best.rounds = round_ + 1
		if not best.is_empty() and best.miss == 0.0:
			break
	if best.is_empty():
		return {"level": null, "nodes": 0, "dead_ends": 0, "attempts": attempts, "in_band": 0, "miss": 0.0, "rounds": tries.size()}
	best.attempts = attempts
	return best


static func _search_round(spec: Dictionary, round_: int, max_attempts: int = MAX_ATTEMPTS) -> Dictionary:
	var id: int = spec.id
	var band: Dictionary = spec.band
	var spread: Array = spec.spread
	var best: SushiLevel = null
	var best_score := INF
	var out := {"level": null, "nodes": 0, "dead_ends": 0, "attempts": 0, "in_band": 0, "miss": 0.0}
	for attempt in max_attempts:
		out.attempts = attempt + 1
		var rng := SeedService.make_rng(["sushi", id, round_, attempt], GEN_VERSION)
		var deal_spec := spec.duplicate()
		deal_spec.spread = rng.randf_range(float(spread[0]), float(spread[1]))
		var level := deal(deal_spec, rng)
		level.id = id
		level.role = spec.role
		level.seed = SeedService.make_seed(["sushi", id, round_, attempt], GEN_VERSION)
		var solver := StateSolver.run(SushiState.start(level), SOLVE_BUDGET)
		if solver.status != StateSolver.Status.SOLVED:
			continue
		level.greedy = _quick_rate(level, SushiBot.GREEDY, level.seed, band.greedy)
		var miss := _outside(level.greedy, band.greedy)
		if miss > 0.3 and best_score < INF:
			continue
		level.careful = _quick_rate(level, SushiBot.CAREFUL, level.seed + 1, band.careful)
		miss += _outside(level.careful, band.careful)
		if miss > 0.0 and miss >= best_score:
			continue
		level.par = SushiSolver.par(level, SOLVE_BUDGET)
		if level.par < 0:
			continue
		if level.par < int(band.get("par_min", 0)):
			miss += 0.25
		miss += _care_shortfall(level)
		var score := miss
		if miss == 0.0:
			out.in_band += 1
			# In the band: prefer the middle of both ranges (always below any miss).
			score = -1.0 + _off_middle(level.greedy, band.greedy) + _off_middle(level.careful, band.careful)
		if score < best_score:
			best_score = score
			best = level
			out.nodes = solver.nodes
			out.dead_ends = solver.dead_ends
		if out.in_band >= ENOUGH:
			break
	if best == null:
		return out
	# A miss may carry a quick estimate: rate the keeper in full.
	best.greedy = SushiBot.win_rate(best, SushiBot.GREEDY, RUNS, best.seed)
	best.careful = SushiBot.win_rate(best, SushiBot.CAREFUL, RUNS, best.seed + 1)
	best.star_peak = mini(best.counter, best.par + 1)
	out.level = best
	out.miss = maxf(best_score, 0.0)
	return out


## How far a hard or super-hard level falls short of rewarding care (0 when careful play wins
## more than CARE_PAYS above greedy play, and on other roles).
static func _care_shortfall(level: SushiLevel) -> float:
	if level.role != "hard" and level.role != "super":
		return 0.0
	return maxf(0.0, CARE_PAYS + 0.01 - (level.careful - level.greedy))


## The bot's win rate over RUNS runs, or over QUICK_RUNS when that is already far outside `range_`.
static func _quick_rate(level: SushiLevel, kind: int, seed: int, range_: Array) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	for run in RUNS:
		if SushiBot.play(level, kind, rng):
			wins += 1
		if run + 1 == QUICK_RUNS:
			var quick := float(wins) / float(QUICK_RUNS)
			if _outside(quick, range_) > QUICK_MARGIN:
				return quick
	return float(wins) / float(RUNS)


static func _outside(value: float, range_: Array) -> float:
	return maxf(0.0, float(range_[0]) - value) + maxf(0.0, value - float(range_[1]))


static func _off_middle(value: float, range_: Array) -> float:
	var lo := float(range_[0])
	var hi := float(range_[1])
	return absf(value - (lo + hi) * 0.5) / maxf(hi - lo, 0.01) * 0.1


## A deal for `spec` ({types, bentos, belt, open, window, counter, preview, spread}). `spread` (0-1)
## is how far plates stray from the order their bentos open in: 0 = in order (easy), 1 = random.
static func deal(spec: Dictionary, rng: RandomNumberGenerator) -> SushiLevel:
	var types: int = spec.types
	var count: int = spec.bentos
	var size: int = spec.belt
	var window: int = spec.get("window", 3)
	var spread: float = spec.get("spread", 1.0)
	var queue := _queue(types, count, rng)
	# Each plate gets a sort key near its bento's place in the queue; `spread` blurs it.
	var plates: Array[Vector2] = []
	for index in queue.size():
		for copy in SushiState.BENTO_SIZE:
			var noise := rng.randf() * float(queue.size()) * spread
			plates.append(Vector2(float(index) * (1.0 - spread) + noise + rng.randf() * 0.5, queue[index]))
	plates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	# Empty slots are spread through the stream, never in the first window.
	var stream := _stream_order(size, window)
	var empties := size - plates.size()
	var gaps := PackedInt32Array()
	var candidates: Array[int] = []
	for i in range(window, size):
		candidates.append(i)
	for i in empties:
		var pick := rng.randi_range(0, candidates.size() - 1)
		gaps.append(candidates[pick])
		candidates.remove_at(pick)
	var belt := PackedInt32Array()
	belt.resize(size)
	belt.fill(-1)
	var next := 0
	for position in size:
		if gaps.has(position):
			continue
		belt[stream[position]] = int(plates[next].y)
		next += 1
	var level := SushiLevel.make(Array(belt), Array(queue), spec.get("open", 2), window, spec.get("counter", 5))
	level.preview = spec.get("preview", 2)
	return level


## Rates `level` in place (par, star peak, bot win rates) and returns the search stats:
## {"solved": bool, "nodes": int, "dead_ends": int, "branching": float}.
static func rate(level: SushiLevel, seed: int, star_peak_slack: int = 1) -> Dictionary:
	var solver := StateSolver.run(SushiState.start(level), SOLVE_BUDGET)
	var stats := {
		"solved": solver.status == StateSolver.Status.SOLVED,
		"nodes": solver.nodes,
		"dead_ends": solver.dead_ends,
		"branching": solver.branching(),
	}
	if not stats.solved:
		return stats
	level.par = SushiSolver.par(level, SOLVE_BUDGET)
	level.star_peak = level.counter if level.par < 0 else mini(level.counter, level.par + star_peak_slack)
	level.greedy = SushiBot.win_rate(level, SushiBot.GREEDY, RUNS, seed)
	level.careful = SushiBot.win_rate(level, SushiBot.CAREFUL, RUNS, seed + 1)
	return stats


## The slots in the order their plates pass the exit: the first window from its exit back to
## position 0, then the slots that enter after it (N-1, N-2, ...).
static func _stream_order(size: int, window: int) -> PackedInt32Array:
	var order := PackedInt32Array()
	for w in range(window - 1, -1, -1):
		order.append(w)
	for slot in range(size - 1, window - 1, -1):
		order.append(slot)
	return order


## `count` bento types using each of types 0..types-1 at least once, shuffled; the first two
## differ when possible so two open bentos never start as twins.
static func _queue(types: int, count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var list: Array[int] = []
	for t in types:
		list.append(t)
	while list.size() < count:
		list.append(rng.randi_range(0, types - 1))
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := list[i]
		list[i] = list[j]
		list[j] = swap
	if list.size() > 1 and list[0] == list[1]:
		for i in range(2, list.size()):
			if list[i] != list[0]:
				var swap := list[1]
				list[1] = list[i]
				list[i] = swap
				break
	return PackedInt32Array(list)
