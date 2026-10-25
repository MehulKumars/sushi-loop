class_name PathBelt
extends Node2D
## A closed conveyor belt (a rounded rectangle, running left to right along the bottom) that
## carries `slots` items. `travel` (in slots, tweened) moves every item along it; ring position
## 0 .. window-1 is the pick window. The window always gets its own fixed spacing on the bottom
## straight (so its items are evenly spaced and tap-sized on any belt length); the other slots
## share the rest of the loop, so items speed up a little on the far side.
## Items are separate nodes placed with point_at(); this node draws the band, slats and window.

## The belt's centre line.
var rect := Rect2(0, 0, 600, 600):
	set(value):
		rect = value
		queue_redraw()
var corner_radius: float = 110.0
var slots: int = 12
var window: int = 3
var band_width: float = 104.0
## Distance between window slots (shrunk if the bottom straight is too short for it).
var window_spacing: float = 112.0
var band_color := Color("23283B")
var slat_color := Color(1, 1, 1, 0.07)
var window_color := Color("E8B04B")
## How far the belt has moved, in slots.
var travel: float = 0.0:
	set(value):
		travel = value
		queue_redraw()
## 0-1: lights the window frame (the first-move guide pulses it).
var window_glow: float = 0.0:
	set(value):
		window_glow = value
		queue_redraw()


func perimeter() -> float:
	var r := _radius()
	return 2.0 * (rect.size.x - 2.0 * r) + 2.0 * (rect.size.y - 2.0 * r) + TAU * r


## Distance between neighbouring slots in the window (the tap-size spacing).
func spacing() -> float:
	var straight := rect.size.x - 2.0 * _radius()
	return minf(window_spacing, straight / float(maxi(window, 1)))


## Where ring position `ring` (in slots, fractions allowed) is.
func point_at(ring: float) -> Vector2:
	return _point(_arc(ring))


## Unit direction of travel at ring position `ring`.
func direction_at(ring: float) -> Vector2:
	var s := _arc(ring)
	return (_point(s + 1.0) - _point(s - 1.0)).normalized()


## The window frame (around ring positions 0 .. window-1), on the bottom straight.
func window_rect() -> Rect2:
	var half_width := spacing() * float(window) * 0.5
	var half := band_width * 0.5 + 6.0
	return Rect2(Vector2(rect.get_center().x - half_width, rect.end.y - half), Vector2(half_width * 2.0, half * 2.0))


## Arc length from the bottom centre for ring position `ring`: the window's slots at spacing(),
## the rest spread evenly over what is left of the loop.
func _arc(ring: float) -> float:
	var n := float(maxi(slots, 1))
	var d := fposmod(ring - float(window - 1) * 0.5 + n * 0.5, n) - n * 0.5
	var inner := spacing()
	var half := float(window) * 0.5
	if absf(d) <= half or slots <= window:
		return d * inner
	var outer := (perimeter() - float(window) * inner) / (n - float(window))
	return signf(d) * (half * inner + (absf(d) - half) * outer)


func _draw() -> void:
	var points := PackedVector2Array()
	var steps := 160
	var length := perimeter()
	for i in steps + 1:
		points.append(_point(length * float(i) / float(steps)))
	draw_polyline(points, band_color, band_width, true)
	draw_polyline(points, Color(band_color.lightened(0.18), 0.9), 3.0, true)
	# Slats move with the belt so a step reads as motion even on an empty stretch.
	var count := slots * 2
	var shift := fposmod(travel, 1.0) * 2.0
	for i in count:
		var ring := (float(i) + shift) * 0.5
		var p := point_at(ring)
		var normal := direction_at(ring).orthogonal()
		draw_line(p - normal * band_width * 0.42, p + normal * band_width * 0.42, slat_color, 3.0)
	var frame := window_rect()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(window_color, 0.12 + 0.18 * window_glow)
	box.border_color = window_color
	box.set_border_width_all(int(5.0 + 3.0 * window_glow))
	box.set_corner_radius_all(int(frame.size.y * 0.3))
	draw_style_box(box, frame)


func _radius() -> float:
	return minf(corner_radius, minf(rect.size.x, rect.size.y) * 0.5)


## The point at arc length `s`, starting at the bottom centre and running right (to the bottom
## right corner, up the right side, left along the top, down the left side, back along the bottom).
func _point(s: float) -> Vector2:
	var r := _radius()
	var a := rect.size.x - 2.0 * r
	var b := rect.size.y - 2.0 * r
	var q := PI * 0.5 * r
	var t := fposmod(s, perimeter())
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	var mid := rect.get_center().x
	if t < a * 0.5:
		return Vector2(mid + t, bottom)
	t -= a * 0.5
	if t < q:
		return Vector2(right - r, bottom - r) + Vector2.from_angle(PI * 0.5 - t / r) * r
	t -= q
	if t < b:
		return Vector2(right, bottom - r - t)
	t -= b
	if t < q:
		return Vector2(right - r, top + r) + Vector2.from_angle(-t / r) * r
	t -= q
	if t < a:
		return Vector2(right - r - t, top)
	t -= a
	if t < q:
		return Vector2(left + r, top + r) + Vector2.from_angle(-PI * 0.5 - t / r) * r
	t -= q
	if t < b:
		return Vector2(left, top + r + t)
	t -= b
	if t < q:
		return Vector2(left + r, bottom - r) + Vector2.from_angle(PI - t / r) * r
	t -= q
	return Vector2(left + r + t, bottom)
