class_name SushiLevel
extends RefCounted
## One Sushi Loop level as baked in data/levels/sushi_v2.json: the belt (a plate type per slot, -1
## for empty), the bento queue and the knobs (open bentos, window, counter, queue preview), plus
## the generator's ratings. Rules: docs/SUSHI_LOOP.md. In the file the belt and queue are short
## strings ("01.2" = types 0, 1, an empty slot, type 2; "a" = a covered type 0, "*" a chef's
## special), so a thousand levels stay small.

const MIN_BELT: int = 12
const MAX_BELT: int = 32
## Dishes (types 0-6). The chef's special is WILD, not a dish.
const TYPE_COUNT: int = 7
## The chef's special (M3): fits any open bento.
const WILD: int = 7
## Character per plate type in the baked strings; COVERED for a covered plate (M1), EMPTY for an
## empty belt slot, WILD_CHAR for a chef's special.
const DIGITS: String = "0123456"
const COVERED: String = "abcdefg"
const EMPTY: String = "."
const WILD_CHAR: String = "*"
## Most takes a rush order may allow (it must fit the state's search key).
const MAX_RUSH: int = 30

var id: int = 0
var belt := PackedInt32Array()
var bentos := PackedInt32Array()
var open: int = 2
var window: int = 3
var counter: int = 5
## Queued bentos shown after the open ones (display and the careful bot only).
var preview: int = 2
## easy, medium, hard, super, rest (the sawtooth role).
var role: String = "easy"
## Smallest counter that still solves it (-1 = not rated).
var par: int = -1
## The most plates the counter may hold for 3 stars.
var star_peak: int = 5
## Bot win rates over 200 runs (-1 = not rated).
var greedy: float = -1.0
var careful: float = -1.0
var seed: int = 0
## Bit i set: the plate in belt slot i is covered (M1).
var covers: int = 0
## Per queued bento: takes allowed once it opens (M2), 0 = no rush. Empty when nothing rushes.
var rush := PackedInt32Array()


static func make(belt_types: Array, bento_types: Array, open_count: int = 2, window_size: int = 3,
		counter_size: int = 5) -> SushiLevel:
	var level := SushiLevel.new()
	level.belt = PackedInt32Array(belt_types)
	level.bentos = PackedInt32Array(bento_types)
	level.open = open_count
	level.window = window_size
	level.counter = counter_size
	level.star_peak = counter_size
	return level


static func from_dict(d: Dictionary) -> SushiLevel:
	var level := SushiLevel.new()
	level.id = int(d.get("id", 0))
	level.belt = _ints(d.get("belt", []))
	level.covers = _covers(d.get("belt", []))
	level.bentos = _ints(d.get("bentos", []))
	level.rush = _ints(d.get("rush", []))
	if d.has("rate"):
		level.greedy = float(d.rate[0])
		level.careful = float(d.rate[1])
	level.open = int(d.get("open", 2))
	level.window = int(d.get("window", 3))
	level.counter = int(d.get("counter", 5))
	level.preview = int(d.get("preview", 2))
	level.role = str(d.get("role", "easy"))
	level.par = int(d.get("par", -1))
	level.star_peak = int(d.get("star_peak", level.counter))
	if not d.has("rate"):
		level.greedy = float(d.get("greedy", -1.0))
		level.careful = float(d.get("careful", -1.0))
	level.seed = int(d.get("seed", 0))
	return level


## Belt and queue as strings, the bot ratings as "rate": [greedy, careful], and the seed unless
## `with_seed` is off (the baked file leaves it out: the game never needs it).
func to_dict(with_seed: bool = true) -> Dictionary:
	var out := {
		"id": id, "role": role, "belt": _text(belt, covers), "bentos": _text(bentos), "open": open,
		"window": window, "counter": counter, "preview": preview, "par": par, "star_peak": star_peak,
		"rate": [snappedf(greedy, 0.005), snappedf(careful, 0.005)],
	}
	if has_rush():
		out.rush = Array(rush)
	if with_seed:
		out.seed = seed
	return out


