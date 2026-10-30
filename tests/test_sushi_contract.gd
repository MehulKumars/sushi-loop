extends GutTest
## Independent checks of the 1000-level bake (gen_version 3) and the level plan against docs/SUSHI_LOOP.md
## ("Rules", "Special plates and orders", "Stars", "Levels", "Progression"), by a session that did not write the
## generator: every expectation is read from the doc. Each check gathers every failing level id and asserts once.

const PATH: String = "res://data/levels/sushi_v3.json"
const FROZEN_PATH: String = "res://tools/levelgen/frozen_v1.json"
const LEVELS: int = 1000
const CHAPTERS: int = 100
const PER_CHAPTER: int = 10
const GEN_VERSION: int = 3
const MAX_BYTES: int = 256 * 1024
const BUDGET: int = 200_000
## "Levels 1-2 are the hand-made tutorials".
const TUTORIALS: int = 2

## "Rules (v1)": sizes of a level.
const BELT_RANGE: Vector2i = Vector2i(12, 32)
const COUNTER_RANGE: Vector2i = Vector2i(3, 7)
## M1 a covered type t is "abcdefg"[t]; M3 "a wild plate (type 7, written *)"; "." an empty slot.
const DIGITS: String = "0123456"
const COVERED: String = "abcdefg"
const WILD: int = 7

## "Roles per 10 levels" table.
const ROLES_CH_1: Array[String] = ["easy", "easy", "easy", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_CH_2_10: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_CH_11_40: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]
const ROLES_CH_41_100: Array[String] = ["easy", "medium", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]

## "Difficulty targets" table: greedy band, careful band, pass about.
const TARGETS: Dictionary = {
	"easy": {"greedy": [0.6, 0.95], "careful": [0.9, 1.0], "pass_about": 0.9},
	"medium": {"greedy": [0.3, 0.8], "careful": [0.75, 1.0], "pass_about": 0.75},
	"hard": {"greedy": [0.05, 0.4], "careful": [0.45, 0.85], "pass_about": 0.55},
	"super": {"greedy": [0.0, 0.15], "careful": [0.15, 0.6], "pass_about": 0.2},
	"rest": {"greedy": [0.7, 1.0], "careful": [0.95, 1.0], "pass_about": 0.93},
}
## "a super-hard level before chapter 5 keeps the classic band (greedy 0-0.2, careful 0.35-0.75)".
const CLASSIC_BAND: Dictionary = {"greedy": [0.0, 0.2], "careful": [0.35, 0.75]}
const PASS_TOLERANCE: float = 0.08

## "Chapters 1-8: learn, more, covered, narrow, rush, single, wild, hidden. From chapter 9 the cycle ...".
const FIRST_EIGHT: Array[StringName] = [&"learn", &"more", &"covered", &"narrow", &"rush", &"single", &"wild", &"hidden"]
const CYCLE: Array[StringName] = [&"long", &"covered", &"narrow", &"rush", &"single", &"wild", &"hidden", &"dense", &"tight", &"mixed"]
## "mixed: each level one of the nine above".
const NINE: Array[StringName] = [&"covered", &"narrow", &"rush", &"single", &"wild", &"hidden", &"long", &"dense", &"tight"]
const CYCLE_FROM: int = 9
const DOUBLE_FROM: int = 21
## "never hidden with tight, nor dense with single".
const NEVER_PAIRED: Array[Array] = [[&"hidden", &"tight"], [&"dense", &"single"]]
## Chapters that bring M1, M2, M3 (the welcome cards of chapters 3, 5 and 7).
const COVERED_FROM: int = 3
const RUSH_FROM: int = 5
const WILD_FROM: int = 7
## "from level 4 every level but a rest level must defeat both mindless players".
const THOUGHT_FROM_LEVEL: int = 4
## "from chapter 5 every super-hard level must also defeat 'take what fits ...' played perfectly".
const CAREFUL_RULE_FROM: int = 5

## Twist knobs: "covered: 40-70% of the plates", "long: belts of 27-32 slots", rush limits.
const COVERED_SHARE: Vector2 = Vector2(0.4, 0.7)
const LONG_BELT: Vector2i = Vector2i(27, 32)
const RUSH_LIMITS: Vector2i = Vector2i(7, 10)
const TOUGH_RUSH_LIMITS: Vector2i = Vector2i(5, 8)
const SINGLE_RUSH_EXTRA: int = 3
## Super-hard pressure: "two rush orders (6-9 takes)".
const PRESSURE_RUSH_LIMITS: Vector2i = Vector2i(6, 9)
## "A super-hard level never has fewer than four counter slots, at most one chef's special, and a long loop of 27-28 slots."
const SUPER_MIN_COUNTER: int = 4
const SUPER_MAX_WILDS: int = 1
const SUPER_LONG_BELT: Vector2i = Vector2i(27, 28)
## Step 3: "the counter 0, -1, +1, -2, +2 from the plan".
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


func _doc_main_twist(chapter: int) -> StringName:
	if chapter < CYCLE_FROM:
		return FIRST_EIGHT[chapter - 1]
	return CYCLE[(chapter - CYCLE_FROM) % CYCLE.size()]


## The twists level `id` must show: its chapter's (checked against the doc in the twist tests), or for a mixed
## chapter the level's own one.
func _level_twists(id: int) -> Array[StringName]:
	var list := SushiChapters.twists(_chapter(id))
	if list.has(&"mixed"):
		return [SushiChapters.mixed_twist(id)]
	return list


