extends Screen
## How to play: the rules in short illustrated cards (SushiIllustration), the three special plates
## and orders with the chapter that brings each, the boosters, and a button that replays the
## guided first level. Reached from home; Back goes home.

## title, text, picture; "from" = the chapter that brings it (0 = from the start).
const SECTIONS: Array[Dictionary] = [
	{"title": "Take a plate", "picture": &"window", "from": 0,
		"text": "Plates ride the belt round the counter. Tap one in the gold window at the bottom to take it. Every take moves the belt one step."},
	{"title": "Pack the bentos", "picture": &"bento", "from": 0,
		"text": "A plate flies into an open bento that wants its dish. Three of a kind close the bento, and the next one in the queue opens."},
	{"title": "Mind the counter", "picture": &"counter", "from": 0,
		"text": "A plate no open bento wants waits on the counter. When a bento opens, matching plates hop in. If the counter is full and a plate has nowhere to go, the level is lost."},
	{"title": "Plan the order", "picture": &"loop", "from": 0,
		"text": "A plate you leave comes back a lap later. Look at the next bentos and the belt: take what you will need soon and let the rest ride. Tapping the same spot every time will not get you far."},
	{"title": "Covered dishes", "picture": &"covered", "from": 3,
		"text": "Some plates arrive under a silver cloche. You only see the dish once it reaches the window, so keep a slot free for surprises."},
	{"title": "Rush orders", "picture": &"rush", "from": 5,
		"text": "A rush bento shows a number: pack it within that many takes or the customer leaves. Feed it first, and bank other plates on the counter meanwhile."},
	{"title": "Chef's special", "picture": &"special", "from": 7,
		"text": "The gold plate fits any bento: it goes into the fullest open one and stands in for one dish. Take it when the right bento is fullest, or a plate is left with nowhere to go."},
	{"title": "Stars and boosters", "picture": &"stars", "from": 0,
		"text": "Three stars for a win without a continue that keeps the counter at the gold marks. Each level has a free undo and a free hint; more come from coins, the shop or a short video. When a move can no longer win, Step back costs an undo; Retry is always free."},
]


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	var reached := SushiLevels.chapter(Progress.next_level(SushiLevels.count()))
	for section in SECTIONS:
		%List.add_child(_card(section, reached))
	var practice := Button.new()
	practice.theme_type_variation = &"AccentButton"
	practice.text = "Play the guided level"
	practice.icon = Icons.PLAY
	practice.pressed.connect(_practice)
	%List.add_child(practice)


func _card(section: Dictionary, reached: int) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"TilePanel"
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	card.add_child(row)
	var picture := SushiIllustration.new()
	picture.kind = section.picture
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = section.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	var from: int = section.from
	if from > reached:
		var soon := Label.new()
		soon.theme_type_variation = &"CaptionLabel"
		soon.text = "Arrives in chapter %d" % from
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(soon)
	var text := Label.new()
	text.text = section.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(text)
	return card


## Level 1 again, with its guide (the plate to take glows).
func _practice() -> void:
	Screens.level = 1
	UI.goto(Screens.GAME)
