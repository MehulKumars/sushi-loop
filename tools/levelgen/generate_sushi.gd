extends SceneTree
## Bakes data/levels/sushi_v2.json from the plan (tools/levelgen/sushi_plan.gd): levels 1-60 copied
## from the frozen first bake, every later level dealt again and again (seeded) until enough deals
## land in its band. Starts one worker process per spare CPU core (worker i bakes every Nth level
## of the list into build/levelgen/shard_i.jsonl), then merges the shards and writes the rating
## CSV and a summary (tools/levelgen/reports/). Same seeds, same levels: the result never depends
## on N. About 25 minutes for all 1000 levels on 14 workers.
## godot --headless --path . -s tools/levelgen/generate_sushi.gd [-- [first last] [--misses] [--workers N]]
##   first last: bake only that range; the other levels stay as baked.
##   --misses: bake again only the levels outside their band (after a band changed).

const OUT_PATH := "res://data/levels/sushi_v2.json"
const REPORT_CSV := "res://tools/levelgen/reports/sushi_v2.csv"
const REPORT_MD := "res://tools/levelgen/reports/sushi_v2.md"
const WORK_DIR := "res://build/levelgen"
const SELF := "res://tools/levelgen/generate_sushi.gd"
## The level ids this bake covers, for the workers.
const IDS_FILE := "res://build/levelgen/ids.json"
const HEADER := "id,role,twists,types,bentos,belt,open,window,counter,preview,par,star_peak,greedy,careful,pass,nodes,dead_ends,attempts,in_band,miss,ms"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "--worker":
		_worker(int(args[1]), int(args[2]))
		quit()
		return
	await _orchestrate(args)
	quit()


# --- Orchestrator ------------------------------------------------------------------------

func _orchestrate(args: PackedStringArray) -> void:
	var first := 1
	var last := SushiPlan.COUNT
	var workers := maxi(1, OS.get_processor_count() - 2)
	var misses := false
	var numbers: Array[int] = []
	var i := 0
	while i < args.size():
		if args[i] == "--workers" and i + 1 < args.size():
			workers = maxi(1, int(args[i + 1]))
			i += 1
		elif args[i] == "--misses":
			misses = true
		elif args[i].is_valid_int():
			numbers.append(int(args[i]))
		i += 1
	if numbers.size() >= 2:
		first = maxi(1, numbers[0])
		last = mini(SushiPlan.COUNT, numbers[1])
	var ids: Array[int] = []
	var baked_now := _existing()
	for id in range(first, last + 1):
		if not misses or not baked_now.has(id) or not _in_band(SushiLevel.from_dict(baked_now[id])):
			ids.append(id)
	if ids.is_empty():
		print("nothing to bake")
		return
	var work := ProjectSettings.globalize_path(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(work)
	for file in DirAccess.get_files_at(work):
		DirAccess.remove_absolute(work.path_join(file))
	var ids_file := FileAccess.open(IDS_FILE, FileAccess.WRITE)
	ids_file.store_string(JSON.stringify(ids))
	ids_file.close()
	var total := ids.size()
	workers = mini(workers, total)
	print("baking %d levels (%d-%d%s) with %d workers" % [total, first, last, ", misses only" if misses else "", workers])
	var started := Time.get_ticks_msec()
	var pids: Array[int] = []
	for index in workers:
		pids.append(OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", SELF, "--",
			"--worker", str(index), str(workers)]))
	var reported := -1
	while pids.any(func(pid: int) -> bool: return OS.is_process_running(pid)):
		await create_timer(5.0).timeout
		var done := _shard_lines(work).size()
		if done != reported:
			reported = done
			print("  %d / %d levels  (%ds)" % [done, total, (Time.get_ticks_msec() - started) / 1000])
	var lines := _shard_lines(work)
	var baked := _existing()
	var rows := _existing_rows()
	for line in lines:
		var entry: Dictionary = JSON.parse_string(line)
		baked[int(entry.level.id)] = entry.level
		rows[int(entry.level.id)] = str(entry.row)
	if lines.size() < total:
		push_error("only %d of %d levels baked: see %s/*.log" % [lines.size(), total, work])
	_write(baked)
	_write_csv(rows)
	_write_summary(baked)
	print("baked %d levels in %ds" % [lines.size(), (Time.get_ticks_msec() - started) / 1000])