## The super-hard pressure rule ("Levels", the paragraph after the twist table). &"" when it does not apply (not
## a super-hard level from chapter 5, or its twists bring rush orders or specials); otherwise &"wild" (from
## chapter 7 in even chapters, or with one bento open), &"none" (a one-bento level before chapter 7 stays
## classic) or &"rush" (two rush orders).
func _pressure(id: int) -> StringName:
	var chapter := _chapter(id)
	if _doc_role(id) != "super" or chapter < CAREFUL_RULE_FROM:
		return &""
	var twists := _level_twists(id)
	if twists.has(&"rush") or twists.has(&"wild"):
		return &""
	var one_bento := twists.has(&"single")
	if chapter >= WILD_FROM and (chapter % 2 == 0 or one_bento):
		return &"wild"
	if one_bento:
		return &"none"
	return &"rush"


## Must "take what fits, else the bento shown soonest" played perfectly lose level `id`? Every super-hard level
## from chapter 5, but a one-bento one before chapter 7 (it stays classic).
func _careful_rule_applies(id: int) -> bool:
	return _doc_role(id) == "super" and _chapter(id) >= CAREFUL_RULE_FROM and _pressure(id) != &"none"


## Is the level rated against the "Difficulty targets" table (not chapter 1's gentler bands, not a classic
## super-hard band)?
func _on_table_band(level: SushiLevel) -> bool:
	if _chapter(level.id) == 1:
		return false
	if level.role == "super":
		return _careful_rule_applies(level.id) and not level.classic
	return true


## "Pass = 0.6 × careful + 0.4 × greedy".
func _pass_rate(level: SushiLevel) -> float:
	return 0.6 * level.careful + 0.4 * level.greedy


## Win rates are counts over 200 runs (steps of 0.005): compare them in exact thousandths.
func _milli(rate: float) -> int:
	return roundi(rate * 1000.0)


func _rates(level: SushiLevel) -> String:
	return "%d (%s g %.3f c %.3f%s)" % [level.id, level.role, level.greedy, level.careful,
			" classic" if level.classic else ""]


func _expect_none(bad: Array, what: String) -> void:
	assert_true(bad.is_empty(), "%s: %d failing %s" % [what, bad.size(), str(bad.slice(0, 80))])


func _bit_count(mask: int) -> int:
	var count := 0
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count


## Plates of a dish on the belt (not empty slots, not chef's specials).
func _dish_plates(level: SushiLevel) -> int:
	var count := 0
	for t in level.belt:
		if t >= 0 and t < WILD:
			count += 1
	return count


## The rush limits of the bentos that rush (limit > 0).
func _rush_limits(level: SushiLevel) -> Array[int]:
	var out: Array[int] = []
	for limit in level.rush:
		if limit > 0:
			out.append(limit)
	return out


func _all_within(values: Array[int], span: Vector2i) -> bool:
	for v in values:
		if v < span.x or v > span.y:
			return false
	return true


func _knobs(level: SushiLevel) -> String:
	return "window %d open %d preview %d counter %d belt %d plates %d covered %d rush %s wilds %d" % [level.window,
			level.open, level.preview, level.counter, level.belt.size(), _dish_plates(level), _bit_count(level.covers),
			str(_rush_limits(level)), level.wild_count()]


## "" when `level` shows the knob `twist` promises in the twist table, else what is missing.
func _knob_miss(level: SushiLevel, twist: StringName, twists: Array[StringName]) -> String:
	var tough := level.role == "hard" or level.role == "super"
	match twist:
		&"covered":
			# "40-70% of the plates under cloches", in whole plates (the share rounds to the nearest plate).
			var plates := _dish_plates(level)
			var covered := _bit_count(level.covers)
			if covered < COVERED_SHARE.x * plates - 0.5 or covered > COVERED_SHARE.y * plates + 0.5:
				return "covered %d of %d plates" % [covered, plates]
		&"narrow":
			if level.window != 2:
				return "window %d" % level.window
		&"rush":
			# "one rush order (7-10 takes), two on hard and super-hard levels (5-8)"; with one bento open
			# "rush orders get 3 more takes".
			var want := 2 if tough else 1
			var span := TOUGH_RUSH_LIMITS if tough else RUSH_LIMITS
			if twists.has(&"single"):
				span += Vector2i(SINGLE_RUSH_EXTRA, SINGLE_RUSH_EXTRA)
			var limits := _rush_limits(level)
			if limits.size() != want or not _all_within(limits, span):
				return "rush %s, want %d in %d-%d" % [str(limits), want, span.x, span.y]
		&"single":
			if level.open != 1:
				return "open %d" % level.open
		&"wild":
			# "one chef's special, two on hard levels".
			var want := 2 if level.role == "hard" else 1
			if level.wild_count() != want:
				return "%d specials, want %d" % [level.wild_count(), want]
		&"hidden":
			if level.preview != 0:
				return "preview %d" % level.preview
		&"long":
			if level.belt.size() < LONG_BELT.x or level.belt.size() > LONG_BELT.y:
				return "belt %d" % level.belt.size()
		&"dense":
			if level.belt.has(-1):
				return "empty slots on a full belt"
		&"tight":
			if level.preview != 3:
				return "preview %d" % level.preview
		_:
			return "unknown twist"
	return ""


func _same_level(a: SushiLevel, b: SushiLevel) -> bool:
	return a.id == b.id and a.belt == b.belt and a.covers == b.covers and a.bentos == b.bentos and a.rush == b.rush \
			and a.open == b.open and a.window == b.window and a.counter == b.counter and a.preview == b.preview \
			and a.role == b.role and a.par == b.par and a.star_peak == b.star_peak and a.classic == b.classic \
			and is_equal_approx(a.greedy, b.greedy) and is_equal_approx(a.careful, b.careful)


## What a player can tell apart after a take (for the cloche check).
func _snapshot(state: SushiState) -> Array:
	var out: Array = [state.offset, state.closed, state.lost, state.held, state.peak, state.plates_on_belt(),
			Array(state.counter.items)]
	for slot in state.open_count():
		out.append(Vector2i(state.open_type(slot), state.open_fill(slot)))
	return out


# --- 1. the baked file -------------------------------------------------------

