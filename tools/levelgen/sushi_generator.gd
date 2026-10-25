class_name SushiGenerator
extends RefCounted
## Offline Sushi Loop level generator (docs/SUSHI_LOOP.md "Levels"): deals a bento queue and a belt
## from a seeded RNG, then rates the deal with the solver (solvable, par, search size) and the bots
## (200 runs each). Used by tools/levelgen/generate_sushi.gd and bench_sushi.gd; never at run time.

const GEN_VERSION: int = 1
const RUNS: int = 200
const SOLVE_BUDGET: int = 150_000


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
