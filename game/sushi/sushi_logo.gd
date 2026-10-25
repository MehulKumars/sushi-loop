class_name SushiLogo
extends Control
## The main menu's emblem: three plates (maki, nigiri, onigiri) riding a short stretch of belt,
## drawn with SushiArt so it always matches the game's plates.

const TYPES: Array[int] = [0, 1, 2]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.y * 0.36, size.x / 7.0)
	var y := size.y * 0.5
	var band := Rect2(Vector2(0.0, y - r * 1.18), Vector2(size.x, r * 2.36))
	SushiArt.draw_panel(self, band, band.size.y * 0.5, SushiPalette.INK, SushiPalette.INK)
	for i in TYPES.size():
		var x := size.x * 0.5 + (float(i) - 1.0) * r * 2.5
		SushiArt.draw_plate(self, Vector2(x, y), r, TYPES[i])
