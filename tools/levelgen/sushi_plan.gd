class_name SushiPlan
extends RefCounted
## The level plan (docs/SUSHI_LOOP.md "Levels"): for every level number its sawtooth role, the
## knobs its deal uses (dishes, belt, window, counter, preview, covered share, rush orders, chef's
## specials), the band both bots must land in, and the "needs thought" rules. Levels 1-2 are the
## hand-made tutorials; later levels follow SushiChapters. Used by tools/levelgen/ only.

const COUNT: int = 1000
const GEN_VERSION: int = 3
## Levels 1..FROZEN_UNTIL are copied from this file, unchanged (the hand-made tutorials).
const FROZEN_PATH: String = "res://tools/levelgen/frozen_v1.json"
const FROZEN_UNTIL: int = 2
## From this level on, every non-rest level must beat both spam players (SushiBot.SPAM_*).
const THOUGHT_FROM: int = 4
## From this chapter on (rush orders exist), super-hard levels must also beat "take what fits"
## played perfectly; one with neither a rush order nor a chef's special in its twists gets one.
const RULE_OF_THUMB_FAILS_FROM: int = 5
## From this chapter on (chef's specials exist), every other chapter's super level gets a special.
const SPECIAL_SUPERS_FROM: int = 7

## Roles per ten levels. Slots 5 (hard), 6 (rest), 9 (super) and 10 (rest) never move; as the
## game goes on, easy slots turn medium and a second hard level arrives. Chapter 1 (the
## tutorials) has a third easy level.
const ROLES_FIRST: Array[String] = ["easy", "easy", "easy", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_EARLY: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "medium", "super", "rest"]
const ROLES_MID: Array[String] = ["easy", "easy", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]
const ROLES_LATE: Array[String] = ["easy", "medium", "medium", "medium", "hard", "rest", "medium", "hard", "super", "rest"]
const MID_FROM_CHAPTER: int = 11
const LATE_FROM_CHAPTER: int = 41

## Win-rate bands of the random-greedy bot (a careless player) and the careful bot (an attentive
## one, slipping one take in ten), and the smallest par (counter the level needs) per role. A
## super-hard level also defeats the careful rule played perfectly, so only the careful bot's
## slips (and a thinking player) win it: its careful band starts lower.
const BANDS: Dictionary[String, Dictionary] = {
	"easy": {"greedy": [0.6, 0.95], "careful": [0.9, 1.0], "par_min": 0},
	"medium": {"greedy": [0.3, 0.8], "careful": [0.75, 1.0], "par_min": 1},
	"hard": {"greedy": [0.05, 0.4], "careful": [0.45, 0.85], "par_min": 2},
	"super": {"greedy": [0.0, 0.15], "careful": [0.15, 0.6], "par_min": 2},
	"rest": {"greedy": [0.7, 1.0], "careful": [0.95, 1.0], "par_min": 0},
}
## A super-hard level before RULE_OF_THUMB_FAILS_FROM: careful play still wins it, greedy rarely.
const CLASSIC_SUPER: Dictionary = {"greedy": [0.0, 0.2], "careful": [0.35, 0.75], "par_min": 2}
## Gentler bands for the first chapter, while players learn the belt.
const FIRST_BANDS: Dictionary[String, Dictionary] = {
	"easy": {"greedy": [0.75, 1.0], "careful": [0.97, 1.0], "par_min": 0},
	"medium": {"greedy": [0.5, 0.95], "careful": [0.9, 1.0], "par_min": 1},
	"hard": {"greedy": [0.3, 0.8], "careful": [0.8, 1.0], "par_min": 2},
	"super": {"greedy": [0.1, 0.55], "careful": [0.6, 0.95], "par_min": 2},
	"rest": {"greedy": [0.85, 1.0], "careful": [0.98, 1.0], "par_min": 0},
}
## How far plates stray from their bento's turn (0 = in order, 1 = random), per role.
const SPREADS: Dictionary[String, Array] = {
	"easy": [0.3, 0.8], "medium": [0.4, 1.0], "hard": [0.5, 1.0], "super": [0.6, 1.0], "rest": [0.1, 0.5],
}
## Belt length per role before the twists (more length = more to keep track of).
const BELTS: Dictionary[String, int] = {"easy": 21, "medium": 23, "hard": 24, "super": 24, "rest": 18}
## Chapter 1, levels 3-10: dishes, bentos, belt, counter, preview (the counting starts gently).
const FIRST_CHAPTER: Dictionary[int, Array] = {
	3: [3, 4, 14, 5, 1], 4: [3, 5, 16, 5, 2], 5: [3, 5, 16, 4, 2], 6: [4, 5, 16, 5, 2],
	7: [4, 6, 18, 5, 2], 8: [4, 6, 18, 5, 2], 9: [4, 6, 18, 4, 2], 10: [4, 6, 18, 5, 2],
}
## Share of a pass the careful bot stands for in the pass estimate (the rest is the greedy bot).
const CAREFUL_SHARE: float = 0.6


static func role(id: int) -> String:
	var chapter := SushiLevels.chapter(id)
	var roles := ROLES_EARLY
	if chapter == 1:
		roles = ROLES_FIRST
	elif chapter >= LATE_FROM_CHAPTER:
		roles = ROLES_LATE
	elif chapter >= MID_FROM_CHAPTER:
		roles = ROLES_MID
	return roles[(id - 1) % roles.size()]


