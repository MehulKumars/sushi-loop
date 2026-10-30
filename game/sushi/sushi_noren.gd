class_name SushiNoren
extends Control
## The shop curtain on the home screen: a wooden rod with end knobs and split cloth panels in the
## chapter's colour, printed with a seigaiha wave pattern and one word of the shop's name each.
## Set the words and font before adding it. Each panel draws once and sways by a tiny rotation
## (no redraw per frame; still with Reduce Motion).

const GAP: float = 10.0
const ROD: float = 18.0
## How far the cloth sits in from each end of the rod.
const INSET: float = 20.0

var color := Color("1F3F6B"):
	set(value):
		color = value
		for cloth in _cloths:
			cloth.color = value
## One word per panel ("Sushi", "Loop"); without words the curtain has `panels` blank panels.
var words := PackedStringArray()
var panels: int = 4
var font: Font
var font_size: int = 84
var ink := Color("F6EFE3")
## The bottom of the cloth hidden behind whatever stands in front (the belt): words centre in the rest.
var hidden_hem: float = 0.0

var _cloths: Array[Cloth] = []
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var count := words.size() if not words.is_empty() else panels
	for i in count:
		var cloth := Cloth.new()
		cloth.color = color
		cloth.word = words[i] if i < words.size() else ""
		cloth.font = font
		cloth.font_size = font_size
		cloth.ink = ink
		cloth.hidden_hem = hidden_hem
		_cloths.append(cloth)
		add_child(cloth)
	_lay_out()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_lay_out()


func _process(delta: float) -> void:
	if Juice.motion_scale <= 0.0 or not is_visible_in_tree():
		return
	_time += delta
	for i in _cloths.size():
		_cloths[i].rotation = sin(_time * 0.9 + float(i) * 1.3) * 0.012 * Juice.motion_scale


func _draw() -> void:
	var wood := Color("8A6A45")
	var dark := Color("6E5234")
	draw_rect(Rect2(Vector2(ROD * 0.5, 0.0), Vector2(size.x - ROD, ROD)), wood)
	draw_rect(Rect2(Vector2(ROD * 0.5, ROD - 4.0), Vector2(size.x - ROD, 4.0)), dark)
	for x: float in [ROD * 0.7, size.x - ROD * 0.7]:
		draw_circle(Vector2(x, ROD * 0.5), ROD * 0.7, dark)
		draw_circle(Vector2(x, ROD * 0.5 - 1.5), ROD * 0.55, wood)


func _lay_out() -> void:
	var count := _cloths.size()
	if count == 0:
		return
	var width := (size.x - INSET * 2.0 - GAP * float(count - 1)) / float(count)
	for i in count:
		_cloths[i].position = Vector2(INSET + float(i) * (width + GAP), ROD * 0.5)
		_cloths[i].size = Vector2(width, size.y - ROD * 0.5)
		_cloths[i].pivot_offset = Vector2(width * 0.5, 0.0)


## One cloth panel with its wave print and its word.
class Cloth extends Control:
	var color := Color("1F3F6B"):
		set(value):
			color = value
			queue_redraw()
	var word := ""
	var font: Font
	var font_size: int = 84
	var ink := Color.WHITE
	var hidden_hem: float = 0.0

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
		# Soft side edges: a swaying rectangle would show stair steps along its long sides.
		for x: float in [0.5, size.x - 0.5]:
			draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.5, true)
		_draw_word()

	## The word centred in the part of the cloth that shows (below the rod, above the hidden hem),
	## shrunk to fit the panel, with a soft dye shadow.
	func _draw_word() -> void:
		if word == "" or font == null:
			return
		var room := size.x - 32.0
		var fs := font_size
		var wide := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if wide > room:
			fs = int(float(fs) * room / wide)
		var middle := (SushiNoren.ROD * 0.5 + size.y - hidden_hem) * 0.5
		var baseline := middle + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(0, baseline + 5.0), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color.darkened(0.45))
		draw_string(font, Vector2(0, baseline), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, ink)

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
