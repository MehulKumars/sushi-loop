extends Modal
## A moment worth a card: a new dish on the menu (the dish on its own plate, so the rim is learned
## with it), a star gift opening, a chapter finished. A showcase over slowly turning rays, a
## title, a name, one line, an optional coin reward and one button. Open with UI.open(), call
## show_dish(type) or show_gift(title, name, text, texture, coins), then await `closed`.

const RAYS: int = 12

var _showcase: Showcase


func _ready() -> void:
	super._ready()
	_showcase = Showcase.new()
	_showcase.custom_minimum_size = Vector2(260, 240)
	_showcase.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	%Picture.add_child(_showcase)
	%Reward.hide()
	%OkButton.pressed.connect(close)


## The first time a dish rides the belt: the dish on its plate, its name and a line about it.
func show_dish(type: int) -> void:
	%Title.text = "New on the menu!"
	%Name.text = SushiPalette.type_name(type)
	%Text.text = SushiPalette.BLURBS[type] if type < SushiPalette.BLURBS.size() else ""
	%OkButton.text = "Let's go"
	_showcase.plate_type = type
	_showcase.picture = null
	_celebrate(&"reveal")


## A reward with a picture (gift, lantern) and `coins` added to the player's purse by the caller.
func show_gift(title: String, heading: String, text: String, picture: Texture2D, coins: int = 0) -> void:
	%Title.text = title
	%Name.text = heading
	%Text.text = text
	%Text.visible = not text.is_empty()
	%OkButton.text = "Collect" if coins > 0 else "Nice!"
	_showcase.plate_type = -1
	_showcase.picture = picture
	if coins > 0:
		%Reward.show()
		%Reward.value = 0
	_celebrate(&"unwrap")
	if coins > 0:
		await get_tree().create_timer(0.45, true, false, true).timeout
		if is_inside_tree():
			%Reward.set_value(coins, 0.8)
			SushiSfx.play(&"coin")


func _celebrate(cue: StringName) -> void:
	SushiSfx.play(cue)
	Haptics.big()
	_showcase.pivot_offset = _showcase.custom_minimum_size * 0.5
	Juice.pop(_showcase, 1.12, 0.35)


## The picture: gold rays turning slowly behind a dish on its plate, or behind a texture.
class Showcase extends Control:
	var plate_type: int = -1:
		set(value):
			plate_type = value
			queue_redraw()
	var picture: Texture2D:
		set(value):
			picture = value
			queue_redraw()
	var _turn: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _process(delta: float) -> void:
		if Juice.motion_scale > 0.0:
			_turn += delta * 0.25
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var reach := minf(size.x, size.y) * 0.62
		var gold := get_theme_color(&"gold", &"Tokens")
		for i in RAYS:
			var a := _turn + TAU * float(i) / float(RAYS)
			var w := TAU / float(RAYS) * 0.28
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - w) * reach,
					c + Vector2.from_angle(a + w) * reach]), Color(gold, 0.16))
		draw_circle(c, reach * 0.62, Color(gold, 0.14))
		var r := minf(size.x, size.y) * 0.34
		if plate_type >= 0:
			draw_circle(c + Vector2(4, 8), r, Color(0, 0, 0, 0.15))
			SushiArt.draw_plate(self, c, r, plate_type)
		elif picture != null:
			var side := r * 2.2
			draw_texture_rect(picture, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false)
