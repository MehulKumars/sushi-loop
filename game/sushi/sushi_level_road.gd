class_name SushiLevelRoad
extends Control
## The home screen's map of one chapter: its levels as plates on a winding dotted trail, the first
## at the bottom. Won plates show their stars and replay on a tap; the next level is the big gold
## plate; hard and super-hard levels carry a tag; a locked plate only wobbles. Used by
## ui/screens/main_menu.gd, which listens to `chosen` and `locked`.

signal chosen(level: int)
signal locked(level: int)

const PLATE: float = 96.0
const NEXT_PLATE: float = 120.0
## The trail snakes through these x positions (share of the width), bottom to top.
const COLUMNS: Array[float] = [0.5, 0.76, 0.5, 0.24]
const DOT_GAP: float = 24.0
const DOT_RADIUS: float = 5.0
## Room kept free above the top plate (for its tag) and below the bottom one.
const TOP_ROOM: float = 74.0
const BOTTOM_ROOM: float = 66.0

var _plates: Array[RoadPlate] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


## Shows chapter `chapter` (1-based) with the player's stars and the next level to play.
func show_chapter(chapter: int) -> void:
	for plate in _plates:
		plate.queue_free()
	_plates.clear()
	var levels := SushiMeta.chapter_range(chapter)
	var next := Progress.next_level(SushiLevels.count())
	for id in range(levels.x, levels.y + 1):
		var plate := RoadPlate.new()
		plate.level = id
		plate.stars = Progress.stars(id)
		plate.role = SushiLevels.level(id).role
		if plate.stars > 0:
			plate.state = RoadPlate.State.WON
		elif id == next:
			plate.state = RoadPlate.State.NEXT
		else:
			plate.state = RoadPlate.State.LOCKED
		plate.tooltip_text = "Level %d" % id
		plate.pressed.connect(_on_plate.bind(plate))
		add_child(plate)
		_plates.append(plate)
	_layout()


## The plate of `level` if it is on the road (for tests and the intro).
func plate_of(level: int) -> Button:
	for plate in _plates:
		if plate.level == level:
			return plate
	return null


func _on_plate(plate: RoadPlate) -> void:
	if plate.state == RoadPlate.State.LOCKED:
		plate.wobble()
		locked.emit(plate.level)
	else:
		chosen.emit(plate.level)


func _layout() -> void:
	if _plates.is_empty():
		return
	var step := (size.y - TOP_ROOM - BOTTOM_ROOM) / maxf(_plates.size() - 1, 1)
	for i in _plates.size():
		var plate := _plates[i]
		var side := NEXT_PLATE if plate.state == RoadPlate.State.NEXT else PLATE
		plate.size = Vector2(side, side)
		plate.pivot_offset = plate.size * 0.5
		plate.position = _center(i, step) - plate.size * 0.5
	queue_redraw()


func _center(i: int, step: float) -> Vector2:
	return Vector2(size.x * COLUMNS[i % COLUMNS.size()], size.y - BOTTOM_ROOM - step * i)


## The trail: dots along S-curves between the plates, gold up to the next level, faint after it.
func _draw() -> void:
	if _plates.size() < 2:
		return
	var step := (size.y - TOP_ROOM - BOTTOM_ROOM) / maxf(_plates.size() - 1, 1)
	var reached := 0
	for i in _plates.size():
		if _plates[i].state != RoadPlate.State.LOCKED:
			reached = i
	var gold := SushiPalette.GOLD
	var faint := Color(SushiPalette.INK, 0.18)
	var carry := 0.0
	for i in _plates.size() - 1:
		var a := _center(i, step)
		var b := _center(i + 1, step)
		var bend := Vector2(0.0, (b.y - a.y) * 0.55)
		var last := a
		for s in range(1, 25):
			var t := float(s) / 24.0
			var point := a.bezier_interpolate(a + bend, b - bend, b, t)
			carry += last.distance_to(point)
			last = point
			if carry >= DOT_GAP:
				carry = 0.0
				draw_circle(point, DOT_RADIUS, gold if i < reached else faint, true, -1.0, true)


