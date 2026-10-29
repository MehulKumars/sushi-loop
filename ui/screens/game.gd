extends Screen
## Game screen: one Sushi Loop level (SushiBoard: the belt loop, bentos and counter), the HUD
## (pause, level, coins, bentos packed and the stars this attempt is on course for), Undo and Hint
## in the bottom corners, the doom card (a free step back or a retry once the solver proves the level lost)
## and the end flow: results, then the first-time rewards (chapter bonus, star gifts), then
## next / retry / home; after a loss a continue with two more counter slots, free after a
## rewarded video or for coins. Firsts are explained once: a new dish gets its card, the counter
## and the three-star limit a short tip. Videos are always the player's choice. Interstitials
## are only considered when the results popup opens, and only if AdPolicy agrees.

const COINS_PER_STAR: int = 10
## Hard and super-hard levels pay more per star.
const ROLE_BONUS: Dictionary[String, float] = {"hard": 1.5, "super": 2.0}
const UNDO_COST: int = 30
const HINT_COST: int = 30
const CONTINUE_COST: int = 50
## Continues per attempt (videos and coins together), so a level is never bought outright.
const MAX_CONTINUES: int = 3
const FREE_HINTS: int = 1
## These levels guide the first take (the pick window and the plate that fits glow).
const GUIDED_LEVELS: int = 2
const GIFT_ART := preload("res://assets/deco/gift.png")
const LANTERN_ART := preload("res://assets/deco/lantern.png")

## Shared across levels so ad pacing (first session free, gaps, caps) works for the whole run.
static var ad_policy := AdPolicy.new()
static var _policy_started: bool = false

var _level: int = 1
var _finished: bool = false
var _hints_left: int = FREE_HINTS
var _ad_continue_used: bool = false
var _coins_won: int = 0
var _outlook: int = 3
var _undo_badge: Label
var _hint_badge: Label
var _doom_card: PanelContainer
var _stars: StarRating
var _results: Modal
## The hard-level banner while it shows (it leaves early on the first take or a doom card).
var _banner: Control

@onready var _board: SushiBoardView = %SushiBoard


func _ready() -> void:
	if not _policy_started:
		_policy_started = true
		ad_policy.start_session(maxi(1, Progress.count("sessions")))
	_level = clampi(Screens.level, 1, SushiLevels.count())
	var level := SushiLevels.level(_level)
	%LevelLabel.text = "Level %d" % _level
	%Coins.value = Progress.coins()
	%GoalIcon.texture = Icons.CHECK_CIRCLE
	%GoalIcon.modulate = get_theme_color(&"gold", &"Tokens")
	(%Goal as ProgressBar).value = 0.0
	%PauseButton.pressed.connect(_pause)
	%UndoButton.pressed.connect(_on_undo)
	%HintButton.pressed.connect(_on_hint)
	_undo_badge = _add_badge(%UndoButton)
	_hint_badge = _add_badge(%HintButton)
	_stars = StarRating.new()
	_stars.star_size = 30.0
	_stars.add_theme_constant_override(&"separation", 0)
	(%Goal as Control).get_parent().add_child(_stars)
	_board.changed.connect(_refresh)
	_board.took.connect(_hide_doom_card)
	_board.took.connect(_hide_banner)
	_board.doomed.connect(_show_doom_card)
	_board.won.connect(_on_won)
	_board.lost.connect(_on_lost)
	_board.counter_used.connect(_on_counter_used)
	_board.bento_collected.connect(_on_bento_collected)
	_board.outside_tap.connect(_on_outside_tap)
	_board.chapter = SushiLevels.chapter(_level)
	_board.guide = _level <= GUIDED_LEVELS
	_build_doom_card()
	_board.play(level)
	resized.connect(_place_collect_point)
	_place_collect_point.call_deferred()
	Events.level_started.emit(str(_level))
	SushiSfx.music()
	_intro(level)


func on_back() -> void:
	_pause()


