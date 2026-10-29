extends RefCounted
## Sizes the desktop window for tool runs (snapshots, playtests): the game lays out and renders at
## the full phone canvas, while the window itself stays small, centred and on screen.
## Viewport stretch renders at canvas size, so root.get_texture() still captures every pixel.

## The window takes at most this share of the screen's usable width and height.
const MAX_SCREEN_SHARE: float = 0.6
## Never larger than half the canvas (a 720x1600 canvas shows in a 360x800 window).
const MAX_SCALE: float = 0.5


## Shows a `canvas`-sized phone screen (in canvas px) in a small window in the middle of the screen.
static func fit(root: Window, canvas: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var area := DisplayServer.screen_get_usable_rect(root.current_screen)
	var scale := minf(MAX_SCALE, minf(area.size.x * MAX_SCREEN_SHARE / canvas.x, area.size.y * MAX_SCREEN_SHARE / canvas.y))
	var size := Vector2i(roundi(canvas.x * scale), roundi(canvas.y * scale))
	root.size = size
	root.position = area.position + (area.size - size) / 2


## The canvas size the game lays out at right now.
static func canvas(root: Window) -> Vector2i:
	return Vector2i(root.get_visible_rect().size.round())
