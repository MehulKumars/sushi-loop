class_name SushiNoren
extends Control
## The shop curtain across the top of the home screen: a wooden rod and split cloth panels in the
## chapter's colour, printed with a seigaiha wave pattern. Each panel draws once and sways by a
## tiny rotation (no redraw per frame; still with Reduce Motion). Decorative, behind the top bar.

const PANELS: int = 4
const GAP: float = 10.0
const ROD: float = 18.0

var color := Color("1F3F6B"):
	set(value):
		color = value
		for cloth in _cloths:
			cloth.color = value

var _cloths: Array[Cloth] = []
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PANELS:
		var cloth := Cloth.new()
		_cloths.append(cloth)
		add_child(cloth)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var width := (size.x - GAP * float(PANELS - 1)) / float(PANELS)
		for i in PANELS:
			_cloths[i].position = Vector2(float(i) * (width + GAP), ROD * 0.5)
			_cloths[i].size = Vector2(width, size.y - ROD * 0.5)
			_cloths[i].pivot_offset = Vector2(width * 0.5, 0.0)


func _process(delta: float) -> void:
	if Juice.motion_scale <= 0.0 or not is_visible_in_tree():
		return
	_time += delta
	for i in PANELS:
		_cloths[i].rotation = sin(_time * 0.9 + float(i) * 1.3) * 0.012 * Juice.motion_scale


func _draw() -> void:
	draw_rect(Rect2(Vector2(-10, 0), Vector2(size.x + 20, ROD)), Color("8A6A45"))
	draw_rect(Rect2(Vector2(-10, ROD - 4), Vector2(size.x + 20, 4)), Color("6E5234"))


## One cloth panel with its wave print.
class Cloth extends Control:
	var color := Color("1F3F6B"):
		set(value):
			color = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, 6), size), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), color)
		# Seigaiha: rows of overlapping wave arcs, every other row shifted by half a wave.
		var line := Color(color.lightened(0.16), 0.55)
		var r := 22.0
		var row := 0
		var y := r
		while y < size.y + r * 0.5:
			var cx := -r + (r if row % 2 == 1 else 0.0)
			while cx < size.x + r:
				for k in 3:
					_arc(Vector2(cx, y), r * (1.0 - 0.3 * float(k)), line)
				cx += r * 2.0
			y += r * 0.55
			row += 1
		draw_line(Vector2(0, size.y), Vector2(size.x, size.y), color.darkened(0.25), 4.0)

	## The upper half of a circle, only where it stays inside the panel.
	func _arc(c: Vector2, r: float, line: Color) -> void:
		var points := PackedVector2Array()
		for i in 13:
			var p := c + Vector2.from_angle(PI + PI * float(i) / 12.0) * r
			if p.x < 2.0 or p.x > size.x - 2.0 or p.y < 2.0 or p.y > size.y - 4.0:
				if points.size() > 1:
					draw_polyline(points, line, 2.0, true)
				points.clear()
				continue
			points.append(p)
		if points.size() > 1:
			draw_polyline(points, line, 2.0, true)