## Ends the level: results, then any first-time rewards, then where the player chose to go.
func finish(won: bool, stars: int) -> void:
	if _finished:
		return
	_finished = true
	_hide_doom_card()
	ad_policy.record_level_result(won)
	if not won:
		_finish_lost()
		return
	var first_win := Progress.stars(_level) == 0
	var best := Progress.record_win(_level, stars)
	_coins_won = coins_for(stars, SushiLevels.level(_level).role)
	Progress.add_coins(_coins_won)
	Services.leaderboard.submit_score("stars", Progress.total_stars())
	# Instant: the results popup pauses the game, which would freeze a count-up here.
	%Coins.value = Progress.coins()
	Events.level_finished.emit(str(_level), true, stars)
	_results = UI.open(load(Screens.RESULTS) as PackedScene)
	_results.connect(&"double_requested", _on_double)
	var note := "New best!" if best and not first_win else ""
	_results.call(&"show_win", _level, stars, _coins_won, Services.ads.is_rewarded_ready("double"), note)
	Events.results_shown.emit(str(_level), true)
	_maybe_show_interstitial(true)
	var choice: Variant = await _results.closed
	_results = null
	await _rewards(first_win)
	_go(choice)


## Coins for `stars` on a level of `role` (hard and super-hard levels pay more).
static func coins_for(stars: int, role: String) -> int:
	return roundi(float(stars * COINS_PER_STAR) * float(ROLE_BONUS.get(role, 1.0)))


func _finish_lost() -> void:
	Events.level_finished.emit(str(_level), false, 0)
	while true:
		_results = UI.open(load(Screens.RESULTS) as PackedScene)
		var run := _board.run
		_results.call(&"show_lose", _level, CONTINUE_COST, Progress.coins() >= CONTINUE_COST,
				not _ad_continue_used and Services.ads.is_rewarded_ready("continue"), run.continues < MAX_CONTINUES)
		Events.results_shown.emit(str(_level), false)
		var choice: Variant = await _results.closed
		_results = null
		if choice == "continue_ad":
			if await _watch_video("continue"):
				_ad_continue_used = true
				_resume_after_continue()
				return
			continue
		if choice == "continue":
			if Progress.spend_coins(CONTINUE_COST):
				_resume_after_continue()
				return
			continue
		_go(choice)
		return


func _resume_after_continue() -> void:
	if _board.continue_game():
		_finished = false
		%Coins.set_value(Progress.coins())
	else:
		UI.goto(Screens.GAME)


func _go(choice: Variant) -> void:
	match choice:
		"next":
			if _level >= SushiLevels.count():
				# The very last level: home shows the whole road won.
				UI.goto(Screens.MAIN_MENU)
				return
			Screens.level = _level + 1
			UI.goto(Screens.GAME)
		"retry":
			UI.goto(Screens.GAME)
		_:
			UI.goto(Screens.MAIN_MENU)


## A finished chapter (first win of its last level) and every star gift now earned, each with
## its own card.
func _rewards(first_win: bool) -> void:
	if first_win and SushiMeta.is_chapter_finale(_level):
		var chapter := SushiLevels.chapter(_level)
		var last := chapter >= SushiMeta.chapter_count()
		Progress.add_coins(SushiMeta.CHAPTER_BONUS)
		var card := UI.open(load(Screens.REWARD) as PackedScene)
		card.call(&"show_gift", "Chapter complete!",
				"Every bento packed!" if last else "%s is open" % SushiMeta.chapter_name(chapter + 1),
				"More levels are on their way." if last else "A new counter to work at, in new colours.",
				LANTERN_ART, SushiMeta.CHAPTER_BONUS)
		await card.closed
	while SushiMeta.gifts_ready() > 0:
		var coins := SushiMeta.open_gift()
		var card := UI.open(load(Screens.REWARD) as PackedScene)
		card.call(&"show_gift", "A gift from the chef", "%d stars collected" % (Progress.count("gifts") * SushiMeta.GIFT_EVERY),
				"Coins for hints, undos and continues.", GIFT_ART, coins)
		await card.closed
	%Coins.value = Progress.coins()
	# The Play review sheet once, after the first chapter is done (a happy moment; Play decides
	# whether it actually shows).
	if first_win and _level == SushiMeta.chapter_range(1).y and _tip_once("review_asked"):
		Services.review.request_review()


