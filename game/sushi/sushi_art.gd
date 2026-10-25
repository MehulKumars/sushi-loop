class_name SushiArt
extends RefCounted
## Sushi Loop art: porcelain plates with a coloured, patterned rim (drawn here) carrying the dish
## (Fluent Emoji 3D renders, MIT licence, assets/food/), lacquered bento boxes, the wooden counter
## and the serving board. Called from _draw() of the plate, bento and board views, which redraw
## only when their state changes: a plate costs one texture quad and a few circles.

const FOOD: Array[Texture2D] = [
	preload("res://assets/food/nigiri.png"),
	preload("res://assets/food/onigiri.png"),
	preload("res://assets/food/dango.png"),
	preload("res://assets/food/ebi_fry.png"),
	preload("res://assets/food/naruto.png"),
	preload("res://assets/food/purin.png"),
	preload("res://assets/food/ika.png"),
]
## How big each dish sits on its plate (the renders fill their squares differently).
const FOOD_SCALE: Array[float] = [1.0, 0.94, 1.1, 1.02, 0.9, 1.0, 1.0]
const OUTLINE: float = 2.5


static func food(type: int) -> Texture2D:
	return FOOD[posmod(type, FOOD.size())]


## A plate of `type` centred at `c`, rim radius `r`. `alpha` fades it.
static func draw_plate(ci: CanvasItem, c: Vector2, r: float, type: int, alpha: float = 1.0) -> void:
	var rim := SushiPalette.rim_color(type)
	rim.a *= alpha
	var porcelain := Color(SushiPalette.PORCELAIN, alpha)
	var shade := Color(SushiPalette.PORCELAIN_SHADE, alpha)
	var well := 0.74
	match SushiPalette.rim_style(type):
		SushiPalette.Rim.SOLID:
			ci.draw_circle(c, r, rim)
			well = 0.76
		SushiPalette.Rim.DASHED:
			ci.draw_circle(c, r, porcelain)
			var dashes := 12
			for i in dashes:
				var a := TAU * float(i) / float(dashes)
				ci.draw_arc(c, r * 0.88, a, a + TAU / float(dashes) * 0.55, 6, rim, r * 0.2, true)
			well = 0.7
		SushiPalette.Rim.DOUBLE:
			ci.draw_circle(c, r, rim)
			ci.draw_circle(c, r * 0.88, porcelain)
			ci.draw_arc(c, r * 0.78, 0.0, TAU, 40, rim, r * 0.07, true)
			well = 0.7
	# The well of the plate: a shaded step, then the lit floor (light from the top left).
	ci.draw_circle(c, r * well, shade)
	ci.draw_circle(c + Vector2(-0.02, -0.03) * r, r * (well - 0.05), porcelain)
	# Gloss on the rim and a soft edge line.
	ci.draw_arc(c, r * 0.92, PI * 1.08, PI * 1.42, 10, Color(1, 1, 1, 0.5 * alpha), r * 0.07, true)
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(SushiPalette.INK, 0.35 * alpha), 1.5, true)
	draw_food(ci, c + Vector2(0.0, -r * 0.03), r * 1.5, type, alpha)


## The dish of `type` in a square of side `s` centred at `c`.
static func draw_food(ci: CanvasItem, c: Vector2, s: float, type: int, alpha: float = 1.0) -> void:
	var side := s * FOOD_SCALE[posmod(type, FOOD_SCALE.size())]
	ci.draw_texture_rect(food(type), Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false,
			Color(1, 1, 1, alpha))


