extends Screen
## Game screen: one Sushi Loop level (SushiBoard: the belt loop, bentos and counter), the HUD
## (pause, level, coins, bentos packed), Undo and Hint in the bottom corners, the doom card (a
## free step back once the solver proves the level lost) and the end flow: results, then next /
## retry / home, or after a loss a continue with two more counter slots for coins.
## Interstitials are only considered when the results popup opens, and only if AdPolicy agrees.

const COINS_PER_STAR: int = 10
const UNDO_COST: int = 30
const HINT_COST: int = 30
const CONTINUE_COST: int = 50
const FREE_HINTS: int = 1
## These levels guide the first take (the pick window and the plate that fits glow).
const GUIDED_LEVELS: int = 2

## Shared across levels so ad pacing (first session free, gaps, caps) works for the whole run.
static var ad_policy := AdPolicy.new()

var _level: int = 1
var _finished: bool = false
var _hints_left: int = FREE_HINTS
var _undo_badge: Label
var _hint_badge: Label
var _doom_card: PanelContainer

@onready var _board: SushiBoardView = %SushiBoard


func _ready() -> void:
	_level = clampi(Screens.level, 1, SushiLevels.count())
	%LevelLabel.text = "Level %d" % _level
	%Coins.value = Progress.coins()
	%GoalIcon.texture = Icons.CHECK_CIRCLE
	%GoalIcon.modulate = get_theme_color(&"gold", &"Tokens")
	%PauseButton.pressed.connect(_pause)
	%UndoButton.pressed.connect(_on_undo)
	%HintButton.pressed.connect(_on_hint)
	_undo_badge = _add_badge(%UndoButton)
	_hint_badge = _add_badge(%HintButton)
	_board.changed.connect(_refresh)
	_board.took.connect(_hide_doom_card)
	_board.doomed.connect(_show_doom_card)
	_board.won.connect(_on_won)
	_board.lost.connect(_on_lost)
	_board.guide = _level <= GUIDED_LEVELS
	_build_doom_card()
	_board.play(SushiLevels.level(_level))
	Events.level_started.emit(str(_level))


func on_back() -> void:
	_pause()


## Ends the level and shows the results popup.
func finish(won: bool, stars: int) -> void:
	if _finished:
		return
	_finished = true
	_hide_doom_card()
	ad_policy.record_level_result(won)
	var coins := stars * COINS_PER_STAR if won else 0
	if won:
		Progress.record_win(_level, stars)
		Progress.add_coins(coins)
		Services.leaderboard.submit_score("stars", Progress.total_stars())
		# Instant: the results popup pauses the game, which would freeze a count-up here.
		%Coins.value = Progress.coins()
	Events.level_finished.emit(str(_level), won, stars)
	var popup := UI.open(load(Screens.RESULTS) as PackedScene)
	if won:
		popup.call(&"show_win", _level, stars, coins)
	else:
		popup.call(&"show_lose", _level, CONTINUE_COST, Progress.coins() >= CONTINUE_COST)
	Events.results_shown.emit(str(_level), won)
	_maybe_show_interstitial(won)
	var choice: Variant = await popup.closed
	match choice:
		"next":
			Screens.level = mini(_level + 1, SushiLevels.count())
			UI.goto(Screens.GAME)
		"retry":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)
		"continue":
			if Progress.spend_coins(CONTINUE_COST) and _board.continue_game():
				_finished = false
				%Coins.set_value(Progress.coins())
			else:
				UI.goto(Screens.GAME)


func _on_won() -> void:
	# A beat to see the last bento close before the results.
	await get_tree().create_timer(0.45).timeout
	finish(true, _board.run.stars())


func _on_lost() -> void:
	await get_tree().create_timer(0.6).timeout
	finish(false, 0)


func _on_undo() -> void:
	if _finished or _board.is_busy():
		return
	var run := _board.run
	if not run.can_undo():
		UI.toast("Nothing to undo yet", Icons.UNDO)
		return
	if run.undos_left() > 0:
		_board.undo()
	elif Progress.coins() >= UNDO_COST:
		Progress.spend_coins(UNDO_COST)
		_board.undo(true)
		%Coins.set_value(Progress.coins())
	else:
		UI.toast("An undo costs %d coins" % UNDO_COST, Icons.COIN)
		return
	_hide_doom_card()
	_refresh()


func _on_hint() -> void:
	if _finished or _board.is_busy():
		return
	if _hints_left <= 0 and Progress.coins() < HINT_COST:
		UI.toast("A hint costs %d coins" % HINT_COST, Icons.COIN)
		return
	if not _board.hint():
		_show_doom_card()
		return
	if _hints_left > 0:
		_hints_left -= 1
	else:
		Progress.spend_coins(HINT_COST)
		%Coins.set_value(Progress.coins())
	_refresh()


func _refresh() -> void:
	var state := _board.run.state
	var total := state.queue.size()
	%MovesLabel.text = "%d / %d bentos" % [state.closed, total]
	var bar: ProgressBar = %Goal
	bar.max_value = total
	var tween := create_tween()
	tween.tween_property(bar, ^"value", float(state.closed), 0.25 * Juice.motion_scale)
	_undo_badge.text = str(_board.run.undos_left()) if _board.run.undos_left() > 0 else str(UNDO_COST)
	_hint_badge.text = str(_hints_left) if _hints_left > 0 else str(HINT_COST)


func _pause() -> void:
	if _finished or UI.has_modal():
		return
	var choice: Variant = await UI.open(load(Screens.PAUSE) as PackedScene).closed
	match choice:
		"restart":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)


## The doom card sits over the bentos so the window stays in reach ("Keep going" is allowed).
func _build_doom_card() -> void:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override(&"margin_left", 40)
	holder.add_theme_constant_override(&"margin_right", 40)
	holder.add_theme_constant_override(&"margin_top", 110)
	_board.add_child(holder)
	_doom_card = PanelContainer.new()
	_doom_card.theme_type_variation = &"HighlightPanel"
	holder.add_child(_doom_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_doom_card.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "No way out from here"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := Label.new()
	text.theme_type_variation = &"CaptionLabel"
	text.text = "Every way on from here ends with a full counter. Step back to your last good move, free."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var back := Button.new()
	back.theme_type_variation = &"AccentButton"
	back.text = "Step back"
	back.icon = Icons.UNDO
	back.pressed.connect(_on_step_back)
	box.add_child(back)
	var keep := Button.new()
	keep.theme_type_variation = &"GhostButton"
	keep.text = "Keep going"
	keep.pressed.connect(_hide_doom_card)
	box.add_child(keep)
	_doom_card.hide()


func _show_doom_card() -> void:
	if _finished:
		return
	_doom_card.show()
	Juice.pop(_doom_card, 1.04, 0.16)


func _hide_doom_card() -> void:
	if _doom_card != null:
		_doom_card.hide()


func _on_step_back() -> void:
	if _board.rewind():
		_hide_doom_card()
		_refresh()


func _add_badge(button: Button) -> Label:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	button.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position += Vector2(10, -10)
	return label


func _maybe_show_interstitial(won: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if ad_policy.can_show_interstitial(_level, won, now) and Services.ads.is_interstitial_ready("results"):
		Services.ads.show_interstitial("results")
		ad_policy.record_interstitial_shown(now)
