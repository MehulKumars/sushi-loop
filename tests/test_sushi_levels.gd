extends GutTest
## The baked levels (data/levels/sushi_v3.json) against docs/SUSHI_LOOP.md "Levels" and "Stars".

const COUNT: int = 1000


func test_all_levels_in_order_with_the_gen_version() -> void:
	var levels := SushiLevels.all()
	assert_eq(levels.size(), COUNT)
	assert_eq(SushiLevels.gen_version(), SushiLevels.GEN_VERSION)
	for i in levels.size():
		assert_eq(levels[i].id, i + 1)
	assert_eq(SushiLevels.level(1).id, 1)
	assert_eq(SushiLevels.level(COUNT + 50).id, COUNT, "clamped")


func test_every_level_is_valid_and_solvable() -> void:
	for level in SushiLevels.all():
		assert_eq(level.validate(), "", "level %d" % level.id)
		var solver := SushiSolver.solve(SushiState.start(level), 200_000)
		assert_eq(solver.status, StateSolver.Status.SOLVED, "level %d" % level.id)


func test_par_and_star_peak() -> void:
	for level in SushiLevels.all():
		assert_between(level.par, 0, level.counter, "level %d par" % level.id)
		if level.id <= 10:
			assert_eq(level.star_peak, level.counter, "level %d: any clean win is 3 stars" % level.id)
		else:
			assert_eq(level.star_peak, mini(level.counter, level.par + 1), "level %d" % level.id)


func test_par_is_right_for_a_sample() -> void:
	for id: int in [1, 5, 9, 15, 19, 25, 29, 64, 105, 359, 588, 777, 999]:
		var level := SushiLevels.level(id)
		assert_eq(SushiSolver.par(level, 200_000), level.par, "level %d" % id)


func test_level_one_teaches_the_counter_by_necessity() -> void:
	var level := SushiLevels.level(1)
	assert_eq(level.plate_count(), 6)
	assert_eq(level.type_count(), 2)
	assert_eq(level.open, 1)
	assert_eq(level.preview, 0)
	assert_gte(level.par, 1, "every line puts a plate on the counter")
	var state := SushiState.start(level)
	var fitting := 0
	for w in level.window:
		var plate := state.window_plate(w)
		if plate >= 0 and state.fits(state.plate_type(plate)):
			fitting += 1
	assert_eq(fitting, 1, "one plate to point at")


func test_one_new_idea_per_tutorial_level() -> void:
	assert_eq(SushiLevels.level(2).preview, 1, "level 2 shows the next bento")
	assert_eq(SushiLevels.level(2).open, 1)
	assert_eq(SushiLevels.level(3).open, 2, "level 3 opens a second bento")


func test_sawtooth_roles() -> void:
	for level in SushiLevels.all():
		match level.id % 10:
			5:
				assert_eq(level.role, "hard", "level %d" % level.id)
			9:
				assert_eq(level.role, "super", "level %d" % level.id)
			6, 0:
				assert_eq(level.role, "rest", "level %d" % level.id)


func test_no_reskin_trap() -> void:
	# Greedy must not win most mid-chapter levels, and after chapter 1 no non-rest level is trivial.
	var total := 0.0
	var count := 0
	for level in SushiLevels.all():
		if level.role == "rest":
			continue
		if level.id % 10 >= 4 and level.id % 10 <= 9:
			total += level.greedy
			count += 1
		if level.id > 10:
			assert_lte(level.greedy, 0.95, "level %d is trivial" % level.id)
	assert_lt(total / count, 0.9)


## No level is one narrow line (a super-hard level defeats the careful rule itself, so only its
## slips win it: at least 15%), and on hard levels thinking pays.
func test_hard_levels_reward_care() -> void:
	for level in SushiLevels.all():
		var floor_ := 0.15 if level.role == "super" else 0.35
		assert_gte(level.careful, floor_, "level %d: not one narrow line" % level.id)
		if level.role == "hard":
			assert_gt(level.careful, level.greedy + 0.2, "level %d: thinking must pay" % level.id)


## docs/SUSHI_LOOP.md "Levels" 2: mindless tapping wins no level after the tutorials (rest levels
## aside), and from chapter 5 "take what fits" played perfectly loses every super-hard level the
## plan marks, unless the bake fell back to a classic super-hard level (marked `classic`).
func test_no_level_plays_itself() -> void:
	for level in SushiLevels.all():
		var spec := SushiPlan.spec(level.id)
		if spec.get("anti_spam", false):
			assert_false(SushiBot.wins(level, SushiBot.SPAM_EXIT), "level %d falls to tapping the exit plate" % level.id)
			assert_false(SushiBot.wins(level, SushiBot.SPAM_ENTRY), "level %d falls to tapping the entry plate" % level.id)
		if spec.get("careful_must_lose", false) and not level.classic:
			assert_false(SushiBot.wins(level, SushiBot.CAREFUL_PURE), "level %d falls to the rule of thumb" % level.id)


func test_sizes_in_range() -> void:
	for level in SushiLevels.all():
		assert_between(level.belt.size(), 12, 32, "level %d" % level.id)
		assert_between(level.window, 2, 3)
		assert_between(level.counter, 3, 7)
		assert_between(level.open, 1, 2)
		assert_between(level.preview, 0, 3)


## From chapter 3 on, every level carries its chapter's twist(s) (SushiChapters), so the card that
## opens the chapter tells the truth. A mixed chapter gives each level one twist of its own.
func test_every_later_level_has_the_twist_its_chapter_names() -> void:
	var checks := {
		&"narrow": func(l: SushiLevel) -> bool: return l.window == 2,
		&"single": func(l: SushiLevel) -> bool: return l.open == 1,
		&"hidden": func(l: SushiLevel) -> bool: return l.preview == 0,
		&"long": func(l: SushiLevel) -> bool: return l.belt.size() >= 27,
		&"dense": func(l: SushiLevel) -> bool: return l.belt.size() == l.plate_count(),
		&"tight": func(l: SushiLevel) -> bool: return l.preview == 3,
		&"covered": func(l: SushiLevel) -> bool: return l.covers != 0,
		&"rush": func(l: SushiLevel) -> bool: return l.has_rush(),
		&"wild": func(l: SushiLevel) -> bool: return l.wild_count() > 0,
	}
	for level in SushiLevels.all():
		var chapter := SushiLevels.chapter(level.id)
		if chapter < 3:
			continue
		var twists := SushiChapters.twists(chapter)
		if twists.has(&"mixed"):
			twists = [SushiChapters.mixed_twist(level.id)]
		for twist in twists:
			assert_true((checks[twist] as Callable).call(level), "level %d lacks its chapter's twist %s" % [level.id, twist])


func test_ten_levels_per_chapter_and_a_name_for_each() -> void:
	assert_eq(SushiMeta.chapter_count(), COUNT / SushiLevels.CHAPTER)
	var names: Dictionary[String, bool] = {}
	for chapter in range(1, SushiMeta.chapter_count() + 1):
		names[SushiMeta.chapter_name(chapter)] = true
		assert_ne(SushiChapters.text(chapter), "", "chapter %d has a card line" % chapter)
	assert_eq(names.size(), SushiMeta.chapter_count(), "every chapter has its own name")
