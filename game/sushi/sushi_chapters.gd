class_name SushiChapters
extends RefCounted
## Each chapter's twist (docs/SUSHI_LOOP.md "Levels"): the knob its levels lean on, named on the
## card that opens the chapter. Chapters 1-8 teach one twist each (chapters 3, 5 and 7 bring the
## new mechanics M1-M3); then the twists come round again, and from DOUBLE_FROM two at a time.
## The level plan (tools/levelgen/sushi_plan.gd) reads the same ids, so the card always tells the
## truth about the levels behind it.

const FIRST: Array[StringName] = [&"learn", &"more", &"covered", &"narrow", &"rush", &"single", &"wild", &"hidden"]
## After chapter 8, in this order, over and over. "mixed" gives each level one of the others.
const CYCLE: Array[StringName] = [&"long", &"covered", &"narrow", &"rush", &"single", &"wild", &"hidden", &"dense", &"tight", &"mixed"]
## Twists a "mixed" level (and a second twist) is chosen from.
const SINGLES: Array[StringName] = [&"long", &"covered", &"narrow", &"rush", &"single", &"wild", &"hidden", &"dense", &"tight"]
## From this chapter on, each chapter (but a mixed one) has a second twist.
const DOUBLE_FROM: int = 21

const LABELS: Dictionary[StringName, String] = {
	&"learn": "First shift",
	&"more": "More dishes",
	&"covered": "Covered dishes",
	&"rush": "Rush orders",
	&"wild": "Chef's special",
	&"narrow": "Two-plate window",
	&"single": "One bento at a time",
	&"hidden": "No peeking",
	&"long": "Long loops",
	&"dense": "Full belt",
	&"tight": "Small counter",
	&"mixed": "Mixed tables",
}
const TEXTS: Dictionary[StringName, String] = {
	&"learn": "Take plates from the gold window and pack each bento with three of a kind.",
	&"more": "More dishes ride the belt, and the loops grow longer.",
	&"covered": "Some plates arrive under a cloche: you only see the dish once it reaches the window.",
	&"rush": "A rush bento shows a number: pack it within that many takes, or the customer leaves.",
	&"wild": "The gold plate is the chef's special: it fills a gap in the fullest bento. Take it at the right moment.",
	&"narrow": "A two-plate window: fewer choices, so each one counts.",
	&"single": "One bento open at a time. The counter has more room to help.",
	&"hidden": "No peeking: the next bentos stay hidden until they open.",
	&"long": "Long loops tonight: more plates, more bentos, more to keep in mind.",
	&"dense": "A full belt: no gaps, so a new plate reaches the window every take.",
	&"tight": "A small counter, but you can see three bentos ahead.",
	&"mixed": "A little of everything: each table has its own rule.",
}
## Pairs never doubled up: tight shows three bentos and hidden none; a full belt with one bento
## open leaves no fair deal that also beats mindless tapping.
const CLASHES: Array[Array] = [[&"hidden", &"tight"], [&"dense", &"single"]]


## The twists of 1-based `chapter`: one, or two from DOUBLE_FROM on.
static func twists(chapter: int) -> Array[StringName]:
	if chapter <= FIRST.size():
		return [FIRST[maxi(chapter, 1) - 1]]
	var turn := chapter - FIRST.size() - 1
	var main := CYCLE[turn % CYCLE.size()]
	if chapter < DOUBLE_FROM or main == &"mixed":
		return [main]
	# The partner rotates one step further each time round, so the pairs keep changing.
	var round_ := turn / CYCLE.size()
	for step in SINGLES.size():
		var second := SINGLES[(turn + round_ + 1 + step) % SINGLES.size()]
		if second != main and not clashes(main, second):
			return [main, second]
	return [main]


## The twist a level of a "mixed" chapter uses (level `id`, 1-based).
static func mixed_twist(id: int) -> StringName:
	return SINGLES[posmod(id * 7 + id / 10, SINGLES.size())]


static func clashes(a: StringName, b: StringName) -> bool:
	for pair in CLASHES:
		if pair.has(a) and pair.has(b):
			return true
	return false


## A short name for the chapter's twist(s), for badges.
static func label(chapter: int) -> String:
	var list := twists(chapter)
	if list.size() == 1:
		return LABELS[list[0]]
	return "%s + %s" % [LABELS[list[0]], LABELS[list[1]].to_lower()]


## The line on the card that opens the chapter.
static func text(chapter: int) -> String:
	var list := twists(chapter)
	if list.size() == 1:
		return TEXTS[list[0]]
	return "Two twists tonight. %s %s" % [TEXTS[list[0]], TEXTS[list[1]]]
