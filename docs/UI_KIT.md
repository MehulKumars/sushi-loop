# UI kit

Sushi Loop's screens and popups share **one visual style, `sushi`**. Every screen is built once
from theme types and tokens, so a change to the style restyles all of them. Layouts adapt to every
phone shape, foldables and tablets (portrait).

## Screens and popups

| | File | What it does |
|---|---|---|
| Splash | `ui/screens/splash.tscn` | The app icon's plate and the game's name for 0.6 s after Android's launch screen (tap to skip). A player who has not won a level yet goes straight into level 1; everyone else goes home |
| Home | `ui/screens/main_menu.tscn` | The game's mark (`SushiLogo`) and name under the current restaurant's noren curtain (`SushiNoren`). A card for the restaurant (name, twist, stars, levels won); a tap opens its levels. One big Play button, "Level N" ("Level N · Hard" or "· Super hard" on those levels), in the thumb zone, then a row of three: Levels, How to play, Shop. Top bar: coins, the daily streak (a tea picture whose badge shows the days in a row; a tap explains it), the chef's gift (its badge counts the stars toward the next gift, "!" when one waits), settings. Back asks before quitting |
| Levels | `ui/screens/levels.tscn` | Every chapter as a row (restaurant colour, name, twist, stars, or a lock). One row is open at a time and shows its ten levels as `LevelTile`s: won ones with their stars, the next one in the accent colour, later ones locked; a won level replays on a tap. It opens the next level's chapter, or the one in `levels.gd`'s static `open_chapter` (home's restaurant card sets it). Back goes home |
| How to play | `ui/screens/how_to_play.tscn` | Illustrated cards (`SushiIllustration`, drawn with the game's own art): taking a plate, packing bentos, the counter, planning the order, covered dishes, rush orders, the chef's special (each marked "Arrives in chapter N" until the player gets there), stars and boosters. "Play the guided level" replays level 1. Back goes home |
| Game | `ui/screens/game.tscn` | One Sushi Loop level (`SushiBoard`) and its HUD: pause, level, coins, bentos packed and the stars on course; Undo and Hint in the bottom corners, their badges counting free and owned uses together; the doom card once the level can no longer be won (Step back costs an undo, Retry, Keep going). Rules, covered dishes, rush orders and the chef's special in [SUSHI_LOOP.md](SUSHI_LOOP.md) |
| Credits | `ui/screens/credits.tscn` | Built from `ATTRIBUTION.md` (the game first, then what it is made with; a small markdown reader turns it into BBCode), followed automatically by the licence notices the shipped code requires. Links are plain text |
| Pause | `ui/popups/pause_popup.tscn` | Resume, restart, settings, Home, quick music/sound/vibration toggles. Pauses the game |
| Results | `ui/popups/results_popup.tscn` | Win: stars pop in, coins count up, ×2 coins for a rewarded video, Next level. Lose: "Counter full" (a continue gives two more counter slots) or "Rush order missed" (five more takes for that bento); the continue is paid with one the player owns, a video or coins; Retry, Home. Back does not dismiss it |
| Settings | `ui/popups/settings_popup.tscn` | Music and sound volume, vibration, reduce motion, credits, privacy policy, reset progress, version |
| Shop | `ui/popups/shop_popup.tscn` | Booster packs for coins (`SushiBoosters.OFFERS`: 3 undos, 3 hints, 2 continues) with how many of each the player owns, and 30 coins for an opt-in video at most every 5 minutes (hidden when no video is ready). No real-money purchases. Close or Back closes it |
| Reward | `ui/popups/reward_popup.tscn` | A card for a moment worth it: a new dish on the menu, a star gift, a finished chapter, the welcome to a new chapter, the daily streak |
| Confirm | `ui/popups/confirm_popup.tscn` | Yes/no question, `await UI.confirm(...)` |

The flow: Android launch screen (app icon) → splash → level 1 for a player with no win yet, home
for everyone else → game → results → Next (straight into the next level) / Retry / Home. Home
also leads to Levels, How to play and the shop.
All paths are in `ui/screens.gd` (`Screens.MAIN_MENU`, `Screens.LEVELS`, `Screens.SHOP`, ...).

## The style

| Style | Look | Font |
|---|---|---|
| `sushi` | Cream porcelain, ink lacquer and gold: calm, warm, adult. Chunky buttons, a still paper-grain background | Nunito (black for titles, semi-bold for text) |

It is the project theme (Project Settings > GUI > Theme > Custom → `res://core/ui/themes/sushi.tres`),
so every screen uses it. Only the Nunito font ships (`core/ui/fonts/`). `UI.apply_style(id)` can
still swap the theme at runtime, but nothing is saved and there is no style picker: Sushi Loop has
one look.

## Adding a style (if ever needed)

1. Duplicate `core/ui/styles/sushi.tres` and give it a new `id`. Edit it in the Inspector: colours,
   fonts (any `.ttf` with an open licence; log it in `ASSETS_LICENSES.md`), button shape (Flat,
   Chunky, Outline, Pixel), corner radii, shadow, background pattern.
2. Build the themes: `godot --headless --path . -s tools/build_theme.gd`
3. Check it: `powershell -ExecutionPolicy Bypass -File tools/check.ps1`. `test_theme.gd` fails if any
   text is below WCAG AA contrast or any control is under 48 dp. It and `test_ui.gd` also expect
   `sushi` to be the only style, so a second style means changing those two checks on purpose.
4. Look at it: `powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Styles your_id`
   and open `build/snapshots/your_id_*_contact.png`.
5. To make it the game's look, point Project Settings > GUI > Theme > Custom at its theme.

`tools/build_theme.gd` is the design system: it turns a style's tokens into every button, card,
slider and switch. Edit it to change how all styles draw a component. Hand edits to the generated
files in `core/ui/themes/` are lost on the next build.

## Theme types (use these, not per-node overrides)

Set a control's **Theme Type Variation** in the Inspector (or `theme_type_variation` in code).

| Kind | Types |
|---|---|
| Buttons | `Button` (secondary), `AccentButton` (primary), `HeroButton` (the one big action), `DangerButton`, `GhostButton` (text only), `IconButton` and `AccentIconButton` (square 96 px, icon only), `TileButton` and `AccentTileButton` (grid tiles), `ChipButton` (toggle chips) |
| Labels | `TitleLabel` (logo-size, on the background), `ScreenHeaderLabel` (screen titles on the background), `HeaderLabel` (titles on cards), `OnBgLabel` (body text on the background), `CaptionLabel` (secondary text on cards), `ValueLabel` (numbers), `BadgeLabel` |
| Panels | `PanelContainer` (card), `SheetPanel` (popups), `TilePanel`, `HighlightPanel` (accent border), `PillPanel` (counters), `BadgePanel`, `DotPanel` (notification dot), `ToastPanel`, `BarPanel` (invisible) |
| Controls | `HSlider`, `CheckButton` (switch), `ProgressBar`, scroll bars: styled automatically |

Text on the background and text on cards use different types because the colours differ in light
and dark styles. **Tokens** hold the raw values for code and custom drawing:

```gdscript
var accent := get_theme_color(&"accent", &"Tokens")         # any Control
var gold := UI.get_theme_color_safe(&"gold")                 # from non-Control code
var touch := get_theme_constant(&"touch_target", &"Tokens")  # 96
```
Colours: `bg_top`, `bg_bottom`, `text_on_bg`, `surface`, `surface_border`, `text`, `text_muted`,
`raised`, `text_on_raised`, `accent`, `on_accent`, `gold`, `positive`, `danger`, `scrim`.
Constants: `touch_target`, `hero_height`, `gap`, `screen_margin`, `radius`, `panel_radius`.
Font sizes: `small`, `body`, `header`, `title`. Fonts: `display`, `body`.

## Building blocks

| Piece | File | Use |
|---|---|---|
| `UI` autoload | `core/ui/ui.gd` | `goto(path)` (fade), `open(scene) -> Modal`, `await confirm(title, message, ok, destructive)`, `toast(text, icon)`, `apply_style(id)`, `list_styles()`, `has_modal()`, `close_all()`. Also gives every button a press squash and a haptic tick, and shows focus rings only after keyboard or gamepad input |
| `Screen` | `core/ui/screen.gd` | Base for full screens. Back calls `on_back()`; or set `back_scene` |
| `Modal` | `core/ui/modal.gd` | Base for popups: dimmed backdrop, pop-in, Back and backdrop taps close it when `dismissible`, `pauses_game`, `sheet_max_width`, `await popup.closed` for the result. A `%Scroll` inside the sheet scrolls when the content is taller than the screen |
| `StyledBackground` | `core/ui/styled_background.gd` | Gradient and animated pattern from the style; stops moving with Reduce Motion |
| `SafeAreaMargin` | `core/ui/safe_area_margin.gd` | Keeps content clear of the camera hole and gesture bar |
| `TouchScrollContainer` | `core/ui/touch_scroll_container.gd` | Use for every scrolling list: scrolls when a drag starts on buttons or text too, never presses the button it started on, and flicks keep gliding (Godot's own ScrollContainer only scrolls where nothing takes the press) |
| `MaxWidthContainer` | `core/ui/max_width_container.gd` | Centred column with a maximum width (tablets) |
| `AdaptiveGridContainer` | `core/ui/adaptive_grid_container.gd` | Grid whose column count follows its width |
| `StarRating`, `CurrencyPill`, `LevelTile` | `core/ui/widgets/` | Stars (with `reveal()`), counters (with `set_value()` count-up), level tiles (the Levels screen) |
| `Icons` | `core/ui/icons.gd` | 38 Material Symbols icons, e.g. `Icons.PLAY`, `Icons.COIN` |
| `Progress` | `core/progress.gd` | Stars per level, unlocks, coins, purchases, daily streak, named counts (JSON save) |
| `Settings` | `core/settings.gd` | Volume, vibration, reduce motion (read and save, in `user://settings.cfg`) |
| `Sound` autoload | `core/audio/sound.gd` | Sound effects, a click on every button, music with crossfades (see [ARCHITECTURE.md](ARCHITECTURE.md)) |

## Adding a screen

1. Duplicate `ui/screens/credits.tscn` (and its script) as a starting point. The layout every screen
   uses:
   ```
   YourScreen (Control, full rect, script extends Screen)
   ├── Background   (ColorRect + StyledBackground)
   └── Safe         (SafeAreaMargin, extra_margin 32)
       └── Column   (MaxWidthContainer, max_width 680-960)
           └── Layout (VBoxContainer): header row, content (TouchScrollContainer if it can grow), bottom actions
   ```
   Levels and How to play started this way: a one-off `-s` script instantiated `credits.tscn`,
   changed it, then packed and saved it under the new name (Godot writes the file).
2. Add its path to `ui/screens.gd`, open it with `UI.goto(Screens.YOUR_SCREEN)`.
3. Add it to `PAGES` in `tests/test_screens.gd` and `SCREENS` in `tools/snapshots.gd`.

## Adding a popup

1. Duplicate `ui/popups/confirm_popup.tscn`: root Control with a script that `extends Modal`,
   then `Safe` (SafeAreaMargin) → `Center` (CenterContainer) → `%Sheet` (`SheetPanel`). Set
   `mouse_filter` to Ignore on Safe and Center, so taps on the backdrop reach it. The shop
   started this way, from `confirm_popup.tscn`.
2. Open it and wait for the answer:
   ```gdscript
   var choice: Variant = await UI.open(load(Screens.YOUR_POPUP) as PackedScene).closed
   ```
3. Add it to the tests and snapshots as above.

## Layout rules

- **Canvas:** 720 px wide on phones (2 px = 1 dp on a 360 dp phone); heights run from 1280 (16:9) to
  about 1700 (21:9). Tablets and foldables get a wider canvas (about 960-1100 px), not a taller one.
- **Touch targets:** at least 96 px (48 dp) both ways. The theme makes every button, switch and slider
  that big; `test_screens.gd` checks every screen at three sizes.
- **Thumb zone:** the main action in the bottom third; pause and rare actions at the top.
- **One primary action per screen** (accent or hero colour); everything else secondary.
- **Safe areas:** every screen sits in a `SafeAreaMargin`. Your phone (OnePlus 10R) has a 96 px
  camera hole at the top centre and a 48 px gesture bar (64 and 32 px on the canvas).
- **Wide screens:** content in a `MaxWidthContainer`; grids in an `AdaptiveGridContainer`.
- **Text:** 32 px body (16 dp), 26 px minimum for captions; numbers use `ValueLabel`.
- **Colour:** never the only signal (switches also change knob size; level tiles show their stars
  or a lock, and the next level's tile shows its number without stars; hard levels are named on
  the Play button).

## Back button

Android Back arrives as the `ui_cancel` action (the Back key is mapped in Project Settings > Input
Map, next to Escape and the gamepad button). Order of handling:
1. The top popup closes if it is `dismissible` (the results popup is not; the player must choose).
2. Otherwise the current `Screen.on_back()` runs: credits, Levels and How to play go home, the
   game opens pause, home asks before quitting, the splash skips ahead.

`Events.back_requested` is still emitted for analytics or custom code.

## Feedback and motion

Every button gets a press squash (to 95%) and a 12 ms haptic tick automatically. Reduce Motion
turns the squash, popup pop-ins, logo intro, Play button breathing, star pops, coin count-ups and
background drift off; the haptic tick follows the Vibration setting. Opt a button out with
`button.set_meta(&"ui_feedback", false)`.

## Checking UI changes

| Check | How |
|---|---|
| Contrast and touch sizes of the style | `tests/test_theme.gd` (part of `tools/check.ps1`) |
| Every screen at 3 sizes: size, on-screen, no overlap | `tests/test_screens.gd` |
| Look at it | `tools/snapshots.ps1` writes every screen × size to `build/snapshots/` (`sushi_<w>x<h>_<screen>.png`), plus one contact sheet per size. It renders the full phone canvas in a small window in the middle of the screen (`tools/test_window.gd`). Flags: `-Sizes 720x1600`, `-Only "main_menu,pause"`, `-Inset "0,64,0,32"` (fake notch and gesture bar), `-Styles <id>` |
| On the phone | Console commands `safe_area`, `display_info`, `fps` |

Snapshots use a separate demo save, so your PC progress is untouched.

## Known limits

- No in-game text-size setting yet (word games should add one).
- Screen readers: Godot's Android TalkBack support lands in Godot 4.8.
- Text is not set up for translation (strings are in the scenes and scripts).
