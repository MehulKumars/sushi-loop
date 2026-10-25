class_name SushiPlateView
extends Node2D
## One plate for the board view: on the belt, on the counter or in flight. Draws itself with
## SushiArt; `glow` is the gold hint/guide ring, `warn` the vermillion ring of an overflowed plate.

var plate: int = -1
var type: int = 0:
	set(value):
		type = value
		queue_redraw()
var radius: float = 42.0:
	set(value):
		radius = value
		queue_redraw()
var glow: float = 0.0:
	set(value):
		glow = value
		queue_redraw()
var warn: float = 0.0:
	set(value):
		warn = value
		queue_redraw()
## A soft shadow under the plate (on the wooden counter; the belt is too dark to need one).
var shadow: bool = false:
	set(value):
		shadow = value
		queue_redraw()


func _draw() -> void:
	if glow > 0.0:
		draw_circle(Vector2.ZERO, radius * (1.14 + 0.08 * glow), Color(SushiPalette.GOLD, 0.45 * glow))
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 48, Color(SushiPalette.GOLD, glow), 5.0, true)
	if shadow:
		draw_circle(Vector2(0, radius * 0.1), radius * 1.02, Color(SushiPalette.INK, 0.18))
	SushiArt.draw_plate(self, Vector2.ZERO, radius, type)
	if warn > 0.0:
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 48, Color(SushiPalette.VERMILLION, warn), 6.0, true)
