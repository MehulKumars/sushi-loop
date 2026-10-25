class_name SushiBoardView
extends Control
## The Sushi Loop board (docs/SUSHI_LOOP.md): the belt loop with its gold pick window, the open
## bentos and the queue preview inside the loop, and the counter just above the window. Plays a
## SushiRun: a tap in the window takes a plate and the model's events play back as short
## animations (a tap made meanwhile is kept and played next, faster). The doom detector searches
## in slices between takes. The game screen calls play(), undo(), rewind(), continue_game(), hint().

signal changed
signal took
signal bento_closed
signal won
signal lost
signal doomed
## The counter has one free slot left (0 = full).
signal counter_low(room: int)

const BAND: float = 100.0
const CORNER: float = 118.0
const MAX_LOOP := Vector2(690.0, 1120.0)
const PLATE_RADIUS: float = 41.0
const WINDOW_SCALE: float = 1.2
const COUNTER_RADIUS: float = 31.0
const PREVIEW_SCALE: float = 0.4
const PLANK_HEIGHT: float = 84.0
const STEP_TIME: float = 0.14
const FLY_TIME: float = 0.2
const HOP_GAP: float = 0.08
## A tap counts within this many plate radii of a window position.
const TAP_SLACK: float = 1.3
## Animation speed while a tap is waiting.
const HURRY: float = 2.2

var run: SushiRun
## Pulse the plate to take until the first take (the tutorial levels).
var guide: bool = false

var _belt := PathBelt.new()
var _bento_layer := Node2D.new()
var _plate_layer := Node2D.new()
var _grains := CPUParticles2D.new()
var _plates: Dictionary[int, SushiPlateView] = {}
var _flying: Dictionary[int, bool] = {}
var _bentos: Array[SushiBentoView] = []
var _previews: Array[SushiBentoView] = []
var _doom := SushiDoom.new()
var _shown_offset: float = 0.0
var _busy: bool = false
var _pending: int = -1
var _speed: float = 1.0
var _took_any: bool = false
var _active_flights: int = 0
var _interior := Rect2()
var _counter_rect := Rect2()
var _bento_points: Array[Vector2] = []
var _preview_points: Array[Vector2] = []
var _bento_scale: float = 1.0
var _counter_glow: float = 0.0
var _counter_tween: Tween
var _belt_tween: Tween
var _hint_tween: Tween
var _hint_plate: int = -1
var _guide_tween: Tween
var _ripple_tween: Tween

signal _landed


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_belt.band_color = SushiPalette.INK
	_belt.window_color = SushiPalette.GOLD
	add_child(_belt)
	add_child(_bento_layer)
	add_child(_plate_layer)
	_grains.emitting = false
	_grains.one_shot = true
	_grains.amount = 20
	_grains.lifetime = 0.7
	_grains.explosiveness = 0.95
	_grains.direction = Vector2.UP
	_grains.spread = 75.0
	_grains.initial_velocity_min = 150.0
	_grains.initial_velocity_max = 280.0
	_grains.gravity = Vector2(0, 700)
	_grains.scale_amount_min = 3.0
	_grains.scale_amount_max = 5.0
	_grains.color = SushiPalette.RICE
	_plate_layer.add_child(_grains)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Starts `level` from the beginning.
func play(level: SushiLevel) -> void:
	run = SushiRun.new(level)
	run.record = true
	_took_any = false
	_pending = -1
	_rebuild()


func is_busy() -> bool:
	return _busy


## Back one take (the free undo, or an extra one); false if not possible now.
func undo(extra: bool = false) -> bool:
	if _busy or run == null or not run.undo(extra):
		return false
	_rebuild()
	return true


## Back to the last state the doom detector proved solvable (free).
func rewind() -> bool:
	if _busy or run == null or not run.rewind_to_safe():
		return false
	_rebuild()
	return true


## After a loss: two more counter slots, the held plate goes on the counter.
func continue_game() -> bool:
	if _busy or run == null or not run.continue_game():
		return false
	for view: SushiPlateView in _plates.values():
		view.warn = 0.0
	_layout()
	var events := run.state.events.duplicate()
	run.state.events.clear()
	_playback(events)
	return true


