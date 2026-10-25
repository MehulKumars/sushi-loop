class_name SushiPlateView
extends Node2D
## One plate for the board view: on the belt, on the counter or in flight. Draws itself with
## SushiArt; `glow` is the gold hint/guide ring, `warn` the vermillion ring of an overflowed plate,
## `lift` (0-1) drops its shadow away while it is in the air.

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
## 0-1: a tap ripple spreading out from the plate (the tutorial's "take this one").
var ripple: float = 0.0:
	set(value):
		ripple = value
		queue_redraw()
## A soft shadow under the plate (on the wooden counter; the belt is too dark to need one).
var shadow: bool = false:
	set(value):
		shadow = value
		queue_redraw()
## 0 resting, 1 in the air: the shadow falls further and fades.
var lift: float = 0.0:
	set(value):
		lift = value
		queue_redraw()


func _draw() -> void:
	if glow > 0.0:
		draw_circle(Vector2.ZERO, radius * (1.16 + 0.08 * glow), Color(SushiPalette.GOLD, 0.4 * glow))
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 48, Color(SushiPalette.GOLD, glow), 5.0, true)
	if shadow or lift > 0.0:
		var drop := radius * (0.1 + 0.35 * lift)
		draw_circle(Vector2(drop * 0.3, drop), radius * (1.0 - 0.08 * lift), Color(SushiPalette.INK, 0.2 * (1.0 - 0.4 * lift)))
	SushiArt.draw_plate(self, Vector2.ZERO, radius, type)
	if warn > 0.0:
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 48, Color(SushiPalette.VERMILLION, warn), 6.0, true)
	if ripple > 0.0:
		draw_arc(Vector2.ZERO, radius * (1.1 + 0.7 * ripple), 0.0, TAU, 48, Color(SushiPalette.GOLD, 1.0 - ripple), 5.0, true)
