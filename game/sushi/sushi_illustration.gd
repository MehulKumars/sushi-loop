class_name SushiIllustration
extends Control
## A small picture for one "How to play" section, drawn with the game's own art (SushiArt): the
## gold window with plates, a bento being packed, the counter, a covered plate, a rush order, the
## chef's special, a plate riding round. Used by ui/screens/how_to_play.gd.

const SIZE := Vector2(220, 150)

## window, bento, counter, loop, covered, rush, special, stars
var kind: StringName = &"window":
	set(value):
		kind = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := 30.0
	match kind:
		&"window":
			draw_rect(Rect2(c - Vector2(105, 40), Vector2(210, 80)), Color(SushiPalette.INK, 0.9))
			draw_rect(Rect2(c - Vector2(104, 38), Vector2(208, 76)), SushiPalette.GOLD, false, 4.0)
			for i in 3:
				SushiArt.draw_plate(self, c + Vector2(-66 + 66 * i, 0), r, [0, 2, 0][i])
		&"bento":
			var cells := PackedInt32Array([1, 1, -1])
			SushiArt.draw_bento(self, Rect2(c - Vector2(78, 52), Vector2(156, 104)), 1, cells)
		&"counter":
			SushiArt.draw_counter_wood(self, Rect2(c - Vector2(105, 34), Vector2(210, 68)), 16.0,
					Color("E9D9BD"), Color("CDB28A"))
			for i in 3:
				SushiArt.draw_plate(self, c + Vector2(-66 + 66 * i, 0), 26.0, [3, 5, 3][i])
		&"loop":
			draw_arc(c, 58.0, 0.0, TAU, 48, Color(SushiPalette.INK, 0.85), 22.0, true)
			draw_arc(c, 58.0, -0.6, 0.6, 12, SushiPalette.GOLD, 5.0, true)
			SushiArt.draw_plate(self, c + Vector2(58, 0).rotated(-PI * 0.75), 22.0, 4)
			SushiArt.draw_plate(self, c + Vector2(58, 0), 22.0, 6)
		&"covered":
			SushiArt.draw_blank_plate(self, c + Vector2(-48, 4), r)
			SushiArt.draw_cloche(self, c + Vector2(-48, 4), r)
			SushiArt.draw_plate(self, c + Vector2(48, 4), r, 1)
			SushiArt.draw_cloche(self, c + Vector2(48, 4), r, 0.6)
		&"rush":
			var cells := PackedInt32Array([5, -1, -1])
			SushiArt.draw_bento(self, Rect2(c - Vector2(78, 46), Vector2(156, 100)), 5, cells)
			var badge := c + Vector2(72, -46)
			draw_circle(badge, 24.0, SushiPalette.VERMILLION)
			draw_arc(badge, 21.0, -PI * 0.5, PI * 0.1, 16, SushiPalette.GOLD, 3.0, true)
			_text(badge, "2", 28, SushiPalette.CREAM)
		&"special":
			SushiArt.draw_plate(self, c + Vector2(-50, 0), r + 4.0, SushiLevel.WILD)
			var cells := PackedInt32Array([2, 2, SushiLevel.WILD])
			SushiArt.draw_bento(self, Rect2(c + Vector2(-6, -36), Vector2(108, 72)), 2, cells)
		&"stars":
			for i in 3:
				var side := 54.0 if i == 1 else 44.0
				draw_texture_rect(Icons.STAR, Rect2(c + Vector2(-62 + 62 * i, -4) - Vector2(side, side) * 0.5,
						Vector2(side, side)), false, SushiPalette.GOLD)


func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := at.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(at.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