## Pulses the plate to take next (the doom detector's solution, else a solver hint). False if
## there is no move that keeps the level winnable.
func hint() -> bool:
	if _busy or run == null or run.state.is_over():
		return false
	var w := -1
	if _doom.verdict == SushiDoom.Verdict.SAFE and not _doom.solution.is_empty():
		w = _doom.solution[0]
	else:
		w = SushiSolver.hint(run.state)
	if w < 0:
		return false
	_show_hint(run.state.window_plate(w))
	return true


## What a tap on window position `w` does (also used by tests and the playtest tool).
func tap(w: int) -> void:
	if run == null or run.state.is_over():
		return
	if _busy:
		_pending = w
		_speed = HURRY
		return
	_speed = 1.0
	_take(w)


## The window position under `point` (board space), -1 if none.
func window_at(point: Vector2) -> int:
	if run == null:
		return -1
	var reach := minf(PLATE_RADIUS * WINDOW_SCALE * TAP_SLACK, _belt.spacing() * 0.5)
	var best := -1
	var best_distance := INF
	for w in run.state.window:
		var distance := point.distance_to(_belt.point_at(float(w)))
		if distance < reach and distance < best_distance:
			best = w
			best_distance = distance
	return best


## Where window position `w` is in viewport coordinates (for injected taps in tools and tests).
func window_point(w: int) -> Vector2:
	return get_global_transform_with_canvas() * _belt.point_at(float(w))


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var w := window_at(press.position)
	if w >= 0:
		accept_event()
		tap(w)


func _process(_delta: float) -> void:
	if _busy or run == null or _doom.verdict != SushiDoom.Verdict.SEARCHING:
		return
	match _doom.tick():
		SushiDoom.Verdict.SAFE:
			run.mark_safe()
		SushiDoom.Verdict.DOOMED:
			doomed.emit()


func _take(w: int) -> void:
	if run.state.window_plate(w) < 0:
		return
	_stop_hint()
	_set_guide(false)
	_doom.stop()
	_took_any = true
	run.take(w)
	var events := run.state.events.duplicate()
	run.state.events.clear()
	Haptics.pulse(12, 0.35)
	SushiSfx.play(&"take")
	took.emit()
	_playback(events)


func _playback(events: Array[Dictionary]) -> void:
	_busy = true
	if events.any(func(e: Dictionary) -> bool: return e.kind == &"advance"):
		_step_belt()
	var hop := 0
	for e in events:
		match e.kind:
			&"take":
				_lift(int(e.plate))
			&"pack":
				if e.from == &"counter":
					# The relief cascade: each hop a semitone higher.
					SushiSfx.play(&"hop", hop)
					hop += 1
					_pack(int(e.plate), int(e.slot), int(e.cell), false)
					await _wait(HOP_GAP)
				else:
					await _pack(int(e.plate), int(e.slot), int(e.cell))
			&"counter":
				await _to_counter(int(e.plate), int(e.index))
			&"close":
				await _close(int(e.slot))
			&"open":
				await _open(int(e.slot), int(e.bento))
			&"lost":
				_overflow(int(e.plate))
	await _await_flights()
	if _belt_tween != null and _belt_tween.is_running():
		await _belt_tween.finished
	_arrange_counter()
	_show_previews(run.state.next_bento)
	_busy = false
	_settle()


func _settle() -> void:
	changed.emit()
	var state := run.state
	queue_redraw()
	if state.is_won():
		_celebrate()
		won.emit()
		return
	if state.lost:
		SushiSfx.play(&"fail")
		lost.emit()
		return
	_update_counter_warning()
	_doom.watch(state)
	if guide and not _took_any:
		_set_guide(true)
	if _pending >= 0:
		var w := _pending
		_pending = -1
		_speed = HURRY
		_take(w)


# --- building and layout ---

