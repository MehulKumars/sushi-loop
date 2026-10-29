extends GutTest
## Independent checks of the 1000-level bake and the level plan against docs/SUSHI_LOOP.md ("Levels", "Stars", "Progression").
## Written from the doc by a session that did not write the generator; every expectation below is copied from the doc's tables.
## Each check gathers the failing level ids and asserts once, so a failure names every level that breaks the rule.

const PATH: String = "res://data/levels/sushi_v2.json"
const FROZEN_PATH: String = "res://tools/levelgen/frozen_v1.json"
const LEVELS: int = 1000
const CHAPTERS: int = 100
const PER_CHAPTER: int = 10
const MAX_BYTES: int = 256 * 1024
const BUDGET: int = 200_000

## "Roles per 10 levels" table.
const ROLES_CH_1: Array[String] = ["easy", "easy", "easy", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_CH_2_10: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_CH_11_40: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]
const ROLES_CH_41_100: Array[String] = ["easy", "medium", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]

## "Difficulty targets" table: greedy band, careful band, pass about.
const TARGETS: Dictionary = {
	"easy": {"greedy": [0.75, 0.95], "careful": [0.95, 1.0], "pass_about": 0.93},
	"medium": {"greedy": [0.4, 0.85], "careful": [0.85, 1.0], "pass_about": 0.8},
	"hard": {"greedy": [0.1, 0.45], "careful": [0.55, 0.85], "pass_about": 0.55},
	"super": {"greedy": [0.0, 0.2], "careful": [0.35, 0.75], "pass_about": 0.4},
	"rest": {"greedy": [0.7, 1.0], "careful": [0.95, 1.0], "pass_about": 0.93},
}
const PASS_TOLERANCE: float = 0.08

## "Chapter twists": chapters 1-6, then the cycle from chapter 7; a second twist from chapter 21.
const FIRST_SIX: Array[StringName] = [&"learn", &"more", &"all", &"narrow", &"single", &"hidden"]
const CYCLE: Array[StringName] = [&"long", &"narrow", &"single", &"hidden", &"dense", &"tight", &"mixed"]
## "mixed: each level one of the six above".
const SIX: Array[StringName] = [&"narrow", &"single", &"hidden", &"long", &"dense", &"tight"]
const CYCLE_FROM: int = 7
const DOUBLE_FROM: int = 21
const LONG_BELT: Vector2i = Vector2i(27, 32)
## "the counter 0, -1, +1, -2, +2 from the plan": at most two slots either way.
const MAX_COUNTER_STEP: int = 2


# --- helpers -----------------------------------------------------------------

func _raw() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data as Dictionary if data is Dictionary else {}


func _levels() -> Array[SushiLevel]:
	return SushiLevels.load_file(PATH)


func _chapter(id: int) -> int:
	return (id - 1) / PER_CHAPTER + 1


func _slot(id: int) -> int:
	return (id - 1) % PER_CHAPTER


func _doc_role(id: int) -> String:
	var chapter := _chapter(id)
	if chapter == 1:
		return ROLES_CH_1[_slot(id)]
	if chapter <= 10:
		return ROLES_CH_2_10[_slot(id)]
	if chapter <= 40:
		return ROLES_CH_11_40[_slot(id)]
	return ROLES_CH_41_100[_slot(id)]


func _main_twist(chapter: int) -> StringName:
	if chapter < CYCLE_FROM:
		return FIRST_SIX[chapter - 1]
	return CYCLE[(chapter - CYCLE_FROM) % CYCLE.size()]


## The twists level `id` must show: its chapter's, or for a mixed chapter the level's own one.
func _level_twists(id: int) -> Array[StringName]:
	var list := SushiChapters.twists(_chapter(id))
	if list.has(&"mixed"):
		return [SushiChapters.mixed_twist(id)]
	return list


func _pass_rate(level: SushiLevel) -> float:
	return 0.6 * level.careful + 0.4 * level.greedy


## Win rates are counts over 200 runs (steps of 0.005): compare them in exact thousandths.
func _milli(rate: float) -> int:
	return roundi(rate * 1000.0)