func test_file_has_1000_levels_in_order_with_gen_version_3() -> void:
	var raw := _raw()
	assert_false(raw.is_empty(), "the file parses as a JSON object")
	assert_eq(int(raw.get("gen_version", 0)), GEN_VERSION)
	assert_eq(SushiLevels.PATH, PATH, "the game reads data/levels/sushi_v3.json")
	assert_eq(SushiLevels.gen_version(), GEN_VERSION)
	assert_eq(SushiLevels.GEN_VERSION, GEN_VERSION)
	assert_eq(SushiPlan.GEN_VERSION, GEN_VERSION)
	var list: Array = raw.get("levels", [])
	assert_eq(list.size(), LEVELS)
	var out_of_order: Array[int] = []
	for i in list.size():
		if int((list[i] as Dictionary).get("id", 0)) != i + 1:
			out_of_order.append(i + 1)
	_expect_none(out_of_order, "level at this position has the wrong id")
	assert_eq(SushiLevels.count(), LEVELS)
	assert_eq(SushiPlan.COUNT, LEVELS)


func test_file_is_small() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	assert_not_null(file)
	if file:
		assert_lt(file.get_length(), MAX_BYTES, "sushi_v3.json bytes (install size)")


## Belt: "0"-"6" a dish, "a"-"g" a covered dish (M1), "*" a chef's special (M3), "." an empty slot; queue:
## "0"-"6". "rush": one limit per queued bento, left out when no bento rushes; "classic" only when set.
## M3: per type plates(t) <= 3 × bentos(t) and plates + wilds = 3 × bentos (counted from the raw strings).
func test_belt_and_queue_strings_use_only_the_doc_characters() -> void:
	var bad: Array[String] = []
	for d: Dictionary in _raw().get("levels", []):
		var id := int(d.get("id", 0))
		var belt: Variant = d.get("belt")
		var bentos: Variant = d.get("bentos")
		if not belt is String or not bentos is String:
			bad.append("%d not strings" % id)
			continue
		var needed: Dictionary[int, int] = {}
		for c: String in bentos as String:
			if not DIGITS.contains(c):
				bad.append("%d queue char %s" % [id, c])
				continue
			needed[DIGITS.find(c)] = needed.get(DIGITS.find(c), 0) + 3
		var plates: Dictionary[int, int] = {}
		var wilds := 0
		for c: String in belt as String:
			if DIGITS.contains(c):
				plates[DIGITS.find(c)] = plates.get(DIGITS.find(c), 0) + 1
			elif COVERED.contains(c):
				plates[COVERED.find(c)] = plates.get(COVERED.find(c), 0) + 1
			elif c == "*":
				wilds += 1
			elif c != ".":
				bad.append("%d belt char %s" % [id, c])
		var total := 0
		for t: int in plates:
			total += plates[t]
			if plates[t] > needed.get(t, 0):
				bad.append("%d type %d has %d plates for %d bentos" % [id, t, plates[t], needed.get(t, 0) / 3])
		if total + wilds != 3 * (bentos as String).length():
			bad.append("%d %d plates + %d specials for %d bentos" % [id, total, wilds, (bentos as String).length()])
		if d.has("rush"):
			var rush: Variant = d.rush
			if not rush is Array or (rush as Array).size() != (bentos as String).length():
				bad.append("%d rush %s for %d bentos" % [id, str(rush), (bentos as String).length()])
			else:
				var any_rush := false
				for v: Variant in rush as Array:
					if not (v is float or v is int) or float(v) < 0.0 or float(v) != floorf(float(v)):
						bad.append("%d rush value %s" % [id, str(v)])
					elif float(v) > 0.0:
						any_rush = true
				if not any_rush:
					bad.append("%d rush field but no bento rushes" % id)
		if d.has("classic") and d.classic != true:
			bad.append("%d classic %s" % [id, str(d.classic)])
	_expect_none(bad, "belt/queue/rush not stored as the doc says")


## "Rules (v1)": belt 12-32 slots, open 1 or 2, window 2 or 3, counter 3-7; and the level validates.
func test_every_baked_level_is_valid_and_in_the_doc_ranges() -> void:
	var bad: Array[String] = []
	for level in _levels():
		var why := level.validate()
		if why != "":
			bad.append("%d %s" % [level.id, why])
		if level.belt.size() < BELT_RANGE.x or level.belt.size() > BELT_RANGE.y or level.open < 1 or level.open > 2 \
				or level.window < 2 or level.window > 3 or level.counter < COUNTER_RANGE.x \
				or level.counter > COUNTER_RANGE.y:
			bad.append("%d %s" % [level.id, _knobs(level)])
	_expect_none(bad, "invalid level")


func test_the_doc_example_strings_read_as_types() -> void:
	var level := SushiLevel.from_dict({"belt": "01.2", "bentos": "0"})
	assert_eq(Array(level.belt), [0, 1, -1, 2])
	assert_eq(Array(level.bentos), [0])
	assert_eq(level.covers, 0, "digits are uncovered")
	# M1 "a covered plate of type t as the letter 'abcdefg'[t]", M3 "type 7, written *".
	level = SushiLevel.from_dict({"belt": "a.g*3", "bentos": "06"})
	assert_eq(Array(level.belt), [0, -1, 6, WILD, 3])
	assert_true(level.is_covered(0), "a is a covered type 0")
	assert_true(level.is_covered(2), "g is a covered type 6")
	assert_false(level.is_covered(3), "a chef's special wears no cloche")
	assert_false(level.is_covered(4))
	assert_eq(level.wild_count(), 1)