## One level on the road: a porcelain plate with its number, its stars once won (a lock while
## locked), a gold rim and a slow glow when it is the next level, a tag when it is hard.
class RoadPlate extends Button:
	enum State { WON, NEXT, LOCKED }

	const LOCKED_RIM := Color("CFC5B4")
	const SUPER_RIM := Color("4A2C5E")

	var level: int = 0
	var stars: int = 0
	var role: String = "easy"
	var state: State = State.LOCKED
	## 0..1, the glow ring of the next level (animated).
	var glow: float = 0.0:
		set(value):
			glow = value
			queue_redraw()

	func _init() -> void:
		flat = true
		text = ""
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		if state == State.NEXT and Juice.motion_scale > 0.0:
			var tween := create_tween().set_loops()
			tween.tween_property(self, ^"glow", 1.0, 1.4).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	## A small no: the plate shakes a little.
	func wobble() -> void:
		if Juice.motion_scale <= 0.0:
			return
		var tween := create_tween()
		for angle: float in [0.12, -0.1, 0.06, 0.0]:
			tween.tween_property(self, ^"rotation", angle * Juice.motion_scale, 0.06)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.44
		var dim := state == State.LOCKED
		var alpha := 0.6 if dim else 1.0
		draw_circle(c + Vector2(0.0, r * 0.12), r, Color(0, 0, 0, 0.14 * alpha), true, -1.0, true)
		if state == State.NEXT and glow > 0.0:
			draw_circle(c, r + 4.0 + 14.0 * glow, Color(SushiPalette.GOLD, 0.4 * (1.0 - glow)), true, -1.0, true)
		draw_circle(c, r, _rim(), true, -1.0, true)
		draw_circle(c, r * 0.8, Color(SushiPalette.PORCELAIN_SHADE, alpha), true, -1.0, true)
		draw_circle(c + Vector2(-0.02, -0.03) * r, r * 0.75, Color(SushiPalette.PORCELAIN, alpha), true, -1.0, true)
		draw_arc(c, r * 0.9, PI * 1.08, PI * 1.42, 10, Color(1, 1, 1, 0.5 * alpha), r * 0.07, true)
		var font := get_theme_font(&"font", &"ValueLabel")
		var font_size := 40 if state == State.NEXT else 32
		var number := str(level)
		var middle := c.y - (r * 0.16 if state != State.NEXT else 0.0)
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := middle + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(c.x - width * 0.5, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(SushiPalette.INK, 0.45 if dim else 1.0))
		if state == State.WON:
			var side := r * 0.36
			for i in 3:
				var at := Vector2(c.x + (i - 1) * side * 1.05 - side * 0.5, c.y + r * 0.22)
				var tint := SushiPalette.GOLD if i < stars else Color(SushiPalette.INK, 0.18)
				draw_texture_rect(Icons.STAR, Rect2(at, Vector2(side, side)), false, tint)
		elif dim:
			# A lock, so a locked plate never reads by its faded colour alone.
			var side := r * 0.42
			draw_texture_rect(Icons.LOCK, Rect2(Vector2(c.x - side * 0.5, c.y + r * 0.12), Vector2(side, side)),
					false, Color(SushiPalette.INK, 0.5))
		if role == "hard" or role == "super":
			_draw_tag(c + Vector2(0.0, -r - 14.0), "Hard" if role == "hard" else "Super hard", alpha)

	func _rim() -> Color:
		if state == State.LOCKED:
			return LOCKED_RIM
		if state == State.NEXT:
			return SushiPalette.GOLD
		match role:
			"hard":
				return SushiPalette.VERMILLION
			"super":
				return SUPER_RIM
		return SushiPalette.BLUE

	func _draw_tag(at: Vector2, words: String, alpha: float) -> void:
		var font := get_theme_font(&"font", &"ValueLabel")
		var font_size := 20
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var rect := Rect2(at.x - width * 0.5 - 12.0, at.y - 15.0, width + 24.0, 30.0)
		var fill := SushiPalette.VERMILLION if role == "hard" else SUPER_RIM
		draw_style_box(_pill(Color(fill, alpha)), rect)
		var baseline := at.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(at.x - width * 0.5, baseline), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(SushiPalette.CREAM, alpha))

	static func _pill(fill: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(15)
		box.anti_aliasing = true
		return box