func _rebuild() -> void:
	_stop_hint()
	_set_guide(false)
	_doom.stop()
	for view: SushiPlateView in _plates.values():
		view.queue_free()
	_plates.clear()
	_flying.clear()
	for view in _bentos:
		view.queue_free()
	_bentos.clear()
	var state := run.state
	_belt.slots = state.belt_size()
	_belt.window = state.window
	_shown_offset = float(state.offset)
	_belt.travel = _shown_offset
	for plate in state.belt_size():
		if state.on_belt(plate):
			_plates[plate] = _new_plate(plate)
	for plate in state.counter.items:
		var view := _new_plate(plate)
		view.shadow = true
		_plates[plate] = view
	if state.held >= 0:
		var held := _new_plate(state.held)
		held.warn = 1.0
		_plates[state.held] = held
	for slot in state.open_count():
		var bento := SushiBentoView.new()
		_bento_layer.add_child(bento)
		_bentos.append(bento)
		bento.want = state.open_type(slot)
		for cell in SushiState.BENTO_SIZE:
			var plate := state.open_plates[slot * SushiState.BENTO_SIZE + cell]
			bento.set_cell(cell, state.plate_type(plate) if plate >= 0 else -1)
		bento.visible = bento.want >= 0
	_show_previews(state.next_bento)
	_layout()
	_settle()


func _new_plate(plate: int) -> SushiPlateView:
	var view := SushiPlateView.new()
	view.plate = plate
	view.type = run.state.plate_type(plate)
	view.radius = PLATE_RADIUS
	_plate_layer.add_child(view)
	return view


func _layout() -> void:
	if run == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# The loop fills the board up to MAX_LOOP and sits at the bottom, so the window is near the thumb.
	var loop := Vector2(minf(size.x, MAX_LOOP.x), minf(size.y, MAX_LOOP.y))
	var outer := Rect2(Vector2((size.x - loop.x) * 0.5, size.y - loop.y), loop)
	_belt.band_width = BAND
	_belt.corner_radius = CORNER
	_belt.rect = outer.grow(-BAND * 0.5 - 2.0)
	_interior = _belt.rect.grow(-BAND * 0.5 - 14.0)
	var state := run.state
	var preview_height := 66.0 if state.preview > 0 else 0.0
	var needed := preview_height + SushiBentoView.SIZE.y + PLANK_HEIGHT + 70.0
	_bento_scale = clampf(_interior.size.y / needed, 0.7, 1.0)
	var plank := PLANK_HEIGHT * _bento_scale
	_counter_rect = Rect2(Vector2(_interior.position.x + 8.0, _interior.end.y - plank - 16.0),
			Vector2(_interior.size.x - 16.0, plank))
	# Preview and open bentos as one group, a little above the middle of the space over the counter.
	var group := (preview_height + 8.0 + SushiBentoView.SIZE.y) * _bento_scale
	var free := _counter_rect.position.y - _interior.position.y
	var top := _interior.position.y + maxf(10.0, (free - group) * 0.35)
	_preview_points.clear()
	for i in state.preview:
		var x := _interior.get_center().x + (float(i) - float(state.preview - 1) * 0.5) * 92.0 * _bento_scale
		_preview_points.append(Vector2(x, top + preview_height * 0.5 * _bento_scale))
	var bento_y := top + (preview_height + 8.0) * _bento_scale + SushiBentoView.SIZE.y * 0.5 * _bento_scale
	_bento_points.clear()
	for slot in state.open_count():
		var offset := (float(slot) - float(state.open_count() - 1) * 0.5) * (SushiBentoView.SIZE.x + 22.0) * _bento_scale
		_bento_points.append(Vector2(_interior.get_center().x + offset, bento_y))
	for slot in _bentos.size():
		_bentos[slot].position = _bento_points[slot]
		_bentos[slot].scale = Vector2.ONE * _bento_scale
	for i in _previews.size():
		_previews[i].position = _preview_points[i]
		_previews[i].scale = Vector2.ONE * PREVIEW_SCALE * _bento_scale
	_place_belt_plates()
	_arrange_counter(true)
	var held: SushiPlateView = _plates.get(state.held)
	if held != null:
		held.position = _held_point()
	queue_redraw()