## A bento box in `rect` with three cells; `cells` holds the dish in each (-1 empty) and `want`
## the dish it takes (a faint ghost in the empty cells). `lid` (0-1) drops the lid on, `ribbon`
## (0-1) ties the gold cord, `pops` (0-1 per cell) swells a dish that just landed.
static func draw_bento(ci: CanvasItem, rect: Rect2, want: int, cells: PackedInt32Array, lid: float = 0.0,
		ribbon: float = 0.0, pops: PackedFloat32Array = PackedFloat32Array()) -> void:
	var radius := rect.size.y * 0.16
	_filled(ci, _rounded(Rect2(rect.position + Vector2(0, rect.size.y * 0.06), rect.size), radius),
			Color(SushiPalette.INK, 0.22), Color(SushiPalette.INK, 0.0))
	_filled(ci, _rounded(rect, radius), SushiPalette.LACQUER, SushiPalette.INK)
	var inner := rect.grow(-rect.size.y * 0.08)
	_filled(ci, _rounded(inner, radius * 0.6), SushiPalette.LACQUER_RED, SushiPalette.LACQUER_RED)
	_gloss(ci, rect, radius, 1.0)
	for i in 3:
		var cell := bento_cell(rect, i)
		_filled(ci, _rounded(cell, radius * 0.4), Color("F3EADB"), Color("F3EADB"))
		ci.draw_line(cell.position + Vector2(radius * 0.4, 2.0), Vector2(cell.end.x - radius * 0.4, cell.position.y + 2.0),
				Color(SushiPalette.INK, 0.12), 3.0)
		var side := minf(cell.size.x, cell.size.y) * 1.08
		var type := cells[i] if i < cells.size() else -1
		if type >= 0:
			var pop := pops[i] if i < pops.size() else 0.0
			draw_food(ci, cell.get_center(), side * (1.0 + 0.3 * pop), type)
		elif want >= 0:
			draw_food(ci, cell.get_center(), side * 0.9, want, 0.28)
	if lid > 0.0:
		# The lid drops from just above, fading in over the first part of the drop only.
		var lid_rect := Rect2(rect.position + Vector2(0, -rect.size.y * (1.0 - lid) * 0.5), rect.size)
		var shown := clampf(lid * 3.0, 0.0, 1.0)
		_filled(ci, _rounded(lid_rect, radius), Color(SushiPalette.LACQUER, shown), Color(SushiPalette.INK, shown))
		_filled(ci, _rounded(lid_rect.grow(-rect.size.y * 0.1), radius * 0.6), Color(SushiPalette.LACQUER_RED, shown * 0.9),
				Color(SushiPalette.LACQUER_RED, 0.0))
		_gloss(ci, lid_rect, radius, shown)
		ci.draw_arc(lid_rect.get_center(), lid_rect.size.y * 0.18, 0.0, TAU, 32, Color(SushiPalette.GOLD, shown), 3.0, true)
		if ribbon > 0.0:
			var gold := Color(SushiPalette.GOLD, ribbon)
			var w := lid_rect.size.y * 0.14 * ribbon
			ci.draw_rect(Rect2(Vector2(lid_rect.get_center().x - w * 0.5, lid_rect.position.y), Vector2(w, lid_rect.size.y)), gold)
			ci.draw_rect(Rect2(Vector2(lid_rect.position.x, lid_rect.get_center().y - w * 0.5), Vector2(lid_rect.size.x, w)), gold)
			# A bow: two loops and the knot.
			var knot := lid_rect.get_center()
			var loop := lid_rect.size.y * 0.16 * ribbon
			ci.draw_circle(knot + Vector2(-loop, -loop * 0.4), loop * 0.75, gold)
			ci.draw_circle(knot + Vector2(loop, -loop * 0.4), loop * 0.75, gold)
			ci.draw_circle(knot, w * 0.8, Color(SushiPalette.GOLD.darkened(0.2), ribbon))


## The wooden sushi counter in `rect`: planks of slightly different tone, a little grain, and a
## soft shadow along the edge where the belt sits above it.
static func draw_counter_wood(ci: CanvasItem, rect: Rect2, radius: float, wood: Color, grain: Color) -> void:
	_filled(ci, _rounded(rect, radius), wood, grain)
	var plank := 58.0
	var rows := maxi(1, int(rect.size.y / plank))
	plank = rect.size.y / float(rows)
	for row in rows:
		var y0 := rect.position.y + float(row) * plank
		var y1 := y0 + plank
		var tone := 0.05 * sin(float(row) * 2.3)
		var fill := wood.lightened(tone) if tone > 0.0 else wood.darkened(-tone)
		var points := PackedVector2Array()
		for k in 7:
			var y := lerpf(y0 + 1.0, y1 - 1.0, float(k) / 6.0)
			points.append(Vector2(rect.position.x + _inset(rect, radius, y) + 2.0, y))
		for k in range(6, -1, -1):
			var y := lerpf(y0 + 1.0, y1 - 1.0, float(k) / 6.0)
			points.append(Vector2(rect.end.x - _inset(rect, radius, y) - 2.0, y))
		ci.draw_colored_polygon(points, fill)
		if row > 0:
			var x0 := rect.position.x + _inset(rect, radius, y0) + 2.0
			var x1 := rect.end.x - _inset(rect, radius, y0) - 2.0
			ci.draw_line(Vector2(x0, y0), Vector2(x1, y0), Color(grain, 0.7), 2.0)
			ci.draw_line(Vector2(x0, y0 + 2.0), Vector2(x1, y0 + 2.0), Color(1, 1, 1, 0.25), 1.0)
		# Two long grain strokes per plank.
		for g in 2:
			var gy := lerpf(y0, y1, 0.3 + 0.4 * float(g)) + 3.0 * sin(float(row * 3 + g))
			var gx0 := rect.position.x + _inset(rect, radius, gy) + 30.0 + 40.0 * absf(sin(float(row + g * 5)))
			var gx1 := rect.end.x - _inset(rect, radius, gy) - 30.0 - 50.0 * absf(cos(float(row * 2 + g)))
			if gx1 > gx0 + 40.0:
				ci.draw_line(Vector2(gx0, gy), Vector2(gx1, gy + 2.0 * sin(float(row))), Color(grain, 0.28), 1.5, true)
	var edge := _rounded(rect.grow(-5.0), maxf(radius - 5.0, 2.0))
	edge.append(edge[0])
	ci.draw_polyline(edge, Color(SushiPalette.INK, 0.12), 10.0, true)