static func band(id: int) -> Dictionary:
	var r := role(id)
	var chapter := SushiLevels.chapter(id)
	if chapter == 1:
		return FIRST_BANDS[r]
	if r == "super" and chapter < RULE_OF_THUMB_FAILS_FROM:
		return CLASSIC_SUPER
	return BANDS[r]


## A rough first-try pass rate for a typical player, from the two bots' win rates.
static func pass_estimate(greedy: float, careful: float) -> float:
	return (1.0 - CAREFUL_SHARE) * greedy + CAREFUL_SHARE * careful


## The twists level `id` is dealt with (a mixed chapter gives each level one of its own).
static func twists(id: int) -> Array[StringName]:
	var list := SushiChapters.twists(SushiLevels.chapter(id))
	if list.has(&"mixed"):
		return [SushiChapters.mixed_twist(id)]
	return list


## {"id", "role", "twists", "frozen"} for frozen levels; otherwise also the deal knobs (types,
## bentos, belt, open, window, counter, preview, covers, rush, rush_limit, wilds), "spread"
## [lo, hi], "band", and the thought rules "anti_spam" and "careful_must_lose".
static func spec(id: int) -> Dictionary:
	var r := role(id)
	var out := {"id": id, "role": r, "twists": twists(id), "frozen": id <= FROZEN_UNTIL}
	if out.frozen:
		return out
	var chapter := SushiLevels.chapter(id)
	var rng := SeedService.make_rng(["sushi-plan", id], GEN_VERSION)
	var tough := r == "hard" or r == "super"
	# Each time the twists come round again, belts grow a step (at most three).
	var lap := clampi((chapter - SushiChapters.FIRST.size() - 1) / SushiChapters.CYCLE.size(), 0, 3)
	var types := 7
	var belt := BELTS[r] + lap + rng.randi_range(-1, 2)
	var counter := 5
	var preview := 2
	if chapter == 1:
		var row: Array = FIRST_CHAPTER[id]
		types = row[0]
		belt = row[2]
		counter = row[3]
		preview = row[4]
	else:
		if chapter == 2:
			types = 5 if r == "easy" or r == "rest" else 6
			belt = mini(belt, 22)
		elif r == "easy":
			types = 6
		elif r == "rest":
			types = rng.randi_range(5, 6)
		match r:
			"hard", "super":
				counter = 4
			"rest":
				counter = 6
	var window := 3
	var open := 2
	var dense := false
	var spread: Array = SPREADS[r]
	var covers := 0.0
	var rushes := 0
	var rush_limit := [6, 9]
	var wilds := 0
	for twist in out.twists:
		match twist:
			&"narrow":
				window = 2
			&"single":
				open = 1
				# A roomier counter helps, except on easy levels: there one bento makes the right take
				# obvious, so they get no extra slot, all seven dishes and a more scrambled belt.
				if r != "easy":
					counter += 1
				else:
					types = 7
					spread = [0.6, 1.0]
			&"hidden":
				preview = 0
			&"long":
				# A super-hard level keeps its loop at the short end, so a fair deal still exists.
				belt = rng.randi_range(27, 28 if r == "super" else 32)
			&"dense":
				dense = true
			&"tight":
				counter -= 1
				preview = 3
			&"covered":
				covers = clampf(0.4 + 0.1 * lap, 0.4, 0.7)
			&"rush":
				rushes = 2 if tough else 1
				rush_limit = [5, 8] if tough else [7, 10]
			&"wild":
				wilds = 2 if r == "hard" else 1
	# A super-hard level needs pressure to beat the rule of thumb: rush orders, or specials. With one
	# bento open at a time rush orders leave no fair deal, so it takes specials (or, before they
	# exist, stays a classic super-hard level).
	var rule_fails := r == "super" and chapter >= RULE_OF_THUMB_FAILS_FROM
	if rule_fails and rushes == 0 and wilds == 0:
		if chapter >= SPECIAL_SUPERS_FROM and (chapter % 2 == 0 or open == 1):
			wilds = 1
		elif open == 1:
			rule_fails = false
		else:
			rushes = 2
			rush_limit = [6, 9]
	# A super-hard level never drops below four counter slots (with its pressure, three is a wall).
	if r == "super":
		counter = maxi(counter, 4)
	# With one bento open at a time every other plate waits on the counter: rush orders get longer.
	if open == 1 and rushes > 0:
		rush_limit = [int(rush_limit[0]) + 3, int(rush_limit[1]) + 3]
	belt = clampi(belt, 14, SushiLevel.MAX_BELT)
	var bentos: int
	if chapter == 1:
		bentos = FIRST_CHAPTER[id][1]
	elif dense:
		bentos = belt / 3
		belt = bentos * 3
	else:
		# Some empty slots, never fewer than one.
		bentos = mini(roundi(belt * rng.randf_range(0.78, 0.92) / 3.0), (belt - 1) / 3)
	bentos = clampi(bentos, 4, 10)
	out.merge({
		"types": mini(types, bentos), "bentos": bentos, "belt": belt, "open": open, "window": window,
		"counter": clampi(counter, 3, 7), "preview": preview, "covers": covers, "rush": rushes,
		"rush_limit": rush_limit, "wilds": wilds, "spread": spread,
		"band": CLASSIC_SUPER if r == "super" and not rule_fails and chapter > 1 else band(id),
		"counter_min": 4 if r == "super" else 3,
		"anti_spam": id >= THOUGHT_FROM and r != "rest",
		"careful_must_lose": rule_fails,
	})
	return out
