class_name SushiBentoView
extends Node2D
## A bento box for the board view: three cells with a ghost of the sushi it wants, filled as
## plates arrive, and the close crescendo (lid drop with a squash, gold ribbon). Also used small
## for the queue preview.

const SIZE := Vector2(190, 126)

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


func set_cell(index: int, type: int) -> void:
	cells[index] = type
	queue_redraw()


func clear_cells() -> void:
	cells = PackedInt32Array([-1, -1, -1])
	queue_redraw()


## The centre of cell `index`, in this node's parent's space (for flying plates in).
func cell_point(index: int) -> Vector2:
	return transform * SushiArt.bento_cell(Rect2(-SIZE * 0.5, SIZE), index).get_center()


## Lid drops with a squash, then the ribbon ties; `speed` > 1 plays it faster.
func close(speed: float = 1.0) -> void:
	var motion := Juice.motion_scale
	var tween := create_tween()
	tween.tween_property(self, ^"lid", 1.0, 0.16 / speed).set_ease(Tween.EASE_IN)
	tween.tween_callback(SushiSfx.play.bind(&"lid"))
	if motion > 0.0:
		var rest := scale
		tween.tween_property(self, ^"scale", rest * Vector2(1.0 + 0.1 * motion, 1.0 - 0.1 * motion), 0.06 / speed)
		tween.tween_property(self, ^"scale", rest, 0.18 / speed).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_callback(SushiSfx.play.bind(&"chime"))
	tween.tween_property(self, ^"ribbon", 1.0, 0.14 / speed)
	await tween.finished


func _draw() -> void:
	SushiArt.draw_bento(self, Rect2(-SIZE * 0.5, SIZE), want, cells, lid, ribbon)
