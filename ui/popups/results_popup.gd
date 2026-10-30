extends Modal
## End-of-level popup. Call show_win(level, stars, coins, can_double, note) or
## show_lose(level, cost, affordable, ad_ready, can_continue, rush, owned) after opening. Closes
## with "next", "retry", "home", "continue" (two more counter slots, or five more takes after a
## missed rush order: an owned continue or coins) or "continue_ad" (the same after a rewarded video). A win can offer "×2 coins" for a rewarded video: the popup emits double_requested and
## the game screen calls doubled(total) when the video paid out. One primary action at a time.
## The game screen decides about interstitials when this opens (AdPolicy).

signal double_requested

var _double: Button
var _ad_continue: Button


func _ready() -> void:
	super._ready()
	%NextButton.pressed.connect(close.bind("next"))
	%RetryButton.pressed.connect(close.bind("retry"))
	%HomeButton.pressed.connect(close.bind("home"))
	%ContinueButton.pressed.connect(close.bind("continue"))
	_double = _add_button(&"GhostButton", "Watch a video:  ×2 coins", %NextButton)
	_double.pressed.connect(_on_double)
	_ad_continue = _add_button(&"AccentButton", "Continue  +2 slots  ·  free video", %ContinueButton)
	_ad_continue.pressed.connect(close.bind("continue_ad"))


func show_win(level: int, stars: int, coins: int, can_double: bool = false, note: String = "") -> void:
	%Headline.text = "Level %d complete!" % level
	%Message.text = note if not note.is_empty() else ["Done!", "Nice!", "Great!", "Perfect!"][clampi(stars, 0, 3)]
	%ContinueButton.hide()
	_ad_continue.hide()
	%NextButton.show()
	%Stars.show()
	%RewardRow.show()
	_double.visible = can_double and coins > 0
	_double.disabled = true
	%Reward.value = 0
	Haptics.big()
	%Stars.reveal(stars, 0.3)
	for i in stars:
		_chime_star.call_deferred(i)
	await get_tree().create_timer(0.3 * stars + 0.2, true, false, true).timeout
	if not is_inside_tree():
		return
	%Reward.set_value(coins)
	if coins > 0:
		SushiSfx.play(&"coin")
	_double.disabled = false


## The video paid out: the reward pill counts on to `total`.
func doubled(total: int) -> void:
	_double.hide()
	%Reward.set_value(total)
	SushiSfx.play(&"coin")
	Haptics.big()


## `cost` coins buy two more counter slots (the button stays visible but disabled when the player
## cannot afford it, so the offer is clear and never the only way on); with `ad_ready` the same
## continue is free after a video. `can_continue` false hides both (the continue cap).
func show_lose(level: int, cost: int = 0, affordable: bool = false, ad_ready: bool = false,
		can_continue: bool = true, rush: bool = false, owned: int = 0) -> void:
	%Headline.text = "Rush order missed" if rush else "Counter full"
	if rush:
		%Message.text = "Level %d. The customer left before the bento was packed. Five more takes, or try again." % level
	else:
		%Message.text = "Level %d. That plate had nowhere to go. Two more counter slots, or try again." % level
	var gain := "+%d takes" % SushiState.RUSH_EXTRA if rush else "+2 slots"
	_ad_continue.text = "Continue  %s  ·  free video" % gain
	%Stars.hide()
	%RewardRow.hide()
	%NextButton.hide()
	_double.hide()
	_ad_continue.visible = can_continue and ad_ready
	%ContinueButton.visible = can_continue and cost > 0
	%ContinueButton.text = "Continue  %s  ·  %d" % [gain, cost]
	%ContinueButton.icon = Icons.COIN
	%ContinueButton.disabled = not affordable
	if owned > 0:
		# A continue the player bought in the shop: it costs nothing more here.
		%ContinueButton.visible = can_continue
		%ContinueButton.text = "Continue  %s  ·  %d left" % [gain, owned]
		%ContinueButton.icon = Icons.PLAY
		%ContinueButton.disabled = false
		affordable = true
		_ad_continue.visible = false
	# One primary action: the free continue, else the coin continue if affordable, else Retry.
	var coin_primary: bool = not _ad_continue.visible and affordable and %ContinueButton.visible
	%ContinueButton.theme_type_variation = &"AccentButton" if coin_primary else &"Button"
	%RetryButton.theme_type_variation = &"Button" if _ad_continue.visible or coin_primary else &"AccentButton"
	if not can_continue:
		%Message.text = "Level %d. %s Have another go: the belt starts fresh." % [level,
				"The customer left." if rush else "That plate had nowhere to go."]


func _on_double() -> void:
	_double.disabled = true
	double_requested.emit()


func _chime_star(index: int) -> void:
	await get_tree().create_timer(0.3 * float(index + 1), true, false, true).timeout
	if is_inside_tree():
		SushiSfx.play(&"star", index * 2)


func _add_button(variation: StringName, text: String, before: Control) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.text = text
	button.icon = Icons.VIDEO
	button.hide()
	before.get_parent().add_child(button)
	before.get_parent().move_child(button, before.get_index())
	return button


## The video did not pay out: the offer stays open.
func double_failed() -> void:
	_double.disabled = false