func test_to_dict_from_dict_round_trip_with_covers_rush_specials_and_classic() -> void:
	# Types 0 x5 (2 bentos, one special stands in), 1 x3, 2 x3; slots 1 and 10 covered.
	var belt := [0, 1, -1, 2, 0, WILD, 1, 2, -1, 0, 2, 1, 0, 0]
	var level := SushiLevel.make(belt, [0, 1, 2, 0], 1, 2, 4)
	level.id = 123
	level.covers = (1 << 1) | (1 << 10)
	level.rush = PackedInt32Array([0, 6, 0, 9])
	level.classic = true
	level.preview = 3
	level.role = "super"
	level.par = 3
	level.star_peak = 4
	level.greedy = 0.05
	level.careful = 0.35
	assert_eq(level.validate(), "", "the hand-made level is valid")
	var d := level.to_dict()
	assert_true(d.get("belt") is String, "belt stored as a string")
	assert_true(d.get("bentos") is String, "queue stored as a string")
	assert_eq(str(d.get("belt")), "0b.20*12.0c100")
	assert_eq(str(d.get("bentos")), "0120")
	assert_eq(d.get("rush"), [0, 6, 0, 9])
	assert_eq(d.get("classic"), true)
	# Straight back, and through JSON text as the file does (numbers come back as floats).
	var direct := SushiLevel.from_dict(d)
	var via_json := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	for copy: SushiLevel in [direct, via_json]:
		assert_true(_same_level(copy, level), "round trip keeps every field")
		assert_eq(Array(copy.belt), belt)
		assert_eq(copy.covers, level.covers)
		assert_eq(Array(copy.rush), [0, 6, 0, 9])
		assert_true(copy.classic)
		assert_eq(copy.wild_count(), 1)
		assert_eq(copy.validate(), "")
	# Left out when not set.
	var plain := SushiLevel.make([0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1]).to_dict()
	assert_false(plain.has("rush"), "no rush field when no bento rushes")
	assert_false(plain.has("classic"), "no classic field unless marked")


func test_every_baked_level_round_trips() -> void:
	var bad: Array[int] = []
	for level in _levels():
		var copy := SushiLevel.from_dict(JSON.parse_string(JSON.stringify(level.to_dict())) as Dictionary)
		if not _same_level(copy, level):
			bad.append(level.id)
	_expect_none(bad, "level changes in a to_dict/from_dict round trip")


## "Levels 1-2 are the hand-made tutorials (tools/levelgen/frozen_v1.json); every other level is dealt".
func test_levels_1_and_2_are_the_frozen_tutorials() -> void:
	var frozen := SushiLevels.load_file(FROZEN_PATH)
	assert_gte(frozen.size(), TUTORIALS)
	var levels := _levels()
	var bad: Array[int] = []
	for old in frozen:
		if old.id > TUTORIALS:
			continue
		var now := levels[old.id - 1]
		if now.belt != old.belt or now.bentos != old.bentos or now.open != old.open or now.window != old.window \
				or now.counter != old.counter or now.preview != old.preview or now.par != old.par \
				or now.star_peak != old.star_peak or now.role != old.role or now.covers != 0 or now.has_rush() \
				or now.classic:
			bad.append(old.id)
	_expect_none(bad, "tutorial changed")
	for id in range(1, TUTORIALS + 1):
		assert_true(bool(SushiPlan.spec(id).get("frozen", false)), "plan: level %d is a tutorial" % id)
	assert_false(bool(SushiPlan.spec(TUTORIALS + 1).get("frozen", true)), "plan: level 3 is dealt")


# --- 2. roles ------------------------------------------------------------------

func test_roles_follow_the_four_row_table() -> void:
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
		var main := _doc_main_twist(chapter)
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
		if list[1] == list[0] or not NINE.has(list[1]):
			bad.append("chapter %d: %s, the second must be another of the nine" % [chapter, list])
		for pair in NEVER_PAIRED:
			if list.has(pair[0]) and list.has(pair[1]):
				bad.append("chapter %d: %s pairs %s with %s" % [chapter, list, pair[0], pair[1]])
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


func test_mixed_levels_take_one_of_the_nine_and_vary() -> void:
	var bad: Array[String] = []
	var mixed_chapters := 0
	for chapter in range(1, CHAPTERS + 1):
		if not SushiChapters.twists(chapter).has(&"mixed"):
			continue
		mixed_chapters += 1
		var seen: Dictionary[StringName, bool] = {}
		for id in range((chapter - 1) * PER_CHAPTER + 1, chapter * PER_CHAPTER + 1):
			var twist := SushiChapters.mixed_twist(id)
			seen[twist] = true
			if not NINE.has(twist):
				bad.append("level %d: %s" % [id, twist])
		if seen.size() < 2:
			bad.append("chapter %d mixes only %s" % [chapter, seen.keys()])
	_expect_none(bad, "mixed chapter")
	assert_eq(mixed_chapters, (CHAPTERS - CYCLE_FROM + 1) / CYCLE.size(), "every tenth chapter from 18 is mixed")


func test_plan_twists_match_the_chapter_card() -> void:
	var bad: Array[int] = []
	for id in range(1, LEVELS + 1):
		if SushiPlan.twists(id) != _level_twists(id):
			bad.append(id)
	_expect_none(bad, "plan twists differ from SushiChapters")


## "Three mechanics arrive one chapter at a time ... each opened by a card": no cloche before chapter 3, no rush
## order before chapter 5, no chef's special before chapter 7.
func test_mechanics_arrive_with_their_chapter() -> void:
	var bad: Array[String] = []
	for level in _levels():
		var chapter := _chapter(level.id)
		if chapter < COVERED_FROM and level.covers != 0:
			bad.append("%d covered" % level.id)
		if chapter < RUSH_FROM and level.has_rush():
			bad.append("%d rush" % level.id)
		if chapter < WILD_FROM and level.wild_count() > 0:
			bad.append("%d special" % level.id)
	_expect_none(bad, "mechanic before its chapter")
	for pair: Array in [[COVERED_FROM, &"covered"], [RUSH_FROM, &"rush"], [WILD_FROM, &"wild"]]:
		var list := SushiChapters.twists(int(pair[0]))
		assert_true(list.size() == 1 and list[0] == pair[1], "chapter %d brings %s: %s" % [pair[0], pair[1], list])


