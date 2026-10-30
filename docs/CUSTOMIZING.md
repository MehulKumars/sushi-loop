# Customizing the template for a new game

What to change for every game, what you can change if the game needs it, and what to leave alone.

## Must change for every game

| What | Where | Notes |
|---|---|---|
| Game name | `project.godot` > `config/name` | Shown on the splash and on home (under the restaurant's noren curtain) |
| Style | Project Settings > GUI > Theme > Custom | This game's is `sushi` (`core/ui/themes/sushi.tres`, the only style). A new one is made in `core/ui/styles/` and built by `tools/build_theme.gd` ([UI_KIT.md](UI_KIT.md)) |
| Package name | `export_presets.cfg` > `package/unique_name` (both presets) | For example `com.yourstudio.halves`. Never ship `com.changeme.template`; it can never change after the first upload |
| App name on the phone | `export_presets.cfg` > `package/name` | |
| Version | `version/code` (raise for every upload) and `version/name` in both presets; `config/version` in `project.godot` (shown in Settings) | |
| App icon | `assets/icon/` | Sushi Loop's icons are drawn by `tools/make_icon.gd` (needs a window); both export presets point at them. Keep important artwork inside the centred 264 px circle of the 432 px adaptive foreground |
| Splash | `ui/screens/splash.tscn` | Shows the app icon's plate, the game name and "Made with Godot" for 0.6 s, then level 1 (a player with no win yet) or home. Add your studio logo to `%Logo` if you have one |
| Credits | `ATTRIBUTION.md` | Replace "Your Studio" and "Your Name" with your team; keep the "Made with", font and icon entries. The licence texts are added below automatically |
| Privacy policy | `ui/popups/settings_popup.gd` > `PRIVACY_URL` | Google Play requires one; a GitHub Pages page works |
| Release keystore | outside the repo | Never commit it; Godot reads its path, user and password from the `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables |
| Licence register | `ASSETS_LICENSES.md` | One row per asset you add |

## The game screen

`ui/screens/game.tscn` holds the Sushi Loop board (`%SushiBoard`, from `game/sushi/`) and its HUD:

- When a level ends, the screen calls `finish(won, stars)`. It records progress and coins, opens
  the results popup, considers an interstitial through `AdPolicy`, and handles Next (straight into
  the next level) / Retry / Home / Continue.
- `%Goal` and `%MovesLabel` show the bentos packed out of the level's total.
- `%UndoButton` and `%HintButton` are the boosters: the level's free use first, then one the
  player owns (`SushiBoosters`, bought in the shop), then coins (`UNDO_COST`, `HINT_COST`), or a
  rewarded video when the player is short of coins. Their badges count free and owned uses
  together (the price when none is left). The doom card's Step back costs an undo the same way.
- `Screens.level` is the level to play; `Progress.LEVEL_COUNT_DEFAULT` (1000) is the number of
  levels. Sushi Loop's levels and chapters are described in [SUSHI_LOOP.md](SUSHI_LOOP.md#levels),
  home, Levels and How to play in its Progression section.
- Back opens the pause popup. Save on `Events.app_paused` if your game holds state that
  `Progress` does not.

## Rewards

| What | Where |
|---|---|
| Coins per star | `ui/screens/game.gd` > `COINS_PER_STAR` (more on hard and super-hard levels: `ROLE_BONUS`) |
| Booster and continue prices | `ui/screens/game.gd` > `UNDO_COST`, `HINT_COST`, `CONTINUE_COST` |
| Shop packs | `game/sushi/sushi_boosters.gd` > `OFFERS` (kind, amount, price, name) |
| Shop video | `ui/popups/shop_popup.gd` > `VIDEO_COINS`, `VIDEO_GAP_SECONDS` |
| Daily streak coins | `core/progress.gd` > `DAILY_REWARDS` (days 1-7; `core/`, so change it on purpose) |

Sushi Loop has no real-money purchases (the economy is in [SUSHI_LOOP.md](SUSHI_LOOP.md)). The
shop sells booster packs for coins; `SushiBoosters` keeps the boosters a player owns as `Progress`
counts (`booster_undo`, `booster_hint`, `booster_continue`), and the game spends one after the
level's free one and before coins or a video. The first win of each day claims the template's
daily streak (`Progress.claim_daily()`) and shows a reward card. `Progress`'s owned items
(`owns()`) are unused by this game.

Remove screens you do not need by deleting the scene, its button and its entry in `ui/screens.gd`,
`tests/test_screens.gd` and `tools/snapshots.gd`.

## Look and feel

| What | Where | How |
|---|---|---|
| Colours, fonts, corners, button shape, background pattern | `core/ui/styles/<style>.tres` | Edit in the Inspector, run `tools/build_theme.gd`, check with `tools/check.ps1` and `tools/snapshots.ps1` |
| How a component looks in every style | `tools/build_theme.gd` | The design system; rebuild after changes (Sushi Loop has one style, `sushi`) |
| Icons | `core/ui/icons/`, `core/ui/icons.gd` | Material Symbols; how to add one is in `icons.gd` |
| Palette for game pieces | per game | Text contrast at least 4.5:1 and game pieces at least 3:1 against their background; pair every meaningful colour with a shape or pattern; check in greyscale and a colour-blind simulator. Reuse the style's Tokens where you can |
| Juice | your gameplay code | Pick the register for the game type (calm, crescendo-only, physical, loud-but-readable). Sushi Loop's is in [SUSHI_LOOP.md](SUSHI_LOOP.md) (Feel) |
| Music and sounds | the `Sound` autoload (`core/audio/sound.gd`); Sushi Loop calls it through `SushiSfx` | `Sound.play(id)` for effects in `assets/audio/sfx/`, `Sound.play_playlist(paths)` for music. Buses are Master, Music, SFX (`default_bus_layout.tres`); the Settings sliders control Music and SFX. WAV for short effects, Ogg for music |

## Settings

`ui/popups/settings_popup.tscn` has Music and Sound volume, Vibration, Reduce motion, Credits,
Privacy, Reset progress and the version. To add a setting, add a row (icon, label, control) and a
getter and setter in `core/settings.gd`, which keeps every setting in its own ConfigFile,
`user://settings.cfg` (sections `audio` and `feel`). There is no style picker: the game has one
style.

## Ad rules

`AdPolicy`'s defaults follow the research. Tune them on the shared instance in `game.gd`:

```gdscript
ad_policy.min_level = 6            # first interstitial after level 6 instead of 8
ad_policy.won_levels_between = 3   # gentler
ad_policy.max_per_session = 2
```

Do not change the rules Google Play and the research treat as hard: no interstitials at level
start, during play, on Retry / Next / Play again, or in the first session.

## Screen and orientation

The canvas is 720 px wide, portrait, with `canvas_items` stretch and `expand` aspect: taller phones
show more vertically (up to about 1700 px), tablets and foldables get a wider canvas (about
960-1100 px). Every screen keeps its content in a `MaxWidthContainer` and its grids adaptive, and
`tests/test_screens.gd` checks three sizes. The PC window is 405×720 (the snapshot and playtest
tools size their own window through `tools/test_window.gd`). Landscape would need every screen
rearranged; it is not supported.

## Change only on purpose

- `core/`: shared by every game. Improve it in the **template** repo, then copy the change into
  games that need it. Ask before changing it in a game.
- `CLAUDE.md` rules: they encode the research; change them deliberately, not to make a task easier.
- `addons/`: never edit vendored plugins; update them as a whole to a pinned version.
- `export_presets.cfg` filters: tests, tools and editor-only addons must stay out of builds; the
  baked levels in `data/` and the font, icon and emoji licence files must stay in.
