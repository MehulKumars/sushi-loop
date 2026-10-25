class_name SushiArt
extends RefCounted
## Code-drawn Sushi Loop art: plates (porcelain with a coloured, patterned rim), the seven sushi
## silhouettes and bento boxes. Placeholders for the human-drawn silhouettes; every shape keeps an
## ink outline so rice reads on cream porcelain. Called from _draw() of the plate and bento views.

const OUTLINE: float = 2.5


## A plate of `type` centred at `c`, rim radius `r`. `alpha` fades it (ghosts, dimmed plates).
static func draw_plate(ci: CanvasItem, c: Vector2, r: float, type: int, alpha: float = 1.0) -> void:
	var rim := SushiPalette.rim_color(type)
	rim.a *= alpha
	var porcelain := Color(SushiPalette.CREAM, alpha)
	match SushiPalette.rim_style(type):
		SushiPalette.Rim.SOLID:
			ci.draw_circle(c, r, rim)
			ci.draw_circle(c, r * 0.8, porcelain)
		SushiPalette.Rim.DASHED:
			ci.draw_circle(c, r, porcelain)
			var dashes := 10
			for i in dashes:
				var a := TAU * float(i) / float(dashes)
				ci.draw_arc(c, r * 0.9, a, a + TAU / float(dashes) * 0.55, 6, rim, r * 0.2, true)
		SushiPalette.Rim.DOUBLE:
			ci.draw_circle(c, r, rim)
			ci.draw_circle(c, r * 0.9, porcelain)
			ci.draw_arc(c, r * 0.76, 0.0, TAU, 40, rim, r * 0.07, true)
			ci.draw_circle(c, r * 0.72, porcelain)
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(SushiPalette.INK, 0.35 * alpha), 1.5, true)
	draw_sushi(ci, c, r * 1.12, type, alpha)


## The sushi silhouette of `type` in a box of side `s` centred at `c`.
static func draw_sushi(ci: CanvasItem, c: Vector2, s: float, type: int, alpha: float = 1.0) -> void:
	var ink := Color(SushiPalette.INK, alpha)
	var rice := Color(SushiPalette.RICE, alpha)
	match type:
		0: # maki: a nori ring around rice and a salmon centre
			ci.draw_circle(c, s * 0.34, ink)
			ci.draw_circle(c, s * 0.27, rice)
			ci.draw_circle(c, s * 0.12, Color(SushiPalette.SALMON, alpha))
			ci.draw_circle(c + Vector2(s * 0.05, -s * 0.04), s * 0.045, Color(SushiPalette.LEAF, alpha))
		1: # nigiri: a rice pillow under a striped salmon slice
			_filled(ci, _capsule(Rect2(c + Vector2(-s * 0.36, -s * 0.02), Vector2(s * 0.72, s * 0.26))), rice, ink)
			var slice := _capsule(Rect2(c + Vector2(-s * 0.42, -s * 0.2), Vector2(s * 0.84, s * 0.24)))
			_filled(ci, slice, Color(SushiPalette.SALMON, alpha), ink)
			for i in 3:
				var x := -s * 0.18 + float(i) * s * 0.16
				ci.draw_line(c + Vector2(x, -s * 0.17), c + Vector2(x + s * 0.08, -s * 0.0), Color(SushiPalette.CREAM, 0.8 * alpha), s * 0.03, true)
		2: # onigiri: a rounded rice triangle with a nori band
			var tri := PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, s * 0.22), c + Vector2(-s * 0.3, s * 0.22)])
			var rounded := Geometry2D.offset_polygon(tri, s * 0.08, Geometry2D.JOIN_ROUND)
			if not rounded.is_empty():
				_filled(ci, rounded[0], rice, ink)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.14, s * 0.06), Vector2(s * 0.28, s * 0.24)), ink)
		3: # gunkan: a nori wrap topped with roe
			for i in 4:
				ci.draw_circle(c + Vector2(-s * 0.21 + float(i) * s * 0.14, -s * 0.14), s * 0.085, Color(SushiPalette.VERMILLION, alpha))
			_filled(ci, _capsule(Rect2(c + Vector2(-s * 0.32, -s * 0.12), Vector2(s * 0.64, s * 0.36)), 0.25), ink, ink)
			ci.draw_line(c + Vector2(-s * 0.28, s * 0.03), c + Vector2(s * 0.28, s * 0.03), Color(SushiPalette.CREAM, 0.35 * alpha), s * 0.03)
		4: # tamago: an egg block on rice, a nori belt
			_filled(ci, _capsule(Rect2(c + Vector2(-s * 0.32, s * 0.02), Vector2(s * 0.64, s * 0.22))), rice, ink)
			_filled(ci, _capsule(Rect2(c + Vector2(-s * 0.36, -s * 0.22), Vector2(s * 0.72, s * 0.3)), 0.2), Color(SushiPalette.EGG, alpha), ink)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.07, -s * 0.24), Vector2(s * 0.14, s * 0.5)), ink)
		5: # dango: three balls on a stick
			var a := c + Vector2(-s * 0.32, s * 0.32)
			var b := c + Vector2(s * 0.34, -s * 0.34)
			ci.draw_line(a, b, Color(SushiPalette.STICK, alpha), s * 0.06, true)
			var colours: Array[Color] = [SushiPalette.LEAF, SushiPalette.RICE, SushiPalette.PINK]
			for i in 3:
				var p := c + Vector2(-s * 0.15, s * 0.15).lerp(Vector2(s * 0.15, -s * 0.15), float(i) / 2.0)
				ci.draw_circle(p, s * 0.135, Color(colours[i], alpha))
				ci.draw_arc(p, s * 0.135, 0.0, TAU, 24, ink, OUTLINE, true)
		6: # temaki: a nori cone with rice and salmon at the open end
			var cone := PackedVector2Array([c + Vector2(-s * 0.06, s * 0.36), c + Vector2(-s * 0.32, -s * 0.18), c + Vector2(s * 0.3, -s * 0.18)])
			ci.draw_colored_polygon(cone, ink)
			ci.draw_circle(c + Vector2(-s * 0.02, -s * 0.2), s * 0.2, rice)
			ci.draw_arc(c + Vector2(-s * 0.02, -s * 0.2), s * 0.2, PI, TAU, 16, ink, OUTLINE, true)
			ci.draw_circle(c + Vector2(s * 0.06, -s * 0.24), s * 0.09, Color(SushiPalette.SALMON, alpha))
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.26), s * 0.06, Color(SushiPalette.LEAF, alpha))


