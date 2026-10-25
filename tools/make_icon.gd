extends SceneTree
## Renders Sushi Loop's app icons into assets/icon/ from the game's own art: a porcelain plate
## with salmon nigiri inside a gold loop (adaptive foreground, kept inside the 264 px safe
## circle), the indigo seigaiha cloth of the noren (adaptive background), the two composed
## (launcher 192, project icon 256), a white monochrome mark and the 512 launch-splash icon.
## Needs a window (not --headless): godot --path . -s tools/make_icon.gd

const OUT: String = "res://assets/icon/%s.png"
const SIZE: int = 432
const INDIGO := Color("1F3F6B")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var fg := await _render(_draw_foreground, true)
	var bg := await _render(_draw_background, false)
	_save(fg, "icon_foreground_432")
	_save(bg, "icon_background_432")
	var both := bg.duplicate() as Image
	both.blend_rect(fg, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	# The legacy icon and the project icon: the composed square, the art a little larger.
	var cropped := both.get_region(Rect2i(54, 54, SIZE - 108, SIZE - 108))
	_save(_resized(cropped, 192), "icon_main_192")
	_save(_resized(cropped, 256), "icon")
	var mono := fg.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			mono.set_pixel(x, y, Color(1, 1, 1, mono.get_pixel(x, y).a))
	_save(mono, "icon_monochrome_432")
	var splash := Image.create_empty(512, 512, false, Image.FORMAT_RGBA8)
	splash.blit_rect(_resized(fg, 512), Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	_save(splash, "icon_splash_512")
	quit()


func _render(painter: Callable, transparent: bool) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var canvas := Painter.new()
	canvas.painter = painter
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.add_child(canvas)
	root.add_child(viewport)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	return image


func _draw_foreground(ci: CanvasItem) -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	# The loop: a gold ring with a gap and an arrow head, the belt going round.
	var ring := 114.0
	ci.draw_arc(c, ring, PI * 0.62, PI * 2.38, 64, Color("E8B04B"), 14.0, true)
	var tip := c + Vector2.from_angle(PI * 0.62) * ring
	var along := Vector2.from_angle(PI * 0.62 - PI * 0.5)
	var out := Vector2.from_angle(PI * 0.62)
	ci.draw_colored_polygon(PackedVector2Array([tip + along * 20.0, tip + out * 17.0 - along * 6.0, tip - out * 17.0 - along * 6.0]),
			Color("E8B04B"))
	# The plate: vermillion rim, porcelain well, gloss; salmon nigiri on it.
	var r := 92.0
	ci.draw_circle(c + Vector2(6, 10), r, Color(0, 0, 0, 0.22))
	ci.draw_circle(c, r, Color("B8461A"))
	ci.draw_circle(c, r * 0.76, Color("E6DCCB"))
	ci.draw_circle(c + Vector2(-0.02, -0.03) * r, r * 0.71, Color("FFFBF3"))
	ci.draw_arc(c, r * 0.9, PI * 1.08, PI * 1.42, 12, Color(1, 1, 1, 0.5), r * 0.07, true)
	var side := r * 1.55
	ci.draw_texture_rect(SushiArt.food(0), Rect2(c - Vector2(side, side) * 0.5 + Vector2(0, -4), Vector2(side, side)), false)


func _draw_background(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, SIZE, SIZE), INDIGO)
	var line := Color(INDIGO.lightened(0.18), 0.6)
	var r := 30.0
	var row := 0
	var y := r * 0.3
	while y < SIZE + r:
		var cx := -r + (r if row % 2 == 1 else 0.0)
		while cx < SIZE + r:
			for k in 3:
				ci.draw_arc(Vector2(cx, y), r * (1.0 - 0.3 * float(k)), PI, TAU, 16, line, 3.0, true)
			cx += r * 2.0
		y += r * 0.55
		row += 1


func _resized(image: Image, side: int) -> Image:
	var copy := image.duplicate() as Image
	copy.resize(side, side, Image.INTERPOLATE_LANCZOS)
	return copy


func _save(image: Image, file: String) -> void:
	var path := ProjectSettings.globalize_path(OUT % file)
	print("make_icon: %s %s" % [file, error_string(image.save_png(path))])


class Painter extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)