func _on_won() -> void:
	# A beat to see the last bento packed and the petals fall before the results.
	await get_tree().create_timer(0.7).timeout
	finish(true, _board.run.stars())


func _on_lost() -> void:
	await get_tree().create_timer(0.6).timeout
	finish(false, 0)


func _on_double() -> void:
	var popup := _results
	if await _watch_video("double") and is_instance_valid(popup):
		Progress.add_coins(_coins_won)
		popup.call(&"doubled", _coins_won * 2)
		%Coins.value = Progress.coins()
	elif is_instance_valid(popup):
		popup.call(&"double_failed")


## Shows a rewarded video for `placement`; true if it paid out.
func _watch_video(placement: String) -> bool:
	if not Services.ads.is_rewarded_ready(placement):
		UI.toast("No video right now. Try again in a moment.", Icons.VIDEO)
		return false
	Services.ads.show_rewarded(placement)
	if Services.ads is MockAdsService:
		UI.toast("Test build: a real video would play here", Icons.VIDEO, 1.5)
	var result: Array = await Services.ads.rewarded_finished
	ad_policy.record_rewarded_shown(Time.get_ticks_msec() / 1000.0)
	var granted := result.size() > 1 and bool(result[1])
	if not granted:
		UI.toast("The video was cut short, so no reward this time.", Icons.VIDEO)
	return granted


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
	elif await _offer_video("An extra undo", "undo"):
		_board.undo(true)
	else:
		return
	_hide_doom_card()
	_refresh()


func _on_hint() -> void:
	if _finished or _board.is_busy():
		return
	var paid := _hints_left <= 0
	if paid and Progress.coins() < HINT_COST:
		if not await _offer_video("A free hint", "hint"):
			return
		paid = false
	if not _board.hint():
		_show_doom_card()
		return
	if _hints_left > 0:
		_hints_left -= 1
	elif paid:
		Progress.spend_coins(HINT_COST)
		%Coins.set_value(Progress.coins())
	_refresh()


## Out of coins for a booster: offers it for a short video (never forced). True if it paid out.
func _offer_video(title: String, placement: String) -> bool:
	if not Services.ads.is_rewarded_ready(placement):
		UI.toast("That costs %d coins" % (UNDO_COST if placement == "undo" else HINT_COST), Icons.COIN)
		return false
	if not await UI.confirm(title, "Watch a short video for it? Or win levels for coins.", "Watch video"):
		return false
	return await _watch_video(placement)


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
	var outlook := _board.star_outlook()
	if outlook < _outlook:
		_stars.pivot_offset = _stars.size * 0.5
		Juice.pop(_stars, 1.25, 0.25)
		Haptics.tick()
		if outlook == 2 and _tip_once("tip_stars"):
			UI.toast("Three stars need the counter at %d plates or fewer. Undo to try again." % _board.run.level.star_peak, Icons.STAR, 3.5)
	_outlook = outlook
	_stars.stars = outlook


## A packed bento landed on the HUD: the goal icon pops.
func _on_bento_collected() -> void:
	var icon: Control = %GoalIcon
	icon.pivot_offset = icon.size * 0.5
	Juice.pop(icon, 1.35, 0.2)
	_refresh()


func _on_counter_used() -> void:
	if _tip_once("tip_counter"):
		UI.toast("No open bento wants it, so it waits on the counter. A full counter ends the level.", Icons.INFO, 4.0)


## True the first time `key` is asked for (the tip is then marked as shown).
func _tip_once(key: String) -> bool:
	if Progress.count(key) > 0:
		return false
	Progress.set_count(key, 1)
	return true


func _place_collect_point() -> void:
	var icon: Control = %GoalIcon
	_board.collect_point = icon.get_global_rect().get_center()


