extends SceneTree
## Bakes data/levels/sushi_v1.json from tools/levelgen/sushi_plan.json: fixed tutorials as written,
## every other level dealt again and again (seeded) until enough deals land in its band, keeping the
## one nearest the band's middle. Writes tools/levelgen/reports/sushi_v1.csv and prints the
## reskin-trap check (greedy win rate on mid-chapter levels).
## Run: godot --headless --path . -s tools/levelgen/generate_sushi.gd [-- first_id last_id]

const PLAN_PATH := "res://tools/levelgen/sushi_plan.json"
const OUT_PATH := "res://data/levels/sushi_v1.json"
const REPORT_PATH := "res://tools/levelgen/reports/sushi_v1.csv"
const MAX_ATTEMPTS: int = 900
## Stop once this many deals are in the band.
const ENOUGH: int = 8
## Levels 1..this keep 3 stars for any clean win (star_peak = counter).
const GENTLE_LEVELS: int = 10

var _rows := PackedStringArray()


func _init() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	var bands: Dictionary = plan.bands
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var last := int(args[1]) if args.size() > 1 else 9999
	var baked: Dictionary[int, Dictionary] = _existing()
	_rows.append("id,role,types,bentos,belt,open,window,counter,preview,par,star_peak,greedy,careful,nodes,dead_ends,branching,attempts,in_band,spread")
	for entry: Dictionary in plan.levels:
		var id := int(entry.id)
		if id < first or id > last:
			if baked.has(id):
				continue
		var started := Time.get_ticks_msec()
		var level := _fixed(entry) if entry.has("fixed") else _search(entry, entry.get("band", bands[entry.role]))
		if level == null:
			push_error("level %d: no solvable deal in %d attempts" % [id, MAX_ATTEMPTS])
			continue
		baked[id] = level.to_dict()
		print("L%-3d %-6s types %d bentos %d belt %2d win %d ctr %d prev %d  par %d  greedy %.2f  careful %.2f  (%d ms)" % [
				id, level.role, level.type_count(), level.bentos.size(), level.belt.size(), level.window,
				level.counter, level.preview, level.par, level.greedy, level.careful, Time.get_ticks_msec() - started])
	_write(baked, int(plan.gen_version))
	_report(baked)
	quit()


func _fixed(entry: Dictionary) -> SushiLevel:
	var fixed: Dictionary = entry.fixed
	var level := SushiLevel.make(fixed.belt, fixed.bentos, int(fixed.open), int(fixed.window), int(fixed.counter))
	level.id = int(entry.id)
	level.role = entry.role
	level.preview = int(fixed.preview)
	assert(level.validate() == "", "level %d: %s" % [level.id, level.validate()])
	level.seed = SeedService.make_seed(["sushi", level.id, "fixed"], SushiGenerator.GEN_VERSION)
	var stats := SushiGenerator.rate(level, level.seed)
	assert(stats.solved, "fixed level %d is not solvable" % level.id)
	level.star_peak = level.counter
	_rows.append(_row(level, stats, 1, 1, -1.0))
	return level