func _rates(level: SushiLevel) -> String:
	return "%d (%s g %.3f c %.3f)" % [level.id, level.role, level.greedy, level.careful]


func _expect_none(bad: Array, what: String) -> void:
	assert_true(bad.is_empty(), "%s: %d failing %s" % [what, bad.size(), str(bad.slice(0, 80))])


## Does `level` show the knob `twist` promises in the twist table?
func _shows(level: SushiLevel, twist: StringName) -> bool:
	match twist:
		&"narrow":
			return level.window == 2
		&"single":
			return level.open == 1
		&"hidden":
			return level.preview == 0
		&"long":
			return level.belt.size() >= LONG_BELT.x and level.belt.size() <= LONG_BELT.y
		&"dense":
			return not level.belt.has(-1)
		&"tight":
			return level.preview == 3
	return false


# --- 1. the baked file -------------------------------------------------------

func test_file_has_1000_levels_in_order_with_gen_version_2() -> void:
	var raw := _raw()
	assert_false(raw.is_empty(), "the file parses as a JSON object")
	assert_eq(int(raw.get("gen_version", 0)), 2)
	assert_eq(SushiLevels.gen_version(), 2)
	var list: Array = raw.get("levels", [])
	assert_eq(list.size(), LEVELS)
	var out_of_order: Array[int] = []
	for i in list.size():
		if int((list[i] as Dictionary).get("id", 0)) != i + 1:
			out_of_order.append(i + 1)
	_expect_none(out_of_order, "level at this position has the wrong id")
	assert_eq(SushiLevels.count(), LEVELS)
	assert_eq(SushiPlan.COUNT, LEVELS)
	assert_eq(SushiPlan.GEN_VERSION, 2)


func test_file_is_small() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	assert_not_null(file)
	if file:
		assert_lt(file.get_length(), MAX_BYTES, "sushi_v2.json bytes (install size)")


func test_belts_and_queues_are_short_strings() -> void:
	var bad: Array[String] = []
	for d: Dictionary in _raw().get("levels", []):
		var id := int(d.get("id", 0))
		var belt: Variant = d.get("belt")
		var bentos: Variant = d.get("bentos")
		if not belt is String or not bentos is String:
			bad.append("%d not strings" % id)
			continue
		for c: String in belt as String:
			if not "0123456.".contains(c):
				bad.append("%d belt char %s" % [id, c])
		for c: String in bentos as String:
			if not "0123456".contains(c):
				bad.append("%d queue char %s" % [id, c])
	_expect_none(bad, "belt/queue not stored as type strings")


func test_every_baked_level_is_valid() -> void:
	var bad: Array[String] = []
	for level in _levels():
		var why := level.validate()
		if why != "":
			bad.append("%d %s" % [level.id, why])
	_expect_none(bad, "invalid level")


func test_the_doc_example_string_reads_as_types_and_a_gap() -> void:
	var level := SushiLevel.from_dict({"belt": "01.2", "bentos": "0"})
	assert_eq(Array(level.belt), [0, 1, -1, 2])
	assert_eq(Array(level.bentos), [0])


func test_to_dict_from_dict_round_trip() -> void:
	var belt := [0, 1, -1, 2, 0, 0, 1, 2, -1, 0, 2, 1, 0, 0]
	var level := SushiLevel.make(belt, [0, 1, 2, 0], 1, 2, 4)
	level.id = 123
	level.preview = 3
	level.role = "hard"
	level.par = 3
	level.star_peak = 4
	level.greedy = 0.25
	level.careful = 0.7
	assert_eq(level.validate(), "", "the hand-made level is valid")
	var d := level.to_dict()
	assert_true(d.get("belt") is String, "belt stored as a string")
	assert_true(d.get("bentos") is String, "queue stored as a string")
	assert_eq(str(d.get("belt")), "01.20012.02100")
	assert_eq(str(d.get("bentos")), "0120")
	# Straight back, and through JSON text as the file does (numbers come back as floats).
	var direct := SushiLevel.from_dict(d)
	var via_json := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	for copy: SushiLevel in [direct, via_json]:
		assert_eq(copy.id, 123)
		assert_eq(Array(copy.belt), belt)
		assert_eq(Array(copy.bentos), [0, 1, 2, 0])
		assert_eq(copy.open, 1)
		assert_eq(copy.window, 2)
		assert_eq(copy.counter, 4)
		assert_eq(copy.preview, 3)
		assert_eq(copy.role, "hard")
		assert_eq(copy.par, 3)
		assert_eq(copy.star_peak, 4)
		assert_almost_eq(copy.greedy, 0.25, 1e-6)
		assert_almost_eq(copy.careful, 0.7, 1e-6)
		assert_eq(copy.validate(), "")


