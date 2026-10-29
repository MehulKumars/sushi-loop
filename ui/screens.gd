class_name Screens
extends RefCounted
## Paths of every screen and popup in the UI kit, so code never repeats them.
## Screens change with UI.goto(Screens.LEVEL_SELECT); popups open with UI.open(load(Screens.PAUSE)).
## Sushi Loop has no shop, daily reward or ranks (see docs/SUSHI_LOOP.md).

const SPLASH: String = "res://ui/screens/splash.tscn"
const MAIN_MENU: String = "res://ui/screens/main_menu.tscn"
const LEVEL_SELECT: String = "res://ui/screens/level_select.tscn"
const GAME: String = "res://ui/screens/game.tscn"
const CREDITS: String = "res://ui/screens/credits.tscn"

const PAUSE: String = "res://ui/popups/pause_popup.tscn"
const RESULTS: String = "res://ui/popups/results_popup.tscn"
const SETTINGS: String = "res://ui/popups/settings_popup.tscn"
const CONFIRM: String = "res://ui/popups/confirm_popup.tscn"
## New dish on the menu, a star gift, a chapter finished.
const REWARD: String = "res://ui/popups/reward_popup.tscn"

## Level the game screen plays next. Set it before UI.goto(Screens.GAME).
static var level: int = 1