func _search(entry: Dictionary, band: Dictionary) -> SushiLevel:
	var id := int(entry.id)
	var spread: Array = entry.get("spread", [0.3, 1.0])
	var best: SushiLevel = null
	var best_stats := {}
	var best_score := INF
	var best_spread := 0.0
	var in_band := 0
	var attempts := 0
	for attempt in MAX_ATTEMPTS:
		attempts = attempt + 1
		var rng := SeedService.make_rng(["sushi", id, attempt], SushiGenerator.GEN_VERSION)
		var spec := entry.duplicate()
		spec.spread = rng.randf_range(float(spread[0]), float(spread[1]))
		var level := SushiGenerator.deal(spec, rng)
		level.id = id
		level.role = entry.role
		level.seed = SeedService.make_seed(["sushi", id, attempt], SushiGenerator.GEN_VERSION)
		var solver := StateSolver.run(SushiState.start(level), SushiGenerator.SOLVE_BUDGET)
		if solver.status != StateSolver.Status.SOLVED:
			continue
		level.greedy = SushiBot.win_rate(level, SushiBot.GREEDY, SushiGenerator.RUNS, level.seed)
		var miss := _outside(level.greedy, band.greedy)
		if miss > 0.3 and best_score < INF:
			continue
		level.careful = SushiBot.win_rate(level, SushiBot.CAREFUL, SushiGenerator.RUNS, level.seed + 1)
		miss += _outside(level.careful, band.careful)
		if miss > 0.0 and miss >= best_score:
			continue
		level.par = SushiSolver.par(level, SushiGenerator.SOLVE_BUDGET)
		if level.par < int(band.get("par_min", 0)):
			miss += 0.25
		var score := miss
		if miss == 0.0:
			in_band += 1
			# In the band: prefer the middle of both ranges (always below any miss).
			score = -1.0 + _off_middle(level.greedy, band.greedy) + _off_middle(level.careful, band.careful)
		if score < best_score:
			best_score = score
			best = level
			best_spread = spec.spread
			best_stats = {"nodes": solver.nodes, "dead_ends": solver.dead_ends, "branching": solver.branching()}
		if in_band >= ENOUGH:
			break
	if best == null:
		return null
	if best_score >= 0.0:
		push_warning("level %d: best deal misses its band by %.2f" % [id, best_score])
	best.star_peak = best.counter if id <= GENTLE_LEVELS else mini(best.counter, best.par + 1)
	_rows.append(_row(best, best_stats, attempts, in_band, best_spread))
	return best


static func _outside(value: float, range_: Array) -> float:
	return maxf(0.0, float(range_[0]) - value) + maxf(0.0, value - float(range_[1]))


static func _off_middle(value: float, range_: Array) -> float:
	var lo := float(range_[0])
	var hi := float(range_[1])
	return absf(value - (lo + hi) * 0.5) / maxf(hi - lo, 0.01) * 0.1


func _row(level: SushiLevel, stats: Dictionary, attempts: int, in_band: int, spread: float) -> String:
	return "%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.3f,%.3f,%d,%d,%.2f,%d,%d,%.2f" % [
		level.id, level.role, level.type_count(), level.bentos.size(), level.belt.size(), level.open,
		level.window, level.counter, level.preview, level.par, level.star_peak, level.greedy,
		level.careful, stats.get("nodes", 0), stats.get("dead_ends", 0), stats.get("branching", 0.0),
		attempts, in_band, spread]


## Levels already baked (kept when regenerating only a range of ids).
func _existing() -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	if not FileAccess.file_exists(OUT_PATH):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT_PATH))
	if data is Dictionary:
		for d: Dictionary in data.get("levels", []):
			out[int(d.id)] = d
	return out


## One level per line, so diffs show which levels changed.
func _write(baked: Dictionary[int, Dictionary], gen_version: int) -> void:
	var ids := baked.keys()
	ids.sort()
	var lines := PackedStringArray()
	for id: int in ids:
		lines.append("\t\t" + JSON.stringify(baked[id]))
	var text := "{\n\t\"gen_version\": %d,\n\t\"levels\": [\n%s\n\t]\n}\n" % [gen_version, ",\n".join(lines)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("wrote %d levels to %s" % [ids.size(), OUT_PATH])


func _report(baked: Dictionary[int, Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string("\n".join(_rows) + "\n")
	file.close()
	# The reskin trap (docs/SUSHI_LOOP.md): greedy on levels 4-9 of each chapter, rest levels aside.
	var total := 0.0
	var count := 0
	var high := PackedStringArray()
	for id: int in baked:
		if id % 10 >= 4 and id % 10 <= 9 and baked[id].role != "rest":
			var greedy := float(baked[id].greedy)
			total += greedy
			count += 1
			if greedy > 0.9:
				high.append(str(id))
	if count > 0:
		print("reskin check: greedy wins %.0f%% of mid-chapter runs on average; above 90%%: %s" % [
				total / count * 100.0, ", ".join(high) if not high.is_empty() else "none"])