## Chapter 1: "3 then 4 dishes" after the tutorials; chapter 2 ("more"): "5-6 dishes, longer belts".
func test_chapters_1_and_2_dishes_and_belts() -> void:
	var levels := _levels()
	var dishes: Array[int] = []
	for id in range(TUTORIALS + 1, PER_CHAPTER + 1):
		dishes.append(levels[id - 1].type_count())
	var sorted_dishes := dishes.duplicate()
	sorted_dishes.sort()
	assert_eq(dishes, sorted_dishes, "chapter 1: 3 dishes, then 4 (%s)" % str(dishes))
	assert_eq(dishes.front(), 3, "chapter 1 starts with 3 dishes: %s" % str(dishes))
	assert_eq(dishes.back(), 4, "chapter 1 ends with 4 dishes: %s" % str(dishes))
	var bad: Array[String] = []
	var belts := Vector2i.ZERO
	for id in range(1, 2 * PER_CHAPTER + 1):
		var level := levels[id - 1]
		if _chapter(id) == 1:
			belts.x += level.belt.size()
			if id > TUTORIALS and (level.type_count() < 3 or level.type_count() > 4):
				bad.append("%d has %d dishes" % [id, level.type_count()])
		else:
			belts.y += level.belt.size()
			if level.type_count() < 5 or level.type_count() > 6:
				bad.append("%d has %d dishes" % [id, level.type_count()])
	_expect_none(bad, "dishes in chapters 1-2")
	assert_gt(belts.y, belts.x, "chapter 2 belts are longer than chapter 1's (total slots)")


func test_every_level_from_chapter_3_shows_its_twists() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if _chapter(level.id) < COVERED_FROM:
			continue
		var twists := _level_twists(level.id)
		for twist in twists:
			var miss := _knob_miss(level, twist, twists)
			if miss != "":
				bad.append("%d %s %s: %s" % [level.id, level.role, twist, miss])
	_expect_none(bad, "level lacks its twist's knob")


## The card tells the truth both ways: a two-plate window, one open bento, no preview, a three-bento preview or
## cloches only where the level's twist names them; rush orders and specials only with their twist or as a
## super-hard level's own pressure.
func test_no_twist_knob_without_its_twist() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if _chapter(level.id) < COVERED_FROM:
			continue
		var twists := _level_twists(level.id)
		var pressure := _pressure(level.id)
		var shown: Array[StringName] = []
		if level.window == 2:
			shown.append(&"narrow")
		if level.open == 1:
			shown.append(&"single")
		if level.preview == 0:
			shown.append(&"hidden")
		if level.preview == 3:
			shown.append(&"tight")
		if level.covers != 0:
			shown.append(&"covered")
		if level.has_rush() and pressure != &"rush":
			shown.append(&"rush")
		if level.wild_count() > 0 and pressure != &"wild":
			shown.append(&"wild")
		for knob in shown:
			if not twists.has(knob):
				bad.append("%d %s shows %s, twists %s" % [level.id, level.role, knob, twists])
	_expect_none(bad, "knob without its twist")


## "From chapter 5 a super-hard level whose twists bring neither rush orders nor specials gets pressure of its
## own: two rush orders (6-9 takes), or from chapter 7 in even chapters (and with one bento open) a chef's
## special; a one-bento super-hard level before chapter 7 stays classic."
func test_super_hard_pressure_from_chapter_5() -> void:
	var bad: Array[String] = []
	var counts: Dictionary[StringName, int] = {}
	for level in _levels():
		var pressure := _pressure(level.id)
		if pressure == &"":
			continue
		counts[pressure] = counts.get(pressure, 0) + 1
		var limits := _rush_limits(level)
		var ok := true
		match pressure:
			&"wild":
				ok = level.wild_count() == 1 and limits.is_empty()
			&"none":
				ok = level.wild_count() == 0 and limits.is_empty()
			&"rush":
				ok = level.wild_count() == 0 and limits.size() == 2 and _all_within(limits, PRESSURE_RUSH_LIMITS)
		if not ok:
			bad.append("%d ch %d %s twists %s: rush %s specials %d" % [level.id, _chapter(level.id), pressure,
					_level_twists(level.id), str(limits), level.wild_count()])
	_expect_none(bad, "super-hard pressure")
	assert_gt(counts.get(&"rush", 0), 0, "some super-hard levels get two rush orders")
	assert_gt(counts.get(&"wild", 0), 0, "some super-hard levels get a chef's special")


## "A super-hard level never has fewer than four counter slots, at most one chef's special, and a long loop of
## 27-28 slots."
func test_super_hard_knob_limits() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.role != "super":
			continue
		if level.counter < SUPER_MIN_COUNTER:
			bad.append("%d counter %d%s" % [level.id, level.counter, " classic" if level.classic else ""])
		if level.wild_count() > SUPER_MAX_WILDS:
			bad.append("%d %d specials" % [level.id, level.wild_count()])
		if _level_twists(level.id).has(&"long") and (level.belt.size() < SUPER_LONG_BELT.x
				or level.belt.size() > SUPER_LONG_BELT.y):
			bad.append("%d long loop of %d" % [level.id, level.belt.size()])
	_expect_none(bad, "super-hard knob limits")