func is_covered(slot: int) -> bool:
	return (covers >> slot) & 1 == 1


## The rush limit of queued bento `index` (M2), 0 when it does not rush.
func rush_of(index: int) -> int:
	return rush[index] if index >= 0 and index < rush.size() else 0


func has_rush() -> bool:
	for limit in rush:
		if limit > 0:
			return true
	return false


func wild_count() -> int:
	return belt.count(WILD)


## "" when the level can be played: sizes in range, and 3 plates per bento of its dish where each
## chef's special stands in for one of them (M3).
func validate() -> String:
	if belt.size() < MIN_BELT or belt.size() > MAX_BELT:
		return "belt has %d slots (%d-%d)" % [belt.size(), MIN_BELT, MAX_BELT]
	if bentos.is_empty() or bentos.size() > 62:
		return "%d bentos (1-62)" % bentos.size()
	if open < 1 or open > 2:
		return "open is %d (1 or 2)" % open
	if window < 1 or window >= belt.size():
		return "window is %d" % window
	if counter < 0:
		return "counter is %d" % counter
	var plates: Dictionary[int, int] = {}
	var wilds := 0
	for slot in belt.size():
		var t := belt[slot]
		if t < -1 or t > WILD:
			return "unknown plate type %d" % t
		if t == WILD:
			wilds += 1
		elif t >= 0:
			plates[t] = plates.get(t, 0) + 1
		if is_covered(slot) and (t < 0 or t == WILD):
			return "slot %d is covered but holds no dish" % slot
	if covers >> belt.size() != 0:
		return "a cover lies beyond the belt"
	var needed: Dictionary[int, int] = {}
	for t in bentos:
		if t < 0 or t >= TYPE_COUNT:
			return "unknown bento type %d" % t
		needed[t] = needed.get(t, 0) + 3
	var short := 0
	for t: int in needed:
		if plates.get(t, 0) > needed[t]:
			return "type %d has %d plates for %d bentos" % [t, plates.get(t, 0), needed[t] / 3]
		short += needed[t] - plates.get(t, 0)
	if short != wilds:
		return "%d plates missing but %d chef's specials" % [short, wilds]
	for t: int in plates:
		if not needed.has(t):
			return "type %d has plates but no bento" % t
	if not rush.is_empty():
		if rush.size() != bentos.size():
			return "rush has %d limits for %d bentos" % [rush.size(), bentos.size()]
		for limit in rush:
			if limit < 0 or limit > MAX_RUSH:
				return "rush limit %d (0-%d)" % [limit, MAX_RUSH]
	return ""


## Plates on the belt at the start (3 per bento).
func plate_count() -> int:
	return bentos.size() * 3


## How many different plate types the level uses.
func type_count() -> int:
	var seen: Dictionary[int, bool] = {}
	for t in bentos:
		seen[t] = true
	return seen.size()


## Types from an array of ints or a baked string ("01.2", "a" = covered type 0, "*" = WILD).
static func _ints(values: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if values is Array:
		for v: Variant in values:
			out.append(int(v))
	elif values is String:
		for c: String in values:
			if c == EMPTY:
				out.append(-1)
			elif c == WILD_CHAR:
				out.append(WILD)
			elif COVERED.contains(c):
				out.append(COVERED.find(c))
			else:
				out.append(DIGITS.find(c))
	return out


## The covered slots of a baked belt string, as a bit mask (0 for an array belt).
static func _covers(values: Variant) -> int:
	var mask := 0
	if values is String:
		var text: String = values
		for i in text.length():
			if COVERED.contains(text[i]):
				mask |= 1 << i
	return mask


static func _text(types: PackedInt32Array, covered: int = 0) -> String:
	var out := ""
	for i in types.size():
		var t := types[i]
		if t < 0:
			out += EMPTY
		elif t == WILD:
			out += WILD_CHAR
		elif (covered >> i) & 1 == 1:
			out += COVERED[t]
		else:
			out += DIGITS[t]
	return out