func test_every_baked_level_round_trips() -> void:
	var bad: Array[int] = []
	for level in _levels():
		var copy := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(level.to_dict())) as Dictionary)
		var same := copy.id == level.id and copy.belt == level.belt and copy.bentos == level.bentos \
				and copy.open == level.open and copy.window == level.window and copy.counter == level.counter \
				and copy.preview == level.preview and copy.role == level.role and copy.par == level.par \
				and copy.star_peak == level.star_peak and is_equal_approx(copy.greedy, level.greedy) \
				and is_equal_approx(copy.careful, level.careful)
		if not same:
			bad.append(level.id)
	_expect_none(bad, "level changes in a to_dict/from_dict round trip")


## "Levels 1-60 are frozen from the first bake (tools/levelgen/frozen_v1.json)".
func test_levels_1_to_60_are_the_frozen_ones() -> void:
	var frozen := SushiLevels.load_file(FROZEN_PATH)
	assert_eq(frozen.size(), 60)
	var levels := _levels()
	var bad: Array[int] = []
	for old in frozen:
		var now := levels[old.id - 1]
		if now.belt != old.belt or now.bentos != old.bentos or now.open != old.open or now.window != old.window \
				or now.counter != old.counter or now.preview != old.preview or now.par != old.par:
			bad.append(old.id)
	_expect_none(bad, "frozen level changed")


# --- 2. roles ------------------------------------------------------------------

func test_roles_follow_the_three_phase_table() -> void:
	var bad: Array[String] = []
	for level in _levels():
		var want := _doc_role(level.id)
		if level.role != want:
			bad.append("%d baked %s want %s" % [level.id, level.role, want])
		if SushiPlan.role(level.id) != want:
			bad.append("%d plan %s want %s" % [level.id, SushiPlan.role(level.id), want])
	_expect_none(bad, "role differs from the doc's table")


func test_hard_and_super_per_ten() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var count := 0
		for id in range((chapter - 1) * PER_CHAPTER + 1, chapter * PER_CHAPTER + 1):
			if levels[id - 1].role in ["hard", "super"]:
				count += 1
		var want := 2 if chapter <= 10 else 3
		if count != want:
			bad.append("chapter %d has %d" % [chapter, count])
	_expect_none(bad, "hard + super per ten")


# --- 3. chapter twists ------------------------------------------------------------

func test_chapter_twists_follow_the_doc() -> void:
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var list := SushiChapters.twists(chapter)
		var main := _main_twist(chapter)
		if list.is_empty() or list[0] != main:
			bad.append("chapter %d: %s, first should be %s" % [chapter, list, main])
			continue
		if chapter < DOUBLE_FROM or main == &"mixed":
			if list.size() != 1:
				bad.append("chapter %d: %s, want one twist" % [chapter, list])
			continue
		if list.size() != 2:
			bad.append("chapter %d: %s, want two twists" % [chapter, list])
			continue
		if list[1] == list[0] or not SIX.has(list[1]):
			bad.append("chapter %d: %s, second must be another of the six" % [chapter, list])
		if list.has(&"hidden") and list.has(&"tight"):
			bad.append("chapter %d: %s, hidden with tight" % [chapter, list])
	_expect_none(bad, "chapter twists")


## "adds a second twist that rotates": the partner differs from the last time the same twist led.
func test_second_twist_rotates() -> void:
	var bad: Array[String] = []
	for chapter in range(DOUBLE_FROM + CYCLE.size(), CHAPTERS + 1):
		var now := SushiChapters.twists(chapter)
		var before := SushiChapters.twists(chapter - CYCLE.size())
		if now.size() == 2 and before.size() == 2 and now[1] == before[1]:
			bad.append("chapter %d %s repeats chapter %d %s" % [chapter, now, chapter - CYCLE.size(), before])
	_expect_none(bad, "second twist does not rotate")


