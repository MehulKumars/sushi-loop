extends GutTest
## SushiMeta (docs/SUSHI_LOOP.md "Progression"): chapters of ten, the first level of each dish
## and its one-time card, star gifts, and the game screen's coins per star. Progress's named
## counts too. Uses its own save file so the real one is never touched.

const TEST_PATH := "user://test_sushi_meta.json"
const GAME_SCRIPT := "res://ui/screens/game.gd"


func before_each() -> void:
	Progress.path = TEST_PATH
	Progress.reset()


func after_all() -> void:
	Progress.reset()
	Progress.path = SaveStore.DEFAULT_PATH
	Progress.load_from_disk()


func test_counts_start_at_zero_and_are_saved() -> void:
	assert_eq(Progress.count("sessions"), 0)
	Progress.set_count("sessions", 3)
	Progress.load_from_disk()
	assert_eq(Progress.count("sessions"), 3)


func test_chapters_are_ten_levels_and_cover_every_level() -> void:
	assert_eq(SushiMeta.chapter_count(), ceili(SushiLevels.count() / 10.0))
	assert_eq(SushiMeta.chapter_range(1), Vector2i(1, 10))
	assert_eq(SushiMeta.chapter_range(2), Vector2i(11, 20))
	assert_eq(SushiMeta.chapter_range(SushiMeta.chapter_count()).y, SushiLevels.count())
	assert_true(SushiMeta.is_chapter_finale(10))
	assert_false(SushiMeta.is_chapter_finale(9))
	assert_false(SushiMeta.is_chapter_finale(11))


func test_every_chapter_has_a_named_restaurant() -> void:
	for chapter in range(1, SushiMeta.chapter_count() + 1):
		assert_false(SushiMeta.chapter_name(chapter).is_empty(), "chapter %d" % chapter)


func test_chapter_stars_and_wins_count_only_that_chapter() -> void:
	Progress.record_win(1, 3)
	Progress.record_win(2, 2)
	Progress.record_win(11, 1)
	assert_eq(SushiMeta.chapter_stars(1), 5)
	assert_eq(SushiMeta.chapter_won(1), 2)
	assert_eq(SushiMeta.chapter_stars(2), 1)


func test_every_dish_rides_a_belt_and_the_first_two_come_first() -> void:
	for type in SushiLevel.TYPE_COUNT:
		assert_gt(SushiMeta.first_level_of(type), 0, "dish %d appears in some level" % type)
	assert_eq(SushiMeta.first_level_of(0), 1)
	assert_eq(SushiMeta.first_level_of(1), 1)


func test_a_new_dish_is_introduced_once() -> void:
	var type := 2
	var level := SushiMeta.first_level_of(type)
	assert_true(SushiMeta.new_dishes(level).has(type))
	SushiMeta.mark_dish_seen(type)
	assert_false(SushiMeta.new_dishes(level).has(type))
	assert_true(SushiMeta.new_dishes(level + 1).is_empty() or not SushiMeta.new_dishes(level + 1).has(type))


func test_a_gift_every_fifteen_stars_opens_once() -> void:
	for level in range(1, 6):
		Progress.record_win(level, 3)
	assert_eq(Progress.total_stars(), 15)
	assert_eq(SushiMeta.gifts_ready(), 1)
	assert_eq(SushiMeta.gift_progress(), Vector2i(15, 15))
	var coins := Progress.coins()
	assert_eq(SushiMeta.open_gift(), SushiMeta.GIFT_COINS)
	assert_eq(Progress.coins(), coins + SushiMeta.GIFT_COINS)
	assert_eq(SushiMeta.gifts_ready(), 0)
	assert_eq(SushiMeta.open_gift(), 0, "nothing left to open")
	Progress.record_win(6, 2)
	assert_eq(SushiMeta.gift_progress(), Vector2i(2, 15))


func test_hard_levels_pay_more_per_star() -> void:
	var game: GDScript = load(GAME_SCRIPT)
	assert_eq(game.call(&"coins_for", 3, "medium"), 30)
	assert_eq(game.call(&"coins_for", 3, "hard"), 45)
	assert_eq(game.call(&"coins_for", 2, "super"), 40)
	assert_eq(game.call(&"coins_for", 0, "super"), 0)