## Plan counter: "single: one more counter slot" (not on easy levels: "instead all seven dishes"), "tight: one
## counter slot fewer", "Hard and super-hard levels have one counter slot fewer, rest levels one more", around one
## shared base; a super-hard level never below four. Chapter 1 has its own table of gentle knobs.
func test_plan_counter_offsets() -> void:
	var deltas: Dictionary[int, int] = {}
	var bases: Dictionary[int, Array] = {}
	for id in range(PER_CHAPTER + 1, LEVELS + 1):
		var spec := SushiPlan.spec(id)
		var role := str(spec.role)
		var twists: Array = spec.twists
		var delta := 0
		match role:
			"hard", "super":
				delta -= 1
			"rest":
				delta += 1
		if twists.has(&"single") and role != "easy":
			delta += 1
		if twists.has(&"tight"):
			delta -= 1
		deltas[id] = delta
		if role == "super":
			continue
		var base := int(spec.counter) - delta
		if not bases.has(base):
			bases[base] = []
		bases[base].append(id)
	var summary: Array[String] = []
	for base: int in bases:
		summary.append("base %d: %d levels, e.g. %s" % [base, bases[base].size(), str(bases[base].slice(0, 10))])
	assert_eq(bases.size(), 1, "one base counter: %s" % str(summary))
	if bases.size() != 1:
		return
	var shared: int = bases.keys()[0]
	var bad: Array[String] = []
	for id: int in deltas:
		if _doc_role(id) != "super":
			continue
		var want := clampi(maxi(shared + deltas[id], SUPER_MIN_COUNTER), COUNTER_RANGE.x, COUNTER_RANGE.y)
		var got := int(SushiPlan.spec(id).counter)
		if got != want:
			bad.append("%d plan counter %d want %d" % [id, got, want])
	_expect_none(bad, "super-hard plan counter")


## Step 2-3: the generator deals the plan's knobs and places its specials, cloches and rush limits; only the
## counter moves (0, -1, +1, -2, +2) and the plate order.
func test_bake_uses_the_plan_knobs() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for id in range(TUTORIALS + 1, LEVELS + 1):
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
			diffs.append("dishes %d/%d" % [level.type_count(), int(spec.types)])
		if absi(level.counter - int(spec.counter)) > MAX_COUNTER_STEP:
			diffs.append("counter %d/%d" % [level.counter, int(spec.counter)])
		if level.wild_count() != int(spec.wilds):
			diffs.append("specials %d/%d" % [level.wild_count(), int(spec.wilds)])
		var limits := _rush_limits(level)
		var span: Array = spec.rush_limit
		if limits.size() != int(spec.rush) or not _all_within(limits, Vector2i(int(span[0]), int(span[1]))):
			diffs.append("rush %s/%d in %s" % [str(limits), int(spec.rush), str(span)])
		if (level.covers != 0) != (float(spec.covers) > 0.0):
			diffs.append("covers %d/%.2f" % [_bit_count(level.covers), float(spec.covers)])
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
	# "twelve looks (SushiPalette.SHOPS) that come round again with a numeral ("Corner Stall II")".
	assert_eq(SushiPalette.SHOPS.size(), 12)
	assert_eq(SushiMeta.chapter_name(13), SushiMeta.chapter_name(1) + " II")


# --- 4. thought rules ----------------------------------------------------------------

func test_plan_marks_the_thought_rules_as_the_doc_says() -> void:
	var bad: Array[String] = []
	for id in range(TUTORIALS + 1, LEVELS + 1):
		var spec := SushiPlan.spec(id)
		var anti_spam := id >= THOUGHT_FROM_LEVEL and _doc_role(id) != "rest"
		if bool(spec.get("anti_spam", false)) != anti_spam:
			bad.append("%d anti_spam %s want %s" % [id, spec.get("anti_spam"), anti_spam])
		if bool(spec.get("careful_must_lose", false)) != _careful_rule_applies(id):
			bad.append("%d careful_must_lose %s want %s" % [id, spec.get("careful_must_lose"),
					_careful_rule_applies(id)])
	_expect_none(bad, "plan thought rules")


## "from level 4 every level but a rest level must defeat both mindless players (always the plate at the
## window's exit, always the one that just came in)".
func test_mindless_tapping_loses_every_non_rest_level_from_level_4() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id < THOUGHT_FROM_LEVEL or level.role == "rest":
			continue
		if SushiBot.wins(level, SushiBot.SPAM_EXIT):
			bad.append("%d %s exit" % [level.id, level.role])
		if SushiBot.wins(level, SushiBot.SPAM_ENTRY):
			bad.append("%d %s entry" % [level.id, level.role])
	_expect_none(bad, "a mindless player wins")


## "from chapter 5 every super-hard level must also defeat 'take what fits, else the bento shown soonest' played
## perfectly (where no fair deal does, the bake falls back to a classic super-hard level, marked classic)".
func test_the_rule_of_thumb_loses_every_marked_super_hard_level() -> void:
	var bad: Array[String] = []
	var checked := 0
	for level in _levels():
		if not bool(SushiPlan.spec(level.id).get("careful_must_lose", false)) or level.classic:
			continue
		checked += 1
		if SushiBot.wins(level, SushiBot.CAREFUL_PURE):
			bad.append(_rates(level))
	_expect_none(bad, "take-what-fits played perfectly wins")
	assert_gt(checked, 0, "some super-hard levels defeat the rule of thumb")


func test_classic_marks_only_super_hard_levels_under_the_careful_rule() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.classic and not _careful_rule_applies(level.id):
			bad.append("%d %s ch %d" % [level.id, level.role, _chapter(level.id)])
	_expect_none(bad, "classic outside the fallback")


# --- 5. quality rules and stars ----------------------------------------------------

## Step 4: "no level but a rest level is trivial (greedy wins at most 95%)", after chapter 1.
func test_no_trivial_level_after_chapter_1() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id > PER_CHAPTER and level.role != "rest" and _milli(level.greedy) > 950:
			bad.append(_rates(level))
	_expect_none(bad, "greedy wins more than 95%")


## Step 4: "hard levels reward care (careful beats greedy by more than 0.2)", after chapter 1.
func test_hard_levels_reward_care() -> void:
	var bad: Array[String] = []
	for level in _levels():
		if level.id > PER_CHAPTER and level.role == "hard" and _milli(level.careful) - _milli(level.greedy) <= 200:
			bad.append(_rates(level))
	_expect_none(bad, "careful does not beat greedy by more than 0.2")