func test_mixed_levels_take_one_of_the_six_and_vary() -> void:
	var bad: Array[String] = []
	for chapter in range(CYCLE_FROM, CHAPTERS + 1):
		if not SushiChapters.twists(chapter).has(&"mixed"):
			continue
		var seen: Dictionary[StringName, bool] = {}
		for id in range((chapter - 1) * PER_CHAPTER + 1, chapter * PER_CHAPTER + 1):
			var twist := SushiChapters.mixed_twist(id)
			seen[twist] = true
			if not SIX.has(twist):
				bad.append("level %d: %s" % [id, twist])
		if seen.size() < 2:
			bad.append("chapter %d mixes only %s" % [chapter, seen.keys()])
	_expect_none(bad, "mixed chapter")


func test_plan_twists_match_the_chapter_card() -> void:
	var bad: Array[int] = []
	for id in range(1, LEVELS + 1):
		if SushiPlan.twists(id) != _level_twists(id):
			bad.append(id)
	_expect_none(bad, "plan twists differ from SushiChapters")


func test_every_level_from_chapter_7_shows_its_twist() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if _chapter(level.id) < CYCLE_FROM:
			continue
		for twist in _level_twists(level.id):
			if not _shows(level, twist):
				bad.append("%d %s (window %d open %d preview %d belt %d plates %d)" % [level.id, twist,
						level.window, level.open, level.preview, level.belt.size(), level.plate_count()])
	_expect_none(bad, "level lacks its twist's knob")


## The card tells the truth both ways: a two-plate window, one open bento, no preview or a three-bento
## preview only where the level's twist names it.
func test_no_twist_knob_without_its_twist() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if _chapter(level.id) < CYCLE_FROM:
			continue
		var twists := _level_twists(level.id)
		for twist: StringName in [&"narrow", &"single", &"hidden", &"tight"]:
			if _shows(level, twist) and not twists.has(twist):
				bad.append("%d shows %s, twists %s" % [level.id, twist, twists])
	_expect_none(bad, "knob without its twist")


## Plan knobs: "single: one more counter slot", "tight: one counter slot fewer", "Hard and super-hard
## levels have one counter slot fewer, rest levels one more" around one shared base.
func test_plan_counter_offsets() -> void:
	var bases: Dictionary[int, Array] = {}
	for id in range(SushiPlan.FROZEN_UNTIL + 1, LEVELS + 1):
		var spec := SushiPlan.spec(id)
		var delta := 0
		match str(spec.role):
			"hard", "super":
				delta -= 1
			"rest":
				delta += 1
		var twists: Array = spec.twists
		if twists.has(&"single"):
			delta += 1
		if twists.has(&"tight"):
			delta -= 1
		var base := int(spec.counter) - delta
		if not bases.has(base):
			bases[base] = []
		bases[base].append(id)
	var summary: Array[String] = []
	for base: int in bases:
		summary.append("base %d: %d levels, e.g. %s" % [base, bases[base].size(), str(bases[base].slice(0, 10))])
	assert_eq(bases.size(), 1, "one base counter: %s" % str(summary))


## The generator deals with the plan's knobs and only moves the counter (one slot per round, four
## rounds at most) and the plate order.
func test_bake_uses_the_plan_knobs() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for id in range(SushiPlan.FROZEN_UNTIL + 1, LEVELS + 1):
		var spec := SushiPlan.spec(id)
		var level := levels[id - 1]
		var diffs: Array[String] = []
		if level.open != int(spec.open):
			diffs.append("open %d/%d" % [level.open, int(spec.open)])
		if level.window != int(spec.window):
			diffs.append("window %d/%d" % [level.window, int(spec.window)])
		if level.preview != int(spec.preview):
			diffs.append("preview %d/%d" % [level.preview, int(spec.preview)])
		if level.belt.size() != int(spec.belt):
			diffs.append("belt %d/%d" % [level.belt.size(), int(spec.belt)])
		if level.bentos.size() != int(spec.bentos):
			diffs.append("bentos %d/%d" % [level.bentos.size(), int(spec.bentos)])
		if level.type_count() > int(spec.types):
			diffs.append("types %d/%d" % [level.type_count(), int(spec.types)])
		if absi(level.counter - int(spec.counter)) > MAX_COUNTER_STEP:
			diffs.append("counter %d/%d" % [level.counter, int(spec.counter)])
		if not diffs.is_empty():
			bad.append("%d %s" % [id, ", ".join(diffs)])
	_expect_none(bad, "baked knobs (baked/plan) differ from the plan")