func _place_belt_plates() -> void:
	var state := run.state
	for plate: int in _plates:
		if _flying.has(plate) or not state.on_belt(plate):
			continue
		var ring := float(plate) + _shown_offset
		var view := _plates[plate]
		view.position = _belt.point_at(ring)
		view.scale = Vector2.ONE * _window_scale(ring)
		view.z_index = 1 if view.scale.x > 1.01 else 0


## Plates swell as they ride into the window and shrink as they leave.
func _window_scale(ring: float) -> float:
	var n := float(run.state.belt_size())
	var d := fposmod(ring + n * 0.5, n) - n * 0.5
	var outside := maxf(-0.5 - d, d - (float(run.state.window) - 0.5))
	return lerpf(WINDOW_SCALE, 1.0, clampf(outside / 0.6 + 0.0, 0.0, 1.0)) if outside > 0.0 else WINDOW_SCALE


func _counter_point(index: int) -> Vector2:
	var capacity := maxi(run.state.counter.capacity, 1)
	var step := _counter_rect.size.x / float(capacity)
	return Vector2(_counter_rect.position.x + step * (float(index) + 0.5), _counter_rect.get_center().y)


func _counter_radius() -> float:
	var step := _counter_rect.size.x / float(maxi(run.state.counter.capacity, 1))
	return minf(COUNTER_RADIUS * _bento_scale, step * 0.42)


func _held_point() -> Vector2:
	return Vector2(_counter_rect.get_center().x, _counter_rect.position.y - _counter_radius() * 1.6)


## Counter plates to their slots, in counter order.
func _arrange_counter(instant: bool = false) -> void:
	if run == null:
		return
	var items := run.state.counter.items
	var scale_to := Vector2.ONE * _counter_radius() / PLATE_RADIUS
	for i in items.size():
		var view: SushiPlateView = _plates.get(items[i])
		if view == null or _flying.has(items[i]):
			continue
		view.shadow = true
		view.z_index = 0
		if instant:
			view.position = _counter_point(i)
			view.scale = scale_to
		else:
			var tween := view.create_tween().set_parallel()
			tween.tween_property(view, ^"position", _counter_point(i), 0.16 / _speed)
			tween.tween_property(view, ^"scale", scale_to, 0.16 / _speed)


func _show_previews(first: int) -> void:
	var state := run.state
	var wanted := 0
	for i in state.preview:
		if first + i < state.queue.size():
			wanted += 1
	while _previews.size() < wanted:
		var view := SushiBentoView.new()
		_bento_layer.add_child(view)
		_previews.append(view)
	while _previews.size() > wanted:
		_previews.pop_back().queue_free()
	for i in _previews.size():
		_previews[i].want = state.queue[first + i]
		_previews[i].modulate.a = 0.9
		if i < _preview_points.size():
			_previews[i].position = _preview_points[i]
			_previews[i].scale = Vector2.ONE * PREVIEW_SCALE * _bento_scale


# --- animations ---

