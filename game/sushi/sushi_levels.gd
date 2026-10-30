class_name SushiLevels
extends RefCounted
## The baked Sushi Loop levels (data/levels/sushi_v3.json, made by tools/levelgen/generate_sushi.gd),
## loaded once and handed out by number (1-based). Never generated at run time.

const PATH := "res://data/levels/sushi_v3.json"
const GEN_VERSION: int = 3
## Levels per chapter (the sawtooth repeats every 10).
const CHAPTER: int = 10

static var _levels: Array[SushiLevel] = []


static func count() -> int:
	return all().size()


## Level `number` (1-based, clamped to the baked range).
static func level(number: int) -> SushiLevel:
	var levels := all()
	return levels[clampi(number, 1, levels.size()) - 1]


static func all() -> Array[SushiLevel]:
	if _levels.is_empty():
		_levels = load_file(PATH)
	return _levels


static func load_file(path: String) -> Array[SushiLevel]:
	var out: Array[SushiLevel] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("SushiLevels: cannot read %s" % path)
		return out
	for d: Dictionary in (data as Dictionary).get("levels", []):
		out.append(SushiLevel.from_dict(d))
	return out


static func gen_version(path: String = PATH) -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int((data as Dictionary).get("gen_version", 0)) if data is Dictionary else 0


## 1-based chapter of level `number`.
static func chapter(number: int) -> int:
	return (number - 1) / CHAPTER + 1
