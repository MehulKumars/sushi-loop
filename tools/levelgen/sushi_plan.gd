class_name SushiPlan
extends RefCounted
## The level plan (docs/SUSHI_LOOP.md "Levels"): for every level number its sawtooth role, the
## knobs its deal uses and the band both bots must land in. Levels 1-60 are frozen from the first
## bake (tuned and playtested on phones); later levels follow the chapter twists in SushiChapters,
## so the chapter card always describes them. Used by tools/levelgen/generate_sushi.gd only.

const COUNT: int = 1000
const GEN_VERSION: int = 2
## Levels 1..FROZEN_UNTIL are copied from this file, unchanged.
const FROZEN_PATH: String = "res://tools/levelgen/frozen_v1.json"
const FROZEN_UNTIL: int = 60

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
## one), and the smallest par (counter the level needs) per role. Pass estimates at the middles:
## easy and rest about 0.93 (one try), medium 0.8, hard 0.55 (two tries), super about 0.4 (two
## to three; deals with a lower careful rate tend to hang on one narrow line, so the band stops
## at 0.35).
const BANDS: Dictionary[String, Dictionary] = {
	"easy": {"greedy": [0.75, 0.95], "careful": [0.95, 1.0], "par_min": 0},
	"medium": {"greedy": [0.4, 0.85], "careful": [0.85, 1.0], "par_min": 1},
	"hard": {"greedy": [0.1, 0.45], "careful": [0.55, 0.85], "par_min": 2},
	"super": {"greedy": [0.0, 0.2], "careful": [0.35, 0.75], "par_min": 2},
	"rest": {"greedy": [0.7, 1.0], "careful": [0.95, 1.0], "par_min": 0},
}
## How far plates stray from their bento's turn (0 = in order, 1 = random), per role.
const SPREADS: Dictionary[String, Array] = {
	"easy": [0.2, 0.6], "medium": [0.3, 1.0], "hard": [0.5, 1.0], "super": [0.6, 1.0], "rest": [0.1, 0.5],
}
## Belt length per role before the twists (more length = more to keep track of).
const BELTS: Dictionary[String, int] = {"easy": 21, "medium": 23, "hard": 24, "super": 24, "rest": 18}
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
## bentos, belt, open, window, counter, preview), "spread" [lo, hi] and "band".
static func spec(id: int) -> Dictionary:
	var r := role(id)
	var out := {"id": id, "role": r, "twists": twists(id), "frozen": id <= FROZEN_UNTIL}
	if out.frozen:
		return out
	var chapter := SushiLevels.chapter(id)
	var rng := SeedService.make_rng(["sushi-plan", id], GEN_VERSION)
	# Each time the twists come round again, belts grow a step (at most three).
	var lap := mini((chapter - SushiChapters.FIRST.size() - 1) / SushiChapters.CYCLE.size(), 3)
	var types := 7
	if r == "easy":
		types = 6
	elif r == "rest":
		types = rng.randi_range(5, 6)
	var belt := BELTS[r] + lap + rng.randi_range(-1, 2)
	var window := 3
	var open := 2
	var preview := 2
	var counter := 5
	match r:
		"hard", "super":
			counter = 4
		"rest":
			counter = 6
	var dense := false
	for twist in out.twists:
		match twist:
			&"narrow":
				window = 2
			&"single":
				open = 1
				counter += 1
			&"hidden":
				preview = 0
			&"long":
				belt = rng.randi_range(27, 32)
			&"dense":
				dense = true
			&"tight":
				counter -= 1
				preview = 3
	belt = clampi(belt, 15, SushiLevel.MAX_BELT)
	var bentos: int
	if dense:
		bentos = belt / 3
		belt = bentos * 3
	else:
		# Some empty slots, never fewer than one.
		bentos = mini(roundi(belt * rng.randf_range(0.78, 0.92) / 3.0), (belt - 1) / 3)
	bentos = clampi(bentos, 4, 10)
	out.merge({
		"types": mini(types, bentos), "bentos": bentos, "belt": belt, "open": open, "window": window,
		"counter": clampi(counter, 3, 7), "preview": preview, "spread": SPREADS[r], "band": BANDS[r],
	})
	return out