## The serving board the counter plates wait on: pale wood, a darker front edge and one round
## setting per slot. `alert` (0-1) warms the settings towards vermillion.
static func draw_serving_board(ci: CanvasItem, rect: Rect2, slots: Array[Vector2], slot_radius: float, alert: float,
		full: bool, wood: Color, grain: Color) -> void:
	var radius := rect.size.y * 0.28
	var depth := rect.size.y * 0.1
	_filled(ci, _rounded(Rect2(rect.position + Vector2(0, depth + 4.0), rect.size), radius), Color(SushiPalette.INK, 0.2),
			Color(SushiPalette.INK, 0.0))
	_filled(ci, _rounded(Rect2(rect.position + Vector2(0, depth), rect.size), radius), grain.darkened(0.15), grain.darkened(0.3))
	_filled(ci, _rounded(rect, radius), wood.lightened(0.35), grain)
	_gloss(ci, rect, radius, 0.6)
	var ring := SushiPalette.VERMILLION if full else grain.darkened(0.1).lerp(SushiPalette.VERMILLION, alert)
	for p in slots:
		ci.draw_circle(p, slot_radius * 1.06, Color(grain, 0.35))
		ci.draw_arc(p, slot_radius * 1.06, PI * 0.15, PI * 0.85, 12, Color(1, 1, 1, 0.5), 2.0, true)
		ci.draw_arc(p, slot_radius * 1.1, 0.0, TAU, 36, ring, 2.5 + 2.5 * alert, true)


## A filled rounded rectangle with an outline (the logo band, plain panels).
static func draw_panel(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, line: Color) -> void:
	_filled(ci, _rounded(rect, radius), fill, line)


## Cell `i` (0-2) of a bento box drawn in `rect`.
static func bento_cell(rect: Rect2, i: int) -> Rect2:
	var inner := rect.grow(-rect.size.y * 0.08)
	var gap := inner.size.y * 0.06
	var cell_w := (inner.size.x - gap * 4.0) / 3.0
	return Rect2(inner.position + Vector2(gap + float(i) * (cell_w + gap), gap), Vector2(cell_w, inner.size.y - gap * 2.0))


## A highlight along the top edge of a lacquered or polished shape.
static func _gloss(ci: CanvasItem, rect: Rect2, radius: float, alpha: float) -> void:
	var y := rect.position.y + rect.size.y * 0.045
	ci.draw_line(Vector2(rect.position.x + radius, y), Vector2(rect.end.x - radius, y), Color(1, 1, 1, 0.22 * alpha), 2.5, true)


## How far the rounded rectangle's edge is from its side at height `y`.
static func _inset(rect: Rect2, radius: float, y: float) -> float:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var dy := 0.0
	if y < rect.position.y + r:
		dy = rect.position.y + r - y
	elif y > rect.end.y - r:
		dy = y - (rect.end.y - r)
	else:
		return 0.0
	return r - sqrt(maxf(0.0, r * r - dy * dy))


static func _filled(ci: CanvasItem, points: PackedVector2Array, fill: Color, line: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, fill)
	if line.a <= 0.0:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, line, OUTLINE, true)


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
			var p := corners[k] + Vector2(cos(a), sin(a)) * r
			# A capsule's corners meet: skip the repeated point (triangulation fails on duplicates).
			if points.is_empty() or p.distance_squared_to(points[points.size() - 1]) > 0.01:
				points.append(p)
	if points.size() > 1 and points[0].distance_squared_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points
