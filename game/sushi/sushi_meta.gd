class_name SushiMeta
extends RefCounted
## Sushi Loop's progression between levels (docs/SUSHI_LOOP.md "Progression"): chapters of ten
## levels, each a restaurant with its own look; a "new on the menu" card the first time a dish
## rides the belt; a gift of coins for every GIFT_EVERY stars; a bonus for finishing a chapter.
## Pure rules over Progress and SushiLevels, so it is tested without screens.

## Stars per gift, and what a gift holds.
const GIFT_EVERY: int = 15
const GIFT_COINS: int = 100
## Coins for winning a chapter's last level the first time.
const CHAPTER_BONUS: int = 100


static func chapter_count() -> int:
	return ceili(float(SushiLevels.count()) / float(SushiLevels.CHAPTER))


## First and last level of 1-based `chapter`.
static func chapter_range(chapter: int) -> Vector2i:
	var first := (chapter - 1) * SushiLevels.CHAPTER + 1
	return Vector2i(first, mini(first + SushiLevels.CHAPTER - 1, SushiLevels.count()))


static func chapter_name(chapter: int) -> String:
	return SushiPalette.shop(chapter).name


static func chapter_stars(chapter: int) -> int:
	var levels := chapter_range(chapter)
	var total := 0
	for level in range(levels.x, levels.y + 1):
		total += Progress.stars(level)
	return total


static func chapter_won(chapter: int) -> int:
	var levels := chapter_range(chapter)
	var won := 0
	for level in range(levels.x, levels.y + 1):
		if Progress.stars(level) > 0:
			won += 1
	return won


static func is_chapter_finale(level: int) -> bool:
	return level == chapter_range(SushiLevels.chapter(level)).y


## The level where dish `type` first rides the belt (0 if no level has it).
static func first_level_of(type: int) -> int:
	for level in SushiLevels.all():
		if level.belt.has(type):
			return level.id
	return 0


## Dishes that ride the belt for the first time in `level` and have not been introduced yet.
static func new_dishes(level: int) -> Array[int]:
	var out: Array[int] = []
	var seen := Progress.count("dishes")
	for type in SushiLevel.TYPE_COUNT:
		if first_level_of(type) == level and seen & (1 << type) == 0:
			out.append(type)
	return out


static func mark_dish_seen(type: int) -> void:
	Progress.set_count("dishes", Progress.count("dishes") | (1 << type))


## Gifts earned by stars and not opened yet.
static func gifts_ready() -> int:
	return maxi(0, Progress.total_stars() / GIFT_EVERY - Progress.count("gifts"))


## Stars collected towards the next gift (x) out of GIFT_EVERY (y).
static func gift_progress() -> Vector2i:
	if gifts_ready() > 0:
		return Vector2i(GIFT_EVERY, GIFT_EVERY)
	return Vector2i(Progress.total_stars() - Progress.count("gifts") * GIFT_EVERY, GIFT_EVERY)


## Opens one gift: adds its coins and returns them (0 if none is ready).
static func open_gift() -> int:
	if gifts_ready() <= 0:
		return 0
	Progress.set_count("gifts", Progress.count("gifts") + 1)
	Progress.add_coins(GIFT_COINS)
	return GIFT_COINS