## A new chapter's welcome card (its twist), then new dishes' cards (from level 2: level 1 is the
## guided start), each once; otherwise hard levels get a banner.
func _intro(level: SushiLevel) -> void:
	var chapter := SushiLevels.chapter(_level)
	var welcome := chapter > 1 and _level == SushiMeta.chapter_range(chapter).x and Progress.count("chapters_seen") < chapter
	if welcome:
		Progress.set_count("chapters_seen", chapter)
		await get_tree().create_timer(0.35).timeout
		var card := UI.open(load(Screens.REWARD) as PackedScene)
		card.call(&"show_gift", "Welcome to %s" % SushiMeta.chapter_name(chapter), "Chapter %d" % chapter,
				str(SushiPalette.shop(chapter).twist), LANTERN_ART, 0, "Let's go")
		await card.closed
	var dishes := SushiMeta.new_dishes(_level)
	if _level == 1:
		for type in dishes:
			SushiMeta.mark_dish_seen(type)
		dishes.clear()
	for type in dishes:
		await get_tree().create_timer(0.35).timeout
		var card := UI.open(load(Screens.REWARD) as PackedScene)
		card.call(&"show_dish", type)
		await card.closed
		SushiMeta.mark_dish_seen(type)
	if not welcome and dishes.is_empty() and ROLE_BONUS.has(level.role):
		_show_banner("Hard level" if level.role == "hard" else "Super hard level",
				"Coins per star ×%s" % str(ROLE_BONUS[level.role]).trim_suffix(".0"))


## A short, untouchable banner over the bentos that fades by itself.
func _show_banner(title_text: String, caption: String) -> void:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override(&"margin_left", 90)
	holder.add_theme_constant_override(&"margin_right", 90)
	holder.add_theme_constant_override(&"margin_top", 170)
	_board.add_child(holder)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HighlightPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	for part: Array in [[title_text, &"HeaderLabel"], [caption, &"CaptionLabel"]]:
		var label := Label.new()
		label.text = part[0]
		label.theme_type_variation = part[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	holder.modulate.a = 0.0
	_banner = holder
	var tween := holder.create_tween()
	tween.tween_property(holder, ^"modulate:a", 1.0, 0.25)
	tween.tween_interval(1.6)
	tween.tween_property(holder, ^"modulate:a", 0.0, 0.4)
	tween.tween_callback(holder.queue_free)
	SushiSfx.play(&"warn")


## The banner makes way as soon as play starts (and for the doom card).
func _hide_banner() -> void:
	if _banner == null or not is_instance_valid(_banner):
		return
	_banner.queue_free()
	_banner = null


func _pause() -> void:
	if _finished or UI.has_modal():
		return
	var choice: Variant = await UI.open(load(Screens.PAUSE) as PackedScene).closed
	match choice:
		"restart":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)


## The doom card sits over the bentos so the window stays in reach: step back (free), retry the
## level from the start, or keep going.
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
	text.text = "Every way on from here ends with a full counter. Step back to your last good move for free, or start over."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var back := Button.new()
	back.theme_type_variation = &"AccentButton"
	back.text = "Step back"
	back.icon = Icons.UNDO
	back.pressed.connect(_on_step_back)
	box.add_child(back)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	box.add_child(row)
	var retry := Button.new()
	retry.text = "Retry"
	retry.icon = Icons.REPLAY
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(UI.goto.bind(Screens.GAME))
	row.add_child(retry)
	var keep := Button.new()
	keep.theme_type_variation = &"GhostButton"
	keep.text = "Keep going"
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(_hide_doom_card)
	row.add_child(keep)
	_doom_card.hide()


func _show_doom_card() -> void:
	if _finished:
		return
	_hide_banner()
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
		if Services.ads is MockAdsService:
			UI.toast("Test build: a full-screen ad would show here", Icons.VIDEO, 1.5)


func _on_outside_tap() -> void:
	if _tip_once("tip_window"):
		UI.toast("Only the plates in the gold window can be taken. Each take moves the belt one step.", Icons.INFO, 3.5)
