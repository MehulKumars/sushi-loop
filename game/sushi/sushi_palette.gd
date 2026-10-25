class_name SushiPalette
extends RefCounted
## Sushi Loop colours (docs/SUSHI_LOOP.md "Palette") and how each plate type is told apart: the
## silhouette first, then the rim colour and the rim pattern, so colour is never the only signal.

const CREAM := Color("F6EFE3")
const INK := Color("23283B")
const VERMILLION := Color("B8461A")
const BLUE := Color("1F64A8")
const GOLD := Color("E8B04B")

## Food and furniture tints (art placeholders until the hand-drawn silhouettes arrive).
const RICE := Color("FFFDF7")
const SALMON := Color("E8875C")
const EGG := Color("F2C14E")
const LEAF := Color("6F9447")
const PINK := Color("E7A3A6")
const STICK := Color("B68A5A")
const WOOD := Color("E7D7BC")
const WOOD_EDGE := Color("C9AE86")
const LACQUER := Color("2A2230")
const LACQUER_RED := Color("8E2F1C")

enum Rim { SOLID, DASHED, DOUBLE }

const NAMES: Array[String] = ["maki", "nigiri", "onigiri", "gunkan", "tamago", "dango", "temaki"]
const RIM_COLORS: Array[Color] = [VERMILLION, BLUE, INK]


static func rim_color(type: int) -> Color:
	return RIM_COLORS[type % RIM_COLORS.size()]


## Vermillion rims are solid, blue ones dashed, ink ones double (the pattern tracks the colour, so
## the two never disagree).
static func rim_style(type: int) -> Rim:
	return [Rim.SOLID, Rim.DASHED, Rim.DOUBLE][type % RIM_COLORS.size()]


static func type_name(type: int) -> String:
	return NAMES[type] if type >= 0 and type < NAMES.size() else "?"