func test_chapters_have_distinct_names_and_a_card() -> void:
	assert_eq(SushiMeta.chapter_count(), CHAPTERS)
	var names: Dictionary[String, int] = {}
	var dupes: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var chapter_name := SushiMeta.chapter_name(chapter)
		if chapter_name.is_empty() or names.has(chapter_name):
			dupes.append("%d '%s'" % [chapter, chapter_name])
		names[chapter_name] = chapter
		if chapter >= 2 and SushiChapters.text(chapter).is_empty():
			dupes.append("%d has no card line" % chapter)
	_expect_none(dupes, "chapter name or card")
	# "twelve looks that come round again with a numeral ("Corner Stall II")".
	assert_eq(SushiPalette.SHOPS.size(), 12)
	assert_eq(SushiMeta.chapter_name(13), SushiMeta.chapter_name(1) + " II")


# --- 4. quality rules and stars ----------------------------------------------------

func test_no_trivial_level_after_chapter_1() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id > PER_CHAPTER and level.role != "rest" and _milli(level.greedy) > 950:
			bad.append(_rates(level))
	_expect_none(bad, "greedy wins more than 95%")


func test_hard_and_super_reward_care() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id > PER_CHAPTER and level.role in ["hard", "super"] \
				and _milli(level.careful) - _milli(level.greedy) <= 200:
			bad.append(_rates(level))
	_expect_none(bad, "careful does not beat greedy by more than 0.2")


func test_no_narrow_line_after_chapter_1() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id > PER_CHAPTER and _milli(level.careful) < 350:
			bad.append(_rates(level))
	_expect_none(bad, "careful wins under 35%")


func test_star_peak_and_par() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.par < 0 or level.par > level.counter:
			bad.append("%d par %d counter %d" % [level.id, level.par, level.counter])
		var want := level.counter if level.id <= PER_CHAPTER else mini(level.counter, level.par + 1)
		if level.star_peak != want:
			bad.append("%d star_peak %d want %d (par %d counter %d)" % [level.id, level.star_peak, want,
					level.par, level.counter])
	_expect_none(bad, "star_peak / par")


# --- 5. difficulty targets -------------------------------------------------------

func test_pass_estimate_formula() -> void:
	assert_almost_eq(SushiPlan.pass_estimate(1.0, 0.0), 0.4, 1e-6)
	assert_almost_eq(SushiPlan.pass_estimate(0.0, 1.0), 0.6, 1e-6)
	assert_almost_eq(SushiPlan.pass_estimate(0.5, 0.75), 0.65, 1e-6)


func test_plan_bands_are_the_doc_table() -> void:
	for role: String in TARGETS:
		assert_true(SushiPlan.BANDS.has(role), role)
		if not SushiPlan.BANDS.has(role):
			continue
		var band: Dictionary = SushiPlan.BANDS[role]
		var want: Dictionary = TARGETS[role]
		for bot: String in ["greedy", "careful"]:
			assert_almost_eq(float(band[bot][0]), float(want[bot][0]), 1e-6, "%s %s low" % [role, bot])
			assert_almost_eq(float(band[bot][1]), float(want[bot][1]), 1e-6, "%s %s high" % [role, bot])


