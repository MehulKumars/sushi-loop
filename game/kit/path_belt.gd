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
var band_color := Color("23283B"):
	set(value):
		band_color = value
		queue_redraw()
## The steel rails on both edges of the band.
var rail_color := Color("C7CED8"):
	set(value):
		rail_color = value
		queue_redraw()
var slat_color := Color(1, 1, 1, 0.09)
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
	var shadow := PackedVector2Array()
	var steps := 160
	var length := perimeter()
	for i in steps + 1:
		var p := _point(length * float(i) / float(steps))
		points.append(p)
		shadow.append(p + Vector2(0, 7))
	# A soft shadow under the belt, steel rails on both edges, then the band between them.
	draw_polyline(shadow, Color(0, 0, 0, 0.16), band_width + 8.0, true)
	draw_polyline(points, rail_color.darkened(0.25), band_width + 2.0, true)
	draw_polyline(points, rail_color, band_width - 2.0, true)
	draw_polyline(points, band_color, band_width - 16.0, true)
	draw_polyline(points, Color(band_color.lightened(0.12), 0.9), 2.0, true)
	# Crescent slats (the plates of a kaiten chain) move with the belt, so a step reads as motion
	# even on an empty stretch.
	var count := slots * 2
	var shift := fposmod(travel, 1.0) * 2.0
	var half := band_width * 0.5 - 9.0
	var dark := Color(0, 0, 0, 0.28)
	for i in count:
		var ring := (float(i) + shift) * 0.5
		var p := point_at(ring)
		var forward := direction_at(ring)
		var normal := forward.orthogonal()
		var crescent := PackedVector2Array()
		for k in 7:
			var u := lerpf(-1.0, 1.0, float(k) / 6.0)
			crescent.append(p + normal * u * half + forward * (1.0 - u * u) * band_width * 0.13)
		draw_polyline(crescent, dark, 3.0, true)
		for k in crescent.size():
			crescent[k] -= forward * 2.5
		draw_polyline(crescent, slat_color, 2.0, true)
	var frame := window_rect()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(window_color, 0.14 + 0.16 * window_glow)
	box.border_color = window_color
	box.set_border_width_all(int(5.0 + 3.0 * window_glow))
	box.set_corner_radius_all(int(frame.size.y * 0.3))
	box.shadow_color = Color(window_color, 0.25 + 0.35 * window_glow)
	box.shadow_size = int(6.0 + 10.0 * window_glow)
	box.anti_aliasing = true
	draw_style_box(box, frame)
	# A gold tick under each pick position, so the window reads as "tap here".
	for w in window:
		var c := point_at(float(w))
		var y := frame.end.y - 3.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) + Vector2(0, y - c.y), c + Vector2(9, 0) + Vector2(0, y - c.y),
				c + Vector2(0, -8) + Vector2(0, y - c.y)]), window_color.darkened(0.15))


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
