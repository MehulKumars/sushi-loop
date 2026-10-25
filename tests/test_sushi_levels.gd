extends GutTest
## The baked levels (data/levels/sushi_v1.json) against docs/SUSHI_LOOP.md "Levels" and "Stars".

const COUNT: int = 60


func test_sixty_levels_in_order_with_the_gen_version() -> void:
	var levels := SushiLevels.all()
	assert_eq(levels.size(), COUNT)
	assert_eq(SushiLevels.gen_version(), SushiLevels.GEN_VERSION)
	for i in levels.size():
		assert_eq(levels[i].id, i + 1)
	assert_eq(SushiLevels.level(1).id, 1)
	assert_eq(SushiLevels.level(999).id, COUNT, "clamped")


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
	for id: int in [1, 5, 9, 15, 19, 25, 29]:
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


func test_hard_levels_reward_care() -> void:
	for level in SushiLevels.all():
		assert_gte(level.careful, 0.35, "level %d: not one narrow line" % level.id)
		if level.role == "hard" or level.role == "super":
			assert_gt(level.careful, level.greedy + 0.2, "level %d: thinking must pay" % level.id)


func test_sizes_in_range() -> void:
	for level in SushiLevels.all():
		assert_between(level.belt.size(), 12, 30, "level %d" % level.id)
		assert_between(level.window, 2, 3)
		assert_between(level.counter, 4, 6)
		assert_between(level.open, 1, 2)
		assert_between(level.preview, 0, 3)


## Chapters 4-6 each lean on one knob (docs/SUSHI_LOOP.md "Levels"): mostly a two-plate window, one
## bento open at a time, no queue preview.
func test_late_chapters_have_their_twist() -> void:
	var twists := {4: func(l: SushiLevel) -> bool: return l.window == 2,
			5: func(l: SushiLevel) -> bool: return l.open == 1,
			6: func(l: SushiLevel) -> bool: return l.preview == 0}
	for chapter: int in twists:
		var levels := SushiMeta.chapter_range(chapter)
		var with_twist := 0
		for id in range(levels.x, levels.y + 1):
			if (twists[chapter] as Callable).call(SushiLevels.level(id)):
				with_twist += 1
		assert_gte(with_twist, 5, "chapter %d: most levels carry the twist" % chapter)
