class_name SushiLogo
extends Control
## The main menu's emblem: plates gliding along a short stretch of belt (steel rails, crescent
## slats), drawn with SushiArt so it always matches the game. Still when Reduce Motion is on.

const TYPES: Array[int] = [0, 1, 2, 3, 4, 5, 6]
## Plates per second.
const SPEED: float = 0.35

var shop: Dictionary = SushiPalette.shop(1):
	set(value):
		shop = value
		queue_redraw()

var _travel: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	if Juice.motion_scale <= 0.0 or not is_visible_in_tree():
		return
	_travel += delta * SPEED * Juice.motion_scale
	queue_redraw()


func _draw() -> void:
	var r := minf(size.y * 0.36, size.x / 8.0)
	var y := size.y * 0.5
	var band := Rect2(Vector2(0.0, y - r * 1.3), Vector2(size.x, r * 2.6))
	SushiArt.draw_panel(self, band.grow(4.0), band.size.y * 0.5 + 4.0, shop.rail, shop.rail.darkened(0.25))
	SushiArt.draw_panel(self, band.grow(-6.0), band.size.y * 0.5 - 6.0, shop.belt, shop.belt)
	var spacing := r * 2.5
	var slat := spacing * 0.5
	var shift := fposmod(_travel * spacing, slat)
	var x := band.position.x + band.size.y * 0.5 + shift
	while x < band.end.x - band.size.y * 0.5:
		var points := PackedVector2Array()
		for k in 7:
			var u := lerpf(-1.0, 1.0, float(k) / 6.0)
			points.append(Vector2(x + (1.0 - u * u) * r * 0.3, y + u * (band.size.y * 0.5 - 10.0)))
		draw_polyline(points, Color(0, 0, 0, 0.28), 3.0, true)
		x += slat
	# Plates ride left to right, each keeping its dish, fading in and out at the band's ends.
	var whole := floorf(_travel)
	var frac := _travel - whole
	var shown := int(ceil(band.size.x / spacing)) + 1
	for i in range(-1, shown):
		var px := band.position.x + (float(i) + frac) * spacing
		var edge := minf(px - band.position.x, band.end.x - px) / (r * 1.6)
		if edge <= 0.0:
			continue
		var type := TYPES[posmod(i - int(whole), TYPES.size())]
		SushiArt.draw_plate(self, Vector2(px, y), r, type, clampf(edge, 0.0, 1.0))