## Step 4: "no level but a super-hard one is one narrow line (careful wins at least 35%); a super-hard level ...
## only the careful bot's slips win it (at least 15%)", after chapter 1.
func test_no_narrow_line_after_chapter_1() -> void:
	var bad: Array[String] = []
	for level in _levels():
		var floor_ := 150 if level.role == "super" else 350
		if level.id > PER_CHAPTER and _milli(level.careful) < floor_:
			bad.append(_rates(level))
	_expect_none(bad, "careful wins under 35% (15% on super-hard)")


## "Stars": star_peak is the counter size on levels 1-10, then par + 1; the counter marks its first star_peak
## settings ("Progression"), so it never exceeds the counter. par: the smallest counter that still solves it.
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


# --- 6. difficulty targets -------------------------------------------------------

func test_pass_estimate_formula() -> void:
	assert_almost_eq(SushiPlan.pass_estimate(1.0, 0.0), 0.4, 1e-6)
	assert_almost_eq(SushiPlan.pass_estimate(0.0, 1.0), 0.6, 1e-6)
	assert_almost_eq(SushiPlan.pass_estimate(0.5, 0.75), 0.65, 1e-6)


func _same_band(band: Dictionary, want: Dictionary) -> bool:
	for bot: String in ["greedy", "careful"]:
		for i in 2:
			if not is_equal_approx(float(band[bot][i]), float(want[bot][i])):
				return false
	return true


func test_plan_bands_are_the_doc_table() -> void:
	for role: String in TARGETS:
		assert_true(SushiPlan.BANDS.has(role), role)
		if SushiPlan.BANDS.has(role):
			assert_true(_same_band(SushiPlan.BANDS[role], TARGETS[role]), "%s band %s" % [role, SushiPlan.BANDS[role]])
	assert_true(_same_band(SushiPlan.CLASSIC_SUPER, CLASSIC_BAND), "classic band %s" % SushiPlan.CLASSIC_SUPER)


## Each dealt level's band: chapter 1 gentler (no lower bound below the table's), a super-hard level the careful
## rule does not cover (chapters 2-4, a one-bento one before chapter 7) the classic band, every other the table.
func test_plan_gives_each_level_the_doc_band() -> void:
	var bad: Array[String] = []
	for id in range(TUTORIALS + 1, LEVELS + 1):
		var band: Dictionary = SushiPlan.spec(id).band
		var role := _doc_role(id)
		var table: Dictionary = TARGETS[role]
		if _chapter(id) == 1:
			var gentler := float(band.greedy[0]) >= float(table.greedy[0]) - 1e-6 \
					and float(band.careful[0]) >= float(table.careful[0]) - 1e-6 and not _same_band(band, table)
			if not gentler:
				bad.append("%d %s chapter-1 band %s not gentler than %s" % [id, role, band, table])
		elif role == "super" and not _careful_rule_applies(id):
			if not _same_band(band, CLASSIC_BAND):
				bad.append("%d classic super band %s" % [id, band])
		elif not _same_band(band, table):
			bad.append("%d %s band %s" % [id, role, band])
	_expect_none(bad, "plan band")


## "Pass about" per role, over the levels rated against the table (not chapter 1's gentler bands, not classic
## super-hard levels).
func test_mean_pass_per_role_is_on_target() -> void:
	var sums: Dictionary[String, float] = {}
	var counts: Dictionary[String, int] = {}
	for level in _levels():
		if not _on_table_band(level):
			continue
		sums[level.role] = sums.get(level.role, 0.0) + _pass_rate(level)
		counts[level.role] = counts.get(level.role, 0) + 1
	for role: String in TARGETS:
		assert_gt(counts.get(role, 0), 0, "%s levels exist" % role)
		if counts.get(role, 0) == 0:
			continue
		var mean := sums[role] / counts[role]
		var target: float = TARGETS[role]["pass_about"]
		assert_almost_eq(mean, target, PASS_TOLERANCE, "%s mean pass %.3f over %d levels (target %.2f)" % [
				role, mean, counts[role], target])


## The roller-coaster sawtooth: each chapter's super-hard level (slot 9) passes less often than its two rest
## levels (slots 6 and 10) on average.
func test_super_is_below_the_rest_levels_in_every_chapter() -> void:
	var levels := _levels()
	var bad: Array[String] = []
	for chapter in range(1, CHAPTERS + 1):
		var first := (chapter - 1) * PER_CHAPTER
		var super_ := levels[first + 8]
		var rest_mean := (_pass_rate(levels[first + 5]) + _pass_rate(levels[first + 9])) / 2.0
		if _pass_rate(super_) >= rest_mean:
			bad.append("chapter %d: super %d pass %.3f, rest mean %.3f" % [chapter, super_.id, _pass_rate(super_), rest_mean])
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
				bad.append("chapter %d: hard %d pass %.3f, rest mean %.3f" % [chapter, level.id, _pass_rate(level), rest_mean])
	_expect_none(bad, "sawtooth (hard)")


# --- 7. plan determinism ---------------------------------------------------------

func test_plan_spec_is_deterministic() -> void:
	var ids: Array[int] = [1, 2, 3, 10, 41, 49, 59, 60, 61, 65, 69, 89, 133, 200, 207, 211, 345, 401, 499, 555, 678,
			789, 900, 999, 1000]
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


# --- 8. solvable sample ------------------------------------------------------------

func test_a_spread_sample_is_solvable_with_the_stored_par() -> void:
	var levels := _levels()
	var first := TUTORIALS + 1
	for k in 25:
		var id := first + roundi(k * float(LEVELS - first) / 24.0)
		var level := levels[id - 1]
		var solver := SushiSolver.solve(SushiState.start(level), BUDGET)
		assert_eq(solver.status, StateSolver.Status.SOLVED, "level %d solvable" % id)
		assert_eq(SushiSolver.par(level, BUDGET), level.par, "level %d par" % id)


