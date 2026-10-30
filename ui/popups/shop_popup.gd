extends Modal
## The booster shop: packs of undos, hints and continues for coins (SushiBoosters.OFFERS), how many
## of each the player owns, and free coins for a short opt-in video. No real-money purchases.
## Opened from home; closes with the Close button or Back.

## Coins a shop video gives, and the least time between two of them.
const VIDEO_COINS: int = 30
const VIDEO_GAP_SECONDS: float = 300.0
## The game screen keeps the ad pacing (AdPolicy): a shop video counts for its interstitial gap.
const GameScreen := preload("res://ui/screens/game.gd")

static var _last_video: float = -VIDEO_GAP_SECONDS

var _owned: Dictionary[StringName, Label] = {}
var _buttons: Array[Button] = []
var _video: Button
var _coins: Label


func _ready() -> void:
	super._ready()
	%CloseButton.pressed.connect(close)
	_coins = Label.new()
	_coins.theme_type_variation = &"ValueLabel"
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Offers.add_child(_coins)
	for offer in SushiBoosters.OFFERS:
		%Offers.add_child(_offer_row(offer))
	_video = Button.new()
	_video.icon = Icons.PLAY
	_video.text = "Watch a video  ·  +%d coins" % VIDEO_COINS
	_video.pressed.connect(_watch)
	%Offers.add_child(_video)
	_refresh()
	refit()


func _offer_row(offer: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var name := Label.new()
	name.theme_type_variation = &"ValueLabel"
	name.text = offer.name
	words.add_child(name)
	var owned := Label.new()
	owned.theme_type_variation = &"CaptionLabel"
	words.add_child(owned)
	_owned[offer.kind] = owned
	var buy := Button.new()
	buy.theme_type_variation = &"AccentButton"
	buy.icon = Icons.COIN
	buy.text = str(offer.price)
	buy.custom_minimum_size.x = 170.0
	buy.set_meta(&"price", int(offer.price))
	buy.pressed.connect(_buy.bind(offer))
	row.add_child(buy)
	_buttons.append(buy)
	return row


func _buy(offer: Dictionary) -> void:
	if not SushiBoosters.buy(offer):
		UI.toast("Not enough coins yet", Icons.COIN)
		return
	SushiSfx.play(&"coin")
	UI.toast("+%s" % offer.name, Icons.CHECK)
	_refresh()


func _watch() -> void:
	if not Services.ads.is_rewarded_ready("shop_coins"):
		UI.toast("No video right now. Try again later.", Icons.INFO)
		return
	Services.ads.show_rewarded("shop_coins")
	if Services.ads is MockAdsService:
		UI.toast("Test build: a real video would play here", Icons.VIDEO, 1.5)
	var result: Array = await Services.ads.rewarded_finished
	GameScreen.ad_policy.record_rewarded_shown(Time.get_ticks_msec() / 1000.0)
	if result.size() > 1 and bool(result[1]):
		_last_video = Time.get_ticks_msec() / 1000.0
		Progress.add_coins(VIDEO_COINS)
		SushiSfx.play(&"coin")
	_refresh()


func _refresh() -> void:
	_coins.text = "Your coins: %d" % Progress.coins()
	for kind: StringName in _owned:
		_owned[kind].text = "You have %d" % SushiBoosters.owned(kind)
	for button in _buttons:
		button.disabled = Progress.coins() < int(button.get_meta(&"price"))
	var wait := VIDEO_GAP_SECONDS - (Time.get_ticks_msec() / 1000.0 - _last_video)
	_video.disabled = wait > 0.0
	_video.visible = Services.ads.is_rewarded_ready("shop_coins") or _video.disabled
