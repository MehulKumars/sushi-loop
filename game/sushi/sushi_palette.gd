class_name SushiPalette
extends RefCounted
## Sushi Loop colours (docs/SUSHI_LOOP.md "Palette") and how each plate type is told apart: the
## dish itself first, then the rim colour and the rim pattern. Every type has its own colour and
## pattern pair, so colour is never the only signal. Also the look of each chapter's restaurant
## (belt, wood, curtain), so moving on to a new chapter shows on screen.

const CREAM := Color("F6EFE3")
const INK := Color("23283B")
const VERMILLION := Color("B8461A")
const BLUE := Color("1F64A8")
const GOLD := Color("E8B04B")

const PORCELAIN := Color("FFFBF3")
const PORCELAIN_SHADE := Color("E6DCCB")
const RICE := Color("FFFDF7")
const PETAL := Color("F6B3C2")
const LACQUER := Color("2A2230")
const LACQUER_RED := Color("8E2F1C")

enum Rim { SOLID, DASHED, DOUBLE }

## Dish names, by plate type (the art is in SushiArt.FOOD, same order).
const NAMES: Array[String] = ["Salmon nigiri", "Onigiri", "Dango", "Ebi fry", "Naruto", "Purin", "Ika"]
## One line each for the "new on the menu" card.
const BLURBS: Array[String] = [
	"Salmon and tuna on hand-pressed rice.",
	"A rice ball wrapped in crisp nori.",
	"Three sweet rice dumplings on a stick.",
	"A golden fried prawn, tail and all.",
	"A fish cake with a pink swirl.",
	"A wobbly caramel custard for dessert.",
	"Tender squid, the chef's favourite.",
]
const RIM_COLORS: Array[Color] = [
	Color("1F64A8"), Color("B8461A"), Color("23283B"), Color("4F8A3A"), Color("7A5BA6"), Color("2E8B8B"), Color("C98A1B"),
]
const RIM_STYLES: Array[Rim] = [Rim.SOLID, Rim.DASHED, Rim.DOUBLE, Rim.SOLID, Rim.DASHED, Rim.DOUBLE, Rim.SOLID]

## Each chapter's restaurant: name, belt band, steel rail, counter wood, its grain, the noren
## curtain on the home screen. Chapters cycle through them; a return visit gets a numeral.
const SHOPS: Array[Dictionary] = [
	{"name": "Corner Stall", "belt": Color("262B40"), "rail": Color("C7CED8"), "wood": Color("E9D9BD"), "grain": Color("CDB28A"), "noren": Color("1F3F6B")},
	{"name": "Harbour Bar", "belt": Color("1C3A45"), "rail": Color("BFD3D6"), "wood": Color("EEE2CC"), "grain": Color("CFBB98"), "noren": Color("24676B")},
	{"name": "Lantern Alley", "belt": Color("3A2433"), "rail": Color("D8C7BF"), "wood": Color("E3C9A6"), "grain": Color("C09A6C"), "noren": Color("9E3A1E")},
	{"name": "Tea Garden", "belt": Color("24382B"), "rail": Color("C9D4C2"), "wood": Color("E8DDB6"), "grain": Color("C7B585"), "noren": Color("4F7A3A")},
	{"name": "Snow Lodge", "belt": Color("2B3442"), "rail": Color("D5DCE6"), "wood": Color("F0E8DC"), "grain": Color("D0BFA6"), "noren": Color("51657E")},
	{"name": "Golden Counter", "belt": Color("1E1B1F"), "rail": Color("E1C98F"), "wood": Color("EBD3A6"), "grain": Color("C7A26A"), "noren": Color("8C5F12")},
	{"name": "Night Market", "belt": Color("2A2440"), "rail": Color("CFC6E0"), "wood": Color("E6D7C3"), "grain": Color("C4AE8E"), "noren": Color("5B3E8C")},
	{"name": "Cherry Terrace", "belt": Color("3B2530"), "rail": Color("E3C6CF"), "wood": Color("F0DFD0"), "grain": Color("D1B39A"), "noren": Color("A8405F")},
	{"name": "Station Kiosk", "belt": Color("263238"), "rail": Color("C9D1D4"), "wood": Color("E4DCCB"), "grain": Color("C2B497"), "noren": Color("3D6E8F")},
	{"name": "Maple Inn", "belt": Color("3A2A22"), "rail": Color("DCC7B0"), "wood": Color("EAD2B0"), "grain": Color("C9A276"), "noren": Color("A0501C")},
	{"name": "Bamboo Grove", "belt": Color("213528"), "rail": Color("C4D6C0"), "wood": Color("E9E3C4"), "grain": Color("C9BE8C"), "noren": Color("4E7A30")},
	{"name": "Rooftop Counter", "belt": Color("1E2433"), "rail": Color("D4D9E3"), "wood": Color("EFE6D8"), "grain": Color("CDBFA8"), "noren": Color("A8741A")},
]
const NUMERALS: Array[String] = ["", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]


## The chef's special (M3) wears a gold rim; covered plates a plain silver one.
const SPECIAL_RIM := Color("D9A43A")
const COVER_RIM := Color("A9AFB9")


static func rim_color(type: int) -> Color:
	if type == SushiLevel.WILD:
		return SPECIAL_RIM
	return RIM_COLORS[posmod(type, RIM_COLORS.size())]


static func rim_style(type: int) -> Rim:
	if type == SushiLevel.WILD:
		return Rim.DOUBLE
	return RIM_STYLES[posmod(type, RIM_STYLES.size())]


static func type_name(type: int) -> String:
	if type == SushiLevel.WILD:
		return "Chef's special"
	return NAMES[type] if type >= 0 and type < NAMES.size() else "?"


## The restaurant of 1-based `chapter`: its colours, its name ("Corner Stall II" on the second
## visit) and its twist line (SushiChapters).
static func shop(chapter: int) -> Dictionary:
	chapter = maxi(chapter, 1)
	var out: Dictionary = SHOPS[(chapter - 1) % SHOPS.size()].duplicate()
	var visit := (chapter - 1) / SHOPS.size()
	if visit > 0:
		out.name = "%s %s" % [out.name, NUMERALS[mini(visit, NUMERALS.size() - 1)]]
	out.twist = SushiChapters.text(chapter)
	return out
