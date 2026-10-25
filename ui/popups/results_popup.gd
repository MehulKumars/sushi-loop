extends Modal
## End-of-level popup. Call show_win(level, stars, coins) or show_lose(level, cost, affordable)
## after opening. Closes with "next", "retry", "home" or "continue" (lose only: two more counter
## slots, which the game screen pays for in coins). The game screen decides about interstitials
## when this opens (AdPolicy).


func _ready() -> void:
	super._ready()
	%NextButton.pressed.connect(close.bind("next"))
	%RetryButton.pressed.connect(close.bind("retry"))
	%HomeButton.pressed.connect(close.bind("home"))
	%ContinueButton.pressed.connect(close.bind("continue"))


func show_win(level: int, stars: int, coins: int) -> void:
	%Headline.text = "Level %d complete!" % level
	%Message.text = ["Done!", "Nice!", "Great!", "Perfect!"][clampi(stars, 0, 3)]
	%ContinueButton.hide()
	%NextButton.show()
	%Stars.show()
	%RewardRow.show()
	%Reward.value = 0
	Haptics.big()
	%Stars.reveal(stars, 0.3)
	await get_tree().create_timer(0.3 * stars + 0.2, true, false, true).timeout
	if is_inside_tree():
		%Reward.set_value(coins)


## `cost` coins buy two more counter slots; the button stays visible but disabled when the player
## cannot afford it, so the offer is always clear and never the only way on.
func show_lose(level: int, cost: int = 0, affordable: bool = false) -> void:
	%Headline.text = "Counter full"
	%Message.text = "Level %d. The plate had nowhere to go. Two more counter slots, or try again." % level
	%Stars.hide()
	%RewardRow.hide()
	%NextButton.hide()
	%ContinueButton.visible = cost > 0
	%ContinueButton.text = "Continue  +2 slots  ·  %d" % cost
	%ContinueButton.icon = Icons.COIN
	%ContinueButton.disabled = not affordable
	# One primary action: the continue when the player can afford it, else Retry.
	%ContinueButton.theme_type_variation = &"AccentButton" if affordable else &"Button"
	%RetryButton.theme_type_variation = &"Button" if affordable and cost > 0 else &"AccentButton"
