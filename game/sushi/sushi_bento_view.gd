class_name SushiBentoView
extends Node2D
## A bento box for the board view: three cells with a ghost of the dish it wants, filled as
## plates arrive (each cell pops as its dish lands), and the close crescendo (lid drop with a
## squash, gold cord and bow). Also used small for the queue preview and as the flying copy that
## carries a packed bento up to the HUD. A rush order (M2) wears a round badge with the takes left,
## vermillion and pulsing from RUSH_ALARM down.

const SIZE := Vector2(190, 126)
const RUSH_ALARM: int = 2
const BADGE_RADIUS: float = 25.0

## Takes left for a rush order, -1 when it does not rush.
var rush: int = -1:
	set(value):
		rush = value
		queue_redraw()
## 0-1: the alarm pulse of a rush order about to run out.
var alarm: float = 0.0:
	set(value):
		alarm = value
		queue_redraw()

var want: int = -1:
	set(value):
		want = value
		queue_redraw()
var cells := PackedInt32Array([-1, -1, -1])
var lid: float = 0.0:
	set(value):
		lid = value
		queue_redraw()
var ribbon: float = 0.0:
	set(value):
		ribbon = value
		queue_redraw()

var _pops := PackedFloat32Array([0.0, 0.0, 0.0])


func set_cell(index: int, type: int) -> void:
	cells[index] = type
	queue_redraw()


func clear_cells() -> void:
	cells = PackedInt32Array([-1, -1, -1])
	queue_redraw()


## The centre of cell `index`, in this node's parent's space (for flying plates in).
func cell_point(index: int) -> Vector2:
	return transform * SushiArt.bento_cell(Rect2(-SIZE * 0.5, SIZE), index).get_center()


## The dish in cell `index` swells and settles (it just landed).
func pop_cell(index: int) -> void:
	if Juice.motion_scale <= 0.0:
		return
	var tween := create_tween()
	tween.tween_method(_set_pop.bind(index), 1.0, 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Lid drops with a squash, then the cord ties; `speed` > 1 plays it faster. `chime_step` climbs
## the chime when several bentos close from one take.
func close(speed: float = 1.0, chime_step: int = 0) -> void:
	var motion := Juice.motion_scale
	var tween := create_tween()
	tween.tween_property(self, ^"lid", 1.0, 0.16 / speed).set_ease(Tween.EASE_IN)
	tween.tween_callback(SushiSfx.play.bind(&"lid"))
	if motion > 0.0:
		var rest := scale
		tween.tween_property(self, ^"scale", rest * Vector2(1.0 + 0.12 * motion, 1.0 - 0.12 * motion), 0.06 / speed)
		tween.tween_property(self, ^"scale", rest, 0.2 / speed).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_callback(SushiSfx.play.bind(&"chime", chime_step))
	tween.tween_property(self, ^"ribbon", 1.0, 0.16 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _set_pop(value: float, index: int) -> void:
	_pops[index] = value
	queue_redraw()


func _draw() -> void:
	SushiArt.draw_bento(self, Rect2(-SIZE * 0.5, SIZE), want, cells, lid, ribbon, _pops)
	if rush >= 0 and lid <= 0.0:
		_draw_rush_badge()


## A round badge on the top-right corner: the takes left, over a ring that empties as they go.
func _draw_rush_badge() -> void:
	var c := Vector2(SIZE.x * 0.5 - 8.0, -SIZE.y * 0.5 + 6.0)
	var urgent := rush <= RUSH_ALARM
	var fill := SushiPalette.VERMILLION if urgent else SushiPalette.INK
	if urgent and alarm > 0.0:
		draw_circle(c, BADGE_RADIUS + 10.0 * alarm, Color(SushiPalette.VERMILLION, 0.35 * (1.0 - alarm)))
	draw_circle(c, BADGE_RADIUS, fill)
	draw_arc(c, BADGE_RADIUS - 3.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(rush) / 10.0, 0.05, 1.0), 32,
			SushiPalette.GOLD, 3.0, true)
	var font := ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else null
	if font == null:
		font = ThemeDB.fallback_font
	var size := 28
	var text := str(rush)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := c.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	draw_string(font, Vector2(c.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SushiPalette.CREAM)
