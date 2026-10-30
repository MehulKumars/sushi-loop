class_name SushiBoosters
extends RefCounted
## Boosters the player owns (bought in the shop with coins): undos, hints and continues. The game
## spends an owned one after the level's free one and before coins or a video. Stored as Progress
## counts, so they save with everything else. Packs and prices are the shop's offers.

const UNDO: StringName = &"undo"
const HINT: StringName = &"hint"
const CONTINUE: StringName = &"continue"
## {kind, amount, price, name} per shop offer.
const OFFERS: Array[Dictionary] = [
	{"kind": UNDO, "amount": 3, "price": 75, "name": "3 undos"},
	{"kind": HINT, "amount": 3, "price": 75, "name": "3 hints"},
	{"kind": CONTINUE, "amount": 2, "price": 90, "name": "2 continues"},
]


static func owned(kind: StringName) -> int:
	return Progress.count("booster_" + String(kind))


## Spends one owned booster of `kind`; false if none is left.
static func use(kind: StringName) -> bool:
	var left := owned(kind)
	if left <= 0:
		return false
	Progress.set_count("booster_" + String(kind), left - 1)
	return true


static func add(kind: StringName, amount: int) -> void:
	Progress.set_count("booster_" + String(kind), owned(kind) + amount)


## Buys `offer` (one of OFFERS) with coins; false if the player cannot afford it.
static func buy(offer: Dictionary) -> bool:
	if not Progress.spend_coins(int(offer.price)):
		return false
	add(offer.kind, int(offer.amount))
	return true