func test_mean_pass_per_role_is_on_target() -> void:
	var sums: Dictionary[String, float] = {}
	var counts: Dictionary[String, int] = {}
	for level in _levels():
		sums[level.role] = sums.get(level.role, 0.0) + SushiPlan.pass_estimate(level.greedy, level.careful)
		counts[level.role] = counts.get(level.role, 0) + 1
	for role: String in TARGETS:
		assert_gt(counts.get(role, 0), 0, "%s levels exist" % role)
		if counts.get(role, 0) == 0:
			continue
		var mean := sums[role] / counts[role]
		var target: float = TARGETS[role]["pass_about"]
		assert_almost_eq(mean, target, PASS_TOLERANCE, "%s mean pass %.3f over %d levels (target %.2f)" % [
				role, mean, counts[role], target])


func test_super_is_below_the_rest_levels_in_every_chapter() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var first := (chapter - 1) * PER_CHAPTER
		var super_ := levels[first + 8]
		var rest_mean := (_pass_rate(levels[first + 5]) + _pass_rate(levels[first + 9])) / 2.0
		if _pass_rate(super_) >= rest_mean:
			bad.append("chapter %d: super %d pass %.3f, rest mean %.3f" % [chapter, super_.id,
					_pass_rate(super_), rest_mean])
	_expect_none(bad, "sawtooth")


func test_hard_is_below_the_rest_levels_in_every_chapter() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var first := (chapter - 1) * PER_CHAPTER
		var rest_mean := (_pass_rate(levels[first + 5]) + _pass_rate(levels[first + 9])) / 2.0
		for slot in PER_CHAPTER:
			var level := levels[first + slot]
			if level.role == "hard" and _pass_rate(level) >= rest_mean:
				bad.append("chapter %d: hard %d pass %.3f, rest mean %.3f" % [chapter, level.id,
						_pass_rate(level), rest_mean])
	_expect_none(bad, "sawtooth (hard)")


# --- 6. plan determinism ---------------------------------------------------------

func test_plan_spec_is_deterministic() -> void:
	var ids: Array[int] = [1, 10, 59, 60, 61, 62, 65, 69, 70, 133, 200, 207, 211, 345, 401, 499, 555, 678, 789, 900, 999, 1000]
	var first: Dictionary[int, Dictionary] = {}
	for id in ids:
		first[id] = SushiPlan.spec(id)
	var reversed := ids.duplicate()
	reversed.reverse()
	var bad: Array[int] = []
	for id: int in reversed:
		var again := SushiPlan.spec(id)
		if again != first[id] or SushiPlan.spec(id) != again:
			bad.append(id)
		if int(again.get("id", 0)) != id or str(again.get("role", "")) != _doc_role(id):
			bad.append(id)
	_expect_none(bad, "spec differs between calls")


# --- 7. solvable sample ------------------------------------------------------------

func test_a_spread_sample_is_solvable_with_the_stored_par() -> void:
	var levels := _levels()
	var first := SushiPlan.FROZEN_UNTIL + 1
	for k in 25:
		var id := first + roundi(k * float(LEVELS - first) / 24.0)
		var level := levels[id - 1]
		var solver := SushiSolver.solve(SushiState.start(level), BUDGET)
		assert_eq(solver.status, StateSolver.Status.SOLVED, "level %d solvable" % id)
		assert_eq(SushiSolver.par(level, BUDGET), level.par, "level %d par" % id)


# --- progression ---------------------------------------------------------------

func test_progression_constants_and_chapter_ranges() -> void:
	assert_eq(SushiMeta.GIFT_EVERY, 15, "a gift every 15 stars")
	assert_eq(SushiMeta.GIFT_COINS, 100)
	assert_eq(SushiMeta.CHAPTER_BONUS, 100)
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var want := Vector2i((chapter - 1) * PER_CHAPTER + 1, chapter * PER_CHAPTER)
		if SushiMeta.chapter_range(chapter) != want:
			bad.append("chapter %d range %s" % [chapter, SushiMeta.chapter_range(chapter)])
	for id in range(1, LEVELS + 1):
		if SushiMeta.is_chapter_finale(id) != (id % PER_CHAPTER == 0):
			bad.append("level %d finale" % id)
		if SushiLevels.chapter(id) != _chapter(id):
			bad.append("level %d chapter %d" % [id, SushiLevels.chapter(id)])
	_expect_none(bad, "chapters of ten")