func _step_belt() -> void:
	if _belt_tween != null:
		_belt_tween.kill()
	var target := float(run.state.offset)
	var steps := clampf(target - _shown_offset, 1.0, 3.0)
	_belt_tween = create_tween()
	_belt_tween.tween_method(_set_shown_offset, _shown_offset, target, STEP_TIME * sqrt(steps) / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	SushiSfx.play(&"tick")


func _set_shown_offset(value: float) -> void:
	_shown_offset = value
	_belt.travel = value
	_place_belt_plates()


func _lift(plate: int) -> void:
	var view: SushiPlateView = _plates.get(plate)
	if view == null:
		return
	_flying[plate] = true
	view.z_index = 3
	var tween := view.create_tween()
	tween.tween_property(view, ^"scale", view.scale * 1.08, 0.05 / _speed)


## Flies `plate` along an arc into cell `cell` of open slot `slot`; the cell fills on landing
## (with a porcelain clink, unless the cascade's rising hops are playing instead).
func _pack(plate: int, slot: int, cell: int, clink: bool = true) -> void:
	var view: SushiPlateView = _plates.get(plate)
	if view == null:
		return
	var bento := _bentos[slot]
	var target := bento.cell_point(cell)
	var type := view.type
	await _fly(view, target, 0.66 * _bento_scale)
	bento.set_cell(cell, type)
	_plates.erase(plate)
	_flying.erase(plate)
	view.queue_free()
	if clink:
		SushiSfx.play(&"clink")


func _to_counter(plate: int, index: int) -> void:
	var view: SushiPlateView = _plates.get(plate)
	if view == null:
		return
	view.warn = 0.0
	await _fly(view, _counter_point(index), _counter_radius() / PLATE_RADIUS)
	_flying.erase(plate)
	view.shadow = true
	view.z_index = 0
	SushiSfx.play(&"counter")


func _fly(view: SushiPlateView, target: Vector2, end_scale: float) -> void:
	_active_flights += 1
	var start := view.position
	var start_scale := view.scale.x
	var lift := Vector2(0.0, -minf(120.0, start.distance_to(target) * 0.35))
	var control := (start + target) * 0.5 + lift
	view.z_index = 3
	var tween := view.create_tween()
	tween.tween_method(func(t: float) -> void:
		view.position = start.lerp(control, t).lerp(control.lerp(target, t), t)
		view.scale = Vector2.ONE * lerpf(start_scale, end_scale, t),
		0.0, 1.0, FLY_TIME / _speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_active_flights -= 1
	_landed.emit()


func _await_flights() -> void:
	while _active_flights > 0:
		await _landed


func _close(slot: int) -> void:
	await _await_flights()
	var bento := _bentos[slot]
	await bento.close(_speed)
	Haptics.pulse(30, 0.6)
	if Juice.motion_scale > 0.0:
		_grains.amount = maxi(4, int(20.0 * Juice.motion_scale))
		_grains.color = SushiPalette.RICE
		_grains.position = bento.position
		_grains.restart()
	bento_closed.emit()
	var tween := bento.create_tween().set_parallel()
	tween.tween_property(bento, ^"position:y", bento.position.y - 36.0, 0.2 / _speed)
	tween.tween_property(bento, ^"modulate:a", 0.0, 0.2 / _speed)
	await tween.finished
	bento.visible = false


## The next bento slides down from the queue preview into `slot`.
func _open(slot: int, index: int) -> void:
	var bento := _bentos[slot]
	bento.visible = true
	bento.lid = 0.0
	bento.ribbon = 0.0
	bento.clear_cells()
	bento.want = run.state.queue[index]
	bento.modulate.a = 1.0
	var from := _preview_points[0] if not _preview_points.is_empty() else _bento_points[slot] + Vector2(0, -40)
	bento.position = from
	bento.scale = Vector2.ONE * PREVIEW_SCALE * _bento_scale
	_show_previews(index + 1)
	var tween := bento.create_tween().set_parallel()
	tween.tween_property(bento, ^"position", _bento_points[slot], 0.18 / _speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bento, ^"scale", Vector2.ONE * _bento_scale, 0.18 / _speed)
	await tween.finished


func _overflow(plate: int) -> void:
	var view: SushiPlateView = _plates.get(plate)
	if view == null:
		return
	view.warn = 1.0
	_fly(view, _held_point(), 0.9)
	if Juice.motion_scale > 0.0:
		for item in run.state.counter.items:
			var counter_plate: SushiPlateView = _plates.get(item)
			if counter_plate == null:
				continue
			var x := counter_plate.position.x
			var nudge := counter_plate.create_tween()
			nudge.tween_property(counter_plate, ^"position:x", x + 3.0, 0.05)
			nudge.tween_property(counter_plate, ^"position:x", x - 3.0, 0.08)
			nudge.tween_property(counter_plate, ^"position:x", x, 0.05)


func _celebrate() -> void:
	Haptics.pulse(60, 0.8)
	SushiSfx.play(&"win")
	if Juice.motion_scale <= 0.0:
		return
	_grains.amount = maxi(8, int(36.0 * Juice.motion_scale))
	_grains.color = SushiPalette.GOLD
	_grains.position = _interior.get_center()
	_grains.restart()


func _update_counter_warning() -> void:
	var room := run.state.counter.room()
	if _counter_tween != null:
		_counter_tween.kill()
		_counter_tween = null
	_counter_glow = 0.0
	if room <= 1 and run.state.counter.capacity > 0:
		counter_low.emit(room)
		if room == 1:
			SushiSfx.play(&"warn")
			_counter_tween = create_tween().set_loops(3)
			_counter_tween.tween_method(_set_counter_glow, 0.0, 1.0, 0.35)
			_counter_tween.tween_method(_set_counter_glow, 1.0, 0.3, 0.35)
	queue_redraw()


func _set_counter_glow(value: float) -> void:
	_counter_glow = value
	queue_redraw()


func _show_hint(plate: int) -> void:
	_stop_hint()
	var view: SushiPlateView = _plates.get(plate)
	if view == null:
		return
	_hint_plate = plate
	_hint_tween = view.create_tween().set_loops()
	_hint_tween.tween_property(view, ^"glow", 1.0, 0.35)
	_hint_tween.tween_property(view, ^"glow", 0.25, 0.35)


func _stop_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	if _ripple_tween != null:
		_ripple_tween.kill()
		_ripple_tween = null
	var view: SushiPlateView = _plates.get(_hint_plate)
	if view != null:
		view.glow = 0.0
		view.ripple = 0.0
	_hint_plate = -1


## The tutorial guide: the window frame breathes and the plate that fits glows.
func _set_guide(on: bool) -> void:
	if _guide_tween != null:
		_guide_tween.kill()
		_guide_tween = null
	_belt.window_glow = 0.0
	if not on or run == null:
		return
	for w in range(run.state.window - 1, -1, -1):
		var plate := run.state.window_plate(w)
		if plate >= 0 and run.state.fits(run.state.plate_type(plate)):
			_show_hint(plate)
			var view: SushiPlateView = _plates.get(plate)
			if view != null and Juice.motion_scale > 0.0:
				_ripple_tween = view.create_tween().set_loops()
				_ripple_tween.tween_property(view, ^"ripple", 1.0, 0.9).from(0.0).set_ease(Tween.EASE_OUT)
				_ripple_tween.tween_interval(0.3)
			break
	_guide_tween = create_tween().set_loops()
	_guide_tween.tween_property(_belt, ^"window_glow", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_guide_tween.tween_property(_belt, ^"window_glow", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed, true, false, true).timeout


func _draw() -> void:
	if run == null or _belt.rect.size == Vector2.ZERO:
		return
	# The wooden sushi counter inside the loop, and the plank the counter plates wait on.
	var wood := _belt.rect.grow(-BAND * 0.5 + 1.0)
	SushiArt.draw_panel(self, wood, maxf(CORNER - BAND * 0.5, 12.0), SushiPalette.WOOD, SushiPalette.WOOD_EDGE)
	var grain := Color(SushiPalette.WOOD_EDGE, 0.35)
	var y := wood.position.y + 28.0
	while y < wood.end.y - 20.0:
		draw_line(Vector2(wood.position.x + 24.0, y), Vector2(wood.end.x - 24.0, y), grain, 1.5)
		y += 46.0
	SushiArt.draw_panel(self, _counter_rect, _counter_rect.size.y * 0.3, SushiPalette.CREAM, SushiPalette.WOOD_EDGE)
	var state := run.state
	var full := state.counter.room() <= 0
	var ring := SushiPalette.VERMILLION if full else SushiPalette.WOOD_EDGE.lerp(SushiPalette.VERMILLION, _counter_glow)
	for i in state.counter.capacity:
		draw_arc(_counter_point(i), _counter_radius() * 1.08, 0.0, TAU, 32, ring, 3.0 + 2.0 * _counter_glow, true)