## A bento box in `rect` with three cells; `cells` holds the sushi type in each (-1 empty) and
## `want` the type it takes (shown as a faint ghost in empty cells). `lid` (0-1) slides the lid on.
static func draw_bento(ci: CanvasItem, rect: Rect2, want: int, cells: PackedInt32Array, lid: float = 0.0,
		ribbon: float = 0.0) -> void:
	var radius := rect.size.y * 0.16
	_filled(ci, _rounded(rect, radius), SushiPalette.LACQUER, SushiPalette.INK)
	var inner := rect.grow(-rect.size.y * 0.08)
	_filled(ci, _rounded(inner, radius * 0.6), SushiPalette.LACQUER_RED, SushiPalette.LACQUER_RED)
	for i in 3:
		var cell := bento_cell(rect, i)
		_filled(ci, _rounded(cell, radius * 0.4), Color(SushiPalette.CREAM, 0.94), Color(SushiPalette.CREAM, 0.94))
		var side := minf(cell.size.x, cell.size.y) * 1.05
		var type := cells[i] if i < cells.size() else -1
		if type >= 0:
			draw_sushi(ci, cell.get_center(), side, type)
		elif want >= 0:
			draw_sushi(ci, cell.get_center(), side, want, 0.22)
	if lid > 0.0:
		# The lid drops from just above, fading in over the first part of the drop only.
		var lid_rect := Rect2(rect.position + Vector2(0, -rect.size.y * (1.0 - lid) * 0.5), rect.size)
		var shown := clampf(lid * 3.0, 0.0, 1.0)
		_filled(ci, _rounded(lid_rect, radius), Color(SushiPalette.LACQUER, shown), Color(SushiPalette.INK, shown))
		_filled(ci, _rounded(lid_rect.grow(-rect.size.y * 0.1), radius * 0.6), Color(SushiPalette.LACQUER_RED, shown * 0.9), Color(SushiPalette.LACQUER_RED, 0.0))
		ci.draw_arc(lid_rect.get_center(), lid_rect.size.y * 0.18, 0.0, TAU, 32, Color(SushiPalette.GOLD, shown), 3.0, true)
		if ribbon > 0.0:
			var gold := Color(SushiPalette.GOLD, ribbon)
			var w := lid_rect.size.y * 0.16 * ribbon
			ci.draw_rect(Rect2(Vector2(lid_rect.get_center().x - w * 0.5, lid_rect.position.y), Vector2(w, lid_rect.size.y)), gold)
			ci.draw_rect(Rect2(Vector2(lid_rect.position.x, lid_rect.get_center().y - w * 0.5), Vector2(lid_rect.size.x, w)), gold)
			ci.draw_circle(lid_rect.get_center(), w * 0.9, gold)


## A filled rounded rectangle with an outline (the board's wooden counter, the plank).
static func draw_panel(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, line: Color) -> void:
	_filled(ci, _rounded(rect, radius), fill, line)


## Cell `i` (0-2) of a bento box drawn in `rect`.
static func bento_cell(rect: Rect2, i: int) -> Rect2:
	var inner := rect.grow(-rect.size.y * 0.08)
	var gap := inner.size.y * 0.06
	var cell_w := (inner.size.x - gap * 4.0) / 3.0
	return Rect2(inner.position + Vector2(gap + float(i) * (cell_w + gap), gap), Vector2(cell_w, inner.size.y - gap * 2.0))


static func _filled(ci: CanvasItem, points: PackedVector2Array, fill: Color, line: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, line, OUTLINE, true)


## Points of a capsule (or a rounded rectangle when `roundness` < 0.5) filling `rect`.
static func _capsule(rect: Rect2, roundness: float = 0.5) -> PackedVector2Array:
	return _rounded(rect, minf(rect.size.x, rect.size.y) * roundness)


static func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r),
	]
	var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for i in 7:
			var a := starts[k] + PI * 0.5 * float(i) / 6.0
			points.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return points