func _shard_lines(work: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(work):
		if file.ends_with(".jsonl"):
			for line in FileAccess.get_file_as_string(work.path_join(file)).split("\n", false):
				out.append(line)
	return out


## Levels already baked (kept when baking only a range).
func _existing() -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	if FileAccess.file_exists(OUT_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT_PATH))
		if data is Dictionary:
			for d: Dictionary in data.get("levels", []):
				out[int(d.id)] = d
	return out


func _existing_rows() -> Dictionary[int, String]:
	var out: Dictionary[int, String] = {}
	if FileAccess.file_exists(REPORT_CSV):
		for line in FileAccess.get_file_as_string(REPORT_CSV).split("\n", false):
			var head := line.get_slice(",", 0)
			if head.is_valid_int():
				out[int(head)] = line
	return out


## One level per line, so diffs show which levels changed.
func _write(baked: Dictionary[int, Dictionary]) -> void:
	var ids := baked.keys()
	ids.sort()
	var lines := PackedStringArray()
	for id: int in ids:
		lines.append("\t\t" + JSON.stringify(baked[id]))
	var text := "{\n\t\"gen_version\": %d,\n\t\"levels\": [\n%s\n\t]\n}\n" % [SushiPlan.GEN_VERSION, ",\n".join(lines)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("wrote %d levels to %s (%d KB)" % [ids.size(), OUT_PATH, text.length() / 1024])


func _write_csv(rows: Dictionary[int, String]) -> void:
	var ids := rows.keys()
	ids.sort()
	var lines := PackedStringArray([HEADER])
	for id: int in ids:
		lines.append(rows[id])
	var file := FileAccess.open(REPORT_CSV, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


## Per role and per hundred levels: how the bots fare and the estimated pass rate, plus the
## levels that missed their band and the reskin-trap check.
func _write_summary(baked: Dictionary[int, Dictionary]) -> void:
	var levels: Array[SushiLevel] = []
	var ids := baked.keys()
	ids.sort()
	for id: int in ids:
		levels.append(SushiLevel.from_dict(baked[id]))
	var md := PackedStringArray(["# Sushi Loop levels (gen_version %d)" % SushiPlan.GEN_VERSION, ""])
	md.append("%d levels. Pass = %.1f x careful + %.1f x greedy: a rough first-try pass rate for a typical player." % [
			levels.size(), SushiPlan.CAREFUL_SHARE, 1.0 - SushiPlan.CAREFUL_SHARE])
	md.append("")
	md.append("## By role")
	md.append("")
	md.append("| Role | Levels | Greedy | Careful | Pass | Tries (1/pass) | Missed band |")
	md.append("|---|---|---|---|---|---|---|")
	for r: String in ["easy", "medium", "hard", "super", "rest"]:
		var group := levels.filter(func(l: SushiLevel) -> bool: return l.role == r)
		if group.is_empty():
			continue
		var g := _mean(group, func(l: SushiLevel) -> float: return l.greedy)
		var c := _mean(group, func(l: SushiLevel) -> float: return l.careful)
		var p := SushiPlan.pass_estimate(g, c)
		var missed := group.filter(func(l: SushiLevel) -> bool: return not _in_band(l))
		md.append("| %s | %d | %.2f | %.2f | %.2f | %.1f | %d |" % [r, group.size(), g, c, p, 1.0 / maxf(p, 0.01), missed.size()])
	md.append("")
	md.append("## By hundred")
	md.append("")
	md.append("| Levels | Pass (all) | Pass (no rest) | Hardest pass | Plates (avg) | Hard + super |")
	md.append("|---|---|---|---|---|---|")
	for start in range(0, levels.size(), 100):
		var group := levels.slice(start, start + 100)
		var work := group.filter(func(l: SushiLevel) -> bool: return l.role != "rest")
		var passes: Array[float] = []
		for l: SushiLevel in group:
			passes.append(SushiPlan.pass_estimate(l.greedy, l.careful))
		md.append("| %d-%d | %.2f | %.2f | %.2f | %.1f | %d |" % [group[0].id, group[-1].id,
				_mean(group, func(l: SushiLevel) -> float: return SushiPlan.pass_estimate(l.greedy, l.careful)),
				_mean(work, func(l: SushiLevel) -> float: return SushiPlan.pass_estimate(l.greedy, l.careful)),
				passes.min(), _mean(group, func(l: SushiLevel) -> float: return float(l.plate_count())),
				group.filter(func(l: SushiLevel) -> bool: return l.role == "hard" or l.role == "super").size()])
	md.append("")
	var misses := levels.filter(func(l: SushiLevel) -> bool: return not _in_band(l))
	md.append("## Missed bands (%d)" % misses.size())
	md.append("")
	for l: SushiLevel in misses:
		md.append("- L%d %s: greedy %.2f, careful %.2f, par %d" % [l.id, l.role, l.greedy, l.careful, l.par])
	var mid := levels.filter(func(l: SushiLevel) -> bool: return l.role != "rest" and (l.id - 1) % 10 >= 3 and (l.id - 1) % 10 <= 8)
	md.append("")
	md.append("Reskin check: greedy wins %.0f%% of mid-chapter runs on average (keep it under 90%%)." % [
			_mean(mid, func(l: SushiLevel) -> float: return l.greedy) * 100.0])
	var file := FileAccess.open(REPORT_MD, FileAccess.WRITE)
	file.store_string("\n".join(md) + "\n")
	file.close()
	print("\n".join(md.slice(0, 20)))


static func _in_band(level: SushiLevel) -> bool:
	if level.id <= SushiPlan.FROZEN_UNTIL:
		return true
	var band: Dictionary = SushiPlan.BANDS[level.role]
	return SushiGenerator._outside(level.greedy, band.greedy) <= 0.0 \
			and SushiGenerator._outside(level.careful, band.careful) <= 0.0 \
			and level.par >= int(band.par_min) \
			and SushiGenerator._care_shortfall(level) <= 0.0


static func _mean(items: Array, value: Callable) -> float:
	if items.is_empty():
		return 0.0
	var total := 0.0
	for item: Variant in items:
		total += float(value.call(item))
	return total / items.size()


# --- Worker ------------------------------------------------------------------------------

## Bakes every `workers`-th level of the id list (from IDS_FILE), starting at `index`, one JSON line
## per level, flushed as it goes so the orchestrator can count progress.
func _worker(index: int, workers: int) -> void:
	var work := ProjectSettings.globalize_path(WORK_DIR)
	var shard := FileAccess.open(work.path_join("shard_%02d.jsonl" % index), FileAccess.WRITE)
	var log_file := FileAccess.open(work.path_join("worker_%02d.log" % index), FileAccess.WRITE)
	var frozen := _frozen()
	var ids: Array = JSON.parse_string(FileAccess.get_file_as_string(IDS_FILE))
	for position in range(index, ids.size(), workers):
		var id := int(ids[position])
		var started := Time.get_ticks_msec()
		var spec := SushiPlan.spec(id)
		var level: SushiLevel = null
		var stats := {"nodes": 0, "dead_ends": 0, "attempts": 0, "in_band": 0, "miss": 0.0}
		if spec.frozen:
			level = SushiLevel.from_dict(frozen[id])
			var solver := StateSolver.run(SushiState.start(level), SushiGenerator.SOLVE_BUDGET)
			stats.nodes = solver.nodes
			stats.dead_ends = solver.dead_ends
		else:
			stats = SushiGenerator.search(spec)
			level = stats.level
		if level == null:
			log_file.store_line("L%d: no solvable deal in %d attempts" % [id, SushiGenerator.MAX_ATTEMPTS])
			log_file.flush()
			continue
		var ms := Time.get_ticks_msec() - started
		var row := "%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.3f,%.3f,%.3f,%d,%d,%d,%d,%.2f,%d" % [
			level.id, level.role, "+".join(spec.twists), level.type_count(), level.bentos.size(),
			level.belt.size(), level.open, level.window, level.counter, level.preview, level.par,
			level.star_peak, level.greedy, level.careful, SushiPlan.pass_estimate(level.greedy, level.careful),
			stats.nodes, stats.dead_ends, stats.attempts, stats.in_band, stats.miss, ms]
		shard.store_line(JSON.stringify({"level": level.to_dict(false), "row": row}))
		shard.flush()
		log_file.store_line(row)
		log_file.flush()
	shard.close()
	log_file.close()


func _frozen() -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SushiPlan.FROZEN_PATH))
	for d: Dictionary in (data as Dictionary).get("levels", []):
		out[int(d.id)] = d
	return out