# --- 9. special plates and orders, on levels worked by hand -------------------------
# (tests/test_sushi_mechanics.gd covers the rest of M1-M3; these add what it leaves out.)

## M2 "From the take after it opens, each take lowers its count": a rush bento open from the start counts the
## very first take. Slots 0-2 dish 0 in the window, slots 9-11 dish 1; take(2) keeps taking the exit plate.
func test_a_rush_order_open_from_the_start_counts_the_first_take() -> void:
	var belt := [0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1]
	var in_time := SushiLevel.make(belt, [0, 1], 1, 3, 5)
	in_time.rush = PackedInt32Array([3, 0])
	assert_eq(in_time.validate(), "")
	var state := SushiState.start(in_time)
	assert_eq(state.rush_of(0), 3, "the limit before the first take")
	state.take(2)
	assert_eq(state.rush_of(0), 2, "the first take counts")
	state.take(2)
	state.take(2)
	assert_false(state.lost, "closed on its last take: in time")
	assert_eq(state.closed, 1)
	for i in 3:
		state.take(2)
	assert_true(state.is_won(), "the second bento does not rush")
	var late := SushiLevel.make(belt, [0, 1], 1, 3, 5)
	late.rush = PackedInt32Array([2, 0])
	state = SushiState.start(late)
	state.take(2)
	assert_false(state.lost)
	state.take(2)
	assert_true(state.lost, "two takes and still open: the customer leaves")
	assert_eq(state.lost_reason, &"rush")


## M2 data: "rush, one limit per queued bento".
func test_rush_needs_one_limit_per_queued_bento() -> void:
	var level := SushiLevel.make([0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1], [0, 1], 1, 3, 5)
	level.rush = PackedInt32Array([4])
	assert_ne(level.validate(), "", "one limit for two bentos")
	level.rush = PackedInt32Array([0, 4])
	assert_eq(level.validate(), "")


## M3 "it goes into the open bento holding the most plates (ties: the lower slot)". Slot 0 a special, dish 0 one
## plate short; after one plate in each bento the special reaches the exit with both bentos at one plate.
func test_a_chefs_special_breaks_a_tie_toward_the_lower_slot() -> void:
	var level := SushiLevel.make([WILD, 1, 0, -1, -1, -1, -1, -1, -1, 0, 1, 1], [0, 1], 2, 3, 5)
	assert_eq(level.validate(), "")
	var state := SushiState.start(level)
	state.take(2)
	state.take(2)
	assert_eq(state.open_fill(0), 1)
	assert_eq(state.open_fill(1), 1)
	assert_eq(state.window_plate(2), 0, "the special is at the exit")
	state.take(2)
	assert_eq(state.open_fill(0), 2, "the tie goes to the lower slot")
	assert_eq(state.open_fill(1), 1)
	assert_eq(state.counter.size(), 0, "a special never goes on the counter")
	assert_eq(SushiSolver.solve(state, BUDGET).status, StateSolver.Status.SOLVED, "it counts as dish 0")


## M3 "per type plates(t) <= 3 × bentos(t) and plates + wilds = 3 × bentos": the totals alone are not enough.
func test_a_dish_never_has_more_plates_than_its_bentos() -> void:
	var level := SushiLevel.make([0, 0, 0, 0, 1, WILD, -1, -1, -1, -1, -1, -1], [0, 1], 2, 3, 5)
	assert_ne(level.validate(), "", "four dish-0 plates for one dish-0 bento")
	level = SushiLevel.make([0, 0, 0, 1, 1, WILD, -1, -1, -1, -1, -1, -1], [0, 1], 2, 3, 5)
	assert_eq(level.validate(), "")


## M1 "Nothing else changes (routing, solver)" and "The solver and the bots know every dish (covered or not)":
## the same level under cloches solves, rates and plays exactly as it does uncovered.
func test_cloches_change_only_what_the_player_sees() -> void:
	var belt := [0, 1, 2, 0, -1, 1, 2, 0, 2, -1, 1, 0, 0, 0, -1]
	var plain := SushiLevel.make(belt, [0, 1, 2, 0], 2, 3, 3)
	var covered := SushiLevel.make(belt, [0, 1, 2, 0], 2, 3, 3)
	for slot in belt.size():
		if belt[slot] >= 0:
			covered.covers |= 1 << slot
	assert_eq(covered.validate(), "")
	assert_eq(str(covered.to_dict().belt), "abca.bcac.baaa.")
	var par := SushiSolver.par(plain, BUDGET)
	assert_gte(par, 0, "the plain level is solvable")
	assert_eq(SushiSolver.par(covered, BUDGET), par, "same par under cloches")
	for kind: int in [SushiBot.GREEDY, SushiBot.CAREFUL]:
		assert_eq(SushiBot.win_rate(covered, kind, 60, 11), SushiBot.win_rate(plain, kind, 60, 11), "bot %d" % kind)
	var a := SushiState.start(plain)
	var b := SushiState.start(covered)
	var rng := RandomNumberGenerator.new()
	var diffs: Array[String] = []
	var takes := 0
	while not a.is_over() and takes < 100:
		var w := SushiBot.choose(a, SushiBot.CAREFUL, rng)
		if SushiBot.choose(b, SushiBot.CAREFUL, rng) != w:
			diffs.append("take %d: careful choice" % takes)
		if SushiSolver.hint(a) != SushiSolver.hint(b):
			diffs.append("take %d: hint" % takes)
		a.take(w)
		b.take(w)
		if _snapshot(a) != _snapshot(b):
			diffs.append("take %d: %s vs %s" % [takes, _snapshot(a), _snapshot(b)])
		takes += 1
	assert_gt(takes, 0)
	assert_eq(a.is_won(), b.is_won())
	_expect_none(diffs, "cloches changed the game")


# --- 10. progression ---------------------------------------------------------------

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
