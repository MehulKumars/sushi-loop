extends SceneTree
## Samples deals for a few knob settings and prints how hard they come out (solvable share, par,
## greedy and careful win rates, search size), to choose the bands in sushi_plan.json.
## Run: godot --headless --path . -s tools/levelgen/bench_sushi.gd [-- samples]

const SPECS: Array[Dictionary] = [
	{"name": "c1 easy", "types": 2, "bentos": 4, "belt": 14, "open": 2, "window": 3, "counter": 5, "preview": 2, "spread": 0.5},
	{"name": "c1 3t", "types": 3, "bentos": 5, "belt": 16, "open": 2, "window": 3, "counter": 5, "preview": 2, "spread": 0.6},
	{"name": "c1 3t c4", "types": 3, "bentos": 5, "belt": 16, "open": 2, "window": 3, "counter": 4, "preview": 2, "spread": 0.8},
	{"name": "c2 4t", "types": 4, "bentos": 6, "belt": 20, "open": 2, "window": 3, "counter": 5, "preview": 2, "spread": 0.8},
	{"name": "c2 4t r", "types": 4, "bentos": 6, "belt": 20, "open": 2, "window": 3, "counter": 5, "preview": 2, "spread": 1.0},
	{"name": "c2 5t c4", "types": 5, "bentos": 7, "belt": 22, "open": 2, "window": 3, "counter": 4, "preview": 2, "spread": 1.0},
	{"name": "c3 5t w2", "types": 5, "bentos": 7, "belt": 22, "open": 2, "window": 2, "counter": 5, "preview": 2, "spread": 0.8},
	{"name": "c3 6t", "types": 6, "bentos": 8, "belt": 24, "open": 2, "window": 3, "counter": 5, "preview": 1, "spread": 1.0},
]


func _init() -> void:
	var samples := 12
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		samples = int(args[0])
	print("spec        solved  par  greedy  careful  nodes  branch  ms")
	for spec in SPECS:
		var solved := 0
		var pars: Array[float] = []
		var greedy: Array[float] = []
		var careful: Array[float] = []
		var nodes: Array[float] = []
		var branch: Array[float] = []
		var started := Time.get_ticks_msec()
		for i in samples:
			var rng := SeedService.make_rng(["bench", spec.name, i], SushiGenerator.GEN_VERSION)
			var level := SushiGenerator.deal(spec, rng)
			assert(level.validate() == "", level.validate())
			var stats := SushiGenerator.rate(level, i)
			if not stats.solved:
				continue
			solved += 1
			pars.append(level.par)
			greedy.append(level.greedy)
			careful.append(level.careful)
			nodes.append(stats.nodes)
			branch.append(stats.branching)
		var ms := (Time.get_ticks_msec() - started) / maxi(samples, 1)
		print("%-11s %2d/%-3d %4.1f  %s  %s  %5d  %4.2f  %d" % [spec.name, solved, samples, _median(pars),
				_range(greedy), _range(careful), int(_median(nodes)), _median(branch), ms])
	quit()


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## "lo-med-hi" of the values.
static func _range(values: Array[float]) -> String:
	if values.is_empty():
		return "  -  "
	var sorted := values.duplicate()
	sorted.sort()
	return "%.2f/%.2f/%.2f" % [sorted[0], sorted[sorted.size() / 2], sorted[sorted.size() - 1]]
