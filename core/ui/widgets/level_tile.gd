@tool
class_name LevelTile
extends Button
## One level in the Levels screen's grid: its number and best stars, or a lock.
## The next level to play uses the accent colour so the eye finds it at once.

@export var level: int = 1:
	set(value):
		level = value
		_refresh()
@export_range(0, 3) var stars: int = 0:
	set(value):
		stars = value
		_refresh()
@export var locked: bool = false:
	set(value):
		locked = value
		_refresh()
## The level the Play button would start.
@export var current: bool = false:
	set(value):
		current = value
		_refresh()

var _stars := StarRating.new()


func _init() -> void:
	# Added at creation so the stars are freed with the tile even if it never enters the tree.
	_stars.star_size = 28.0
	_stars.add_theme_constant_override(&"separation", 2)
	add_child(_stars)


func _ready() -> void:
	custom_minimum_size.y = 156
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stars.anchor_left = 0.0
	_stars.anchor_right = 1.0
	_stars.offset_left = 0.0
	_stars.offset_right = 0.0
	_stars.offset_top = -50.0
	_stars.offset_bottom = -18.0
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	theme_type_variation = &"AccentTileButton" if current and not locked else &"TileButton"
	disabled = locked
	text = "" if locked else str(level)
	icon = Icons.LOCK if locked else null
	_stars.visible = not locked and not current
	_stars.stars = stars
	tooltip_text = "Level %d, locked" % level if locked else "Level %d, %d stars" % [level, stars]
