# Sushi Loop: rules for Claude Code

Sushi Loop is game 2 of the studio plan, started from our mobile game template on 2026-10-25. Rules, API and the
level pipeline are the contract in `docs/SUSHI_LOOP.md`: change the rules there first. v1 is free like Halves (no shop,
daily reward, ranks or purchases; coins pay for boosters). Template core changes made for this game: the `sushi` style
as the project theme, autoload **Sound** (`core/audio/sound.gd`, from Halves), `Progress.LEVEL_COUNT_DEFAULT` = 30.

Godot **4.7.2** (pinned) · GDScript only · 2D portrait, 720 px wide canvas · Android first · Compatibility renderer.
The human owns fun, feel, art, balance, the store page and release decisions. Claude builds code with a checkable answer.

## Project map
- `core/` shared template systems. Change only on purpose and ask first.
  - `events.gd` autoload **Events**: global signal bus (incl. `app_paused`, `app_resumed`, `back_requested`).
  - `services/` autoload **Services**: `ads`, `iap`, `analytics`, `leaderboard`, `review` as interfaces with mocks.
  - `app_lifecycle.gd` autoload **AppLifecycle**: Android pause/resume/Back -> Events; applies Reduce Motion and Haptics.
  - `ad_policy.gd` (when interstitials may show), `seed_service.gd` (stable seeds), `save_store.gd` (versioned JSON save),
    `progress.gd` (stars, unlocks, coins, purchases, daily streak), `settings.gd` (volume, vibration, reduce motion).
  - `feel/`: `Juice` (pop, squash; honours `Juice.motion_scale`), `Haptics` (honours `Haptics.enabled`), `hit_flash.gdshader`.
  - `ui/` the UI kit core: autoload **UI** (`ui.gd`: goto, open, confirm, toast, apply_style, button feel, focus rings),
    `screen.gd` (base for screens), `modal.gd` (base for popups), `styled_background.gd`, `safe_area_margin.gd`,
    `max_width_container.gd`, `adaptive_grid_container.gd`, `touch_scroll_container.gd`, `widgets/` (StarRating, CurrencyPill, LevelTile), `icons.gd`,
    `styles/*.tres` (5 UIStyle resources), `themes/*.tres` (built from styles; never edit by hand), `fonts/`, `icons/`.
  - `dev_tools.gd` autoload **DevTools**: debug-only console commands (`fps`, `log_input`, `display_info`, `safe_area`...).
- `ui/` the game's screens (`ui/screens/`) and popups (`ui/popups/`); paths in `ui/screens.gd` (`Screens.*`). Edit per game.
  `ui/screens/game.gd` hosts the gameplay: replace its %Board and call `finish(won, stars)`.
- `scenes/loading_screens/`: Maaack's loading screen, for SceneLoader (heavy scenes only). `assets/template_icon/`: placeholder app icon.
- `game/` gameplay scenes and scripts (create per game). `data/` baked levels and configs (create per game).
  This repo: `game/sushi/` (SushiState rules, SushiSolver, SushiBot, SushiRun, SushiDoom, the board and art views),
  `game/kit/` (StateSolver, SolverState, Rack, PathBelt: generic, meant for the template later),
  `data/levels/sushi_v1.json` (baked by `tools/levelgen/generate_sushi.gd` from `sushi_plan.json`),
  `tools/sushi_playtest.gd`, `tools/audio/synth_sushi_sfx.gd`. Sound cues go through `SushiSfx` (run-time lookup).
- `tests/` GUT tests named `test_*.gd`. `tools/` scripts and the hook. `addons/` vendored plugins.
- `.claude/skills/`: mobile-ui, game-design-review, godot-game-feel, level-generation, mobile-performance-audit,
  play-release. Use them for those tasks.
- `docs/`: human guides. `docs/UI_KIT.md` and `docs/ARCHITECTURE.md` describe every module; keep them in sync.

## Never
- Godot 3 APIs. Use the right column:
  | Godot 3 (wrong) | Godot 4 (right) |
  |---|---|
  | `yield(...)` | `await ...` |
  | `KinematicBody2D`, `move_and_slide(vel, UP)` | `CharacterBody2D`, set `velocity`, `move_and_slide()` |
  | `deg2rad`, `rad2deg`, `rand_range` | `deg_to_rad`, `rad_to_deg`, `randf_range` / `randi_range` |
  | `export var`, `onready var`, `.instance()` | `@export var`, `@onready var`, `.instantiate()` |
  | `connect("sig", self, "fn")` | `sig.connect(fn)` |
  | `File.new()`, `Directory.new()` | `FileAccess.open()`, `DirAccess.open()` |
  | `set_shader_param` | `set_shader_parameter` |
  | `BUTTON_LEFT` (fails silently) | `MOUSE_BUTTON_LEFT` |
  | `TileMap` | `TileMapLayer` |
- Call a plugin singleton (AdMob, Billing, Play Games) outside `core/services/`.
- Show an interstitial anywhere except when a results screen opens, and only if `AdPolicy.can_show_interstitial()` is true.
  Never on Next / Retry / Play again, at level start, during play, after a fail with a continue offer, or in daily/zen modes.
- Generate shipped levels at runtime. Generate offline, rate with a bot, bake to `data/` with a `gen_version`.
- Hand-write `uid://` values or restructure existing `.tscn` files as text. Change properties or remove nodes with
  `tools/scene_edit.gd` (Godot writes the file); adding or moving nodes happens in the editor, in code, or in a
  one-off `-s` script that instantiates, changes, packs and saves the scene.
- Edit anything in `addons/`, or the generated `core/ui/themes/*.tres` (edit `core/ui/styles/` and run the builder).
- Hard-code colours, fonts or sizes in screens. Use theme type variations and `Tokens` (see `docs/UI_KIT.md`).
- Name a static function `reload`, `free` or another built-in Object/Script method: `Class.reload()` calls the built-in.
- Create child nodes in member initialisers and add them in `_ready` (they leak if the node never enters the tree);
  add them in `_init` instead.
- Emit a service result (ads, purchases) inside the call: callers call, then `await` the signal.
- Commit keystores, passwords or `build/` outputs.
- Weaken, skip or delete a test to make it pass.
- Add AI-generated art, audio or text content.

## Always
- Static typing everywhere: `var speed: float = 2.0`, `func f(a: String) -> void:`, `:=` when the type is obvious.
  `class_name` on reusable scripts. Untyped declarations raise a warning (project setting).
- "Call down, signal up": parents call children, children emit signals, cross-system events go through `Events`.
- New script = a 3-line header comment: what it does, who uses it, anything surprising.
- Tweens: `create_tween()` each time; kill an old tween on the same property first (see `Juice`).
- Screens extend `Screen` (Back via `on_back()`), popups extend `Modal` (open with `UI.open()`, `await .closed`).
  Every screen: StyledBackground + SafeAreaMargin + MaxWidthContainer. One primary (accent) action per screen.
  Scrolling lists use `TouchScrollContainer`, never a plain ScrollContainer (on phones it would not scroll
  when the drag starts on a button or text).
- Touch targets at least 96 px on the 720-px canvas (48 dp). Primary actions in the bottom third.
- After any UI change: run `tools/snapshots.ps1` for the affected screens and **look at the PNGs** before saying it works.
- Every important event has a visual. Sound and haptics are extras, never the only signal.
- Juice goes on player success. Calm games stay calm. Respect `Juice.motion_scale` and `Haptics.enabled`.
- Never time gameplay to audio: Android audio lags 165–500 ms on some phones.
- Performance: no full-screen translucent layers in gameplay, no Light2D or HDR glow by default, pooled one-shot
  `CPUParticles2D`, sprite atlases, no per-enemy physics nodes for swarms, Lossless textures without mipmaps.
- Save progress on `Events.app_paused` (Progress saves on every change already).
- Work in small steps: plan first, one feature at a time, run the done check, then commit.

## Ask the human first
- A new autoload or addon, any change in `core/`, project settings, export presets, signing, package names.

## Automatic check (hook)
After every Edit/Write of a `.gd` file, `.claude/settings.json` runs `tools/hooks/gd_check.ps1`, which compiles the
file inside the project (`tools/hooks/check_script.gd`). If it reports errors, fix them before doing anything else.

## Done = this passes
```
powershell -ExecutionPolicy Bypass -File tools/check.ps1
```
It runs a warm-up import, boots the game headless for 300 frames, and runs every GUT test (incl. contrast and
touch-size checks of every style, and every screen at three sizes).
Test cases for generators and solvers are written by the human or a separate session, not the one writing the code.
(The first Sushi tests were written test-first from `docs/SUSHI_LOOP.md` by the session that built the code, on
levels worked by hand in `tests/sushi_helpers.gd`; a second session or the human should still review them.)

## Commands
- Run the game: `godot --path .`  · Editor: `godot --path . -e`
- Tests only: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit` (one file: `-gselect=test_ui`)
- Check one script: `godot --headless --path . -s tools/hooks/check_script.gd -- res://core/events.gd`
- Screenshots of the UI: `powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 [-Styles all] [-Sizes 720x1600] [-Only main_menu,pause] [-Inset 0,64,0,32]`
  -> `build/snapshots/<style>_<w>x<h>_<screen>.png` and `..._contact.png`
- Rebuild themes after editing a style: `godot --headless --path . -s tools/build_theme.gd`
- Set scene properties: `godot --headless --path . -s tools/scene_edit.gd -- res://ui/screens/credits.tscn Safe extra_margin 24`
- Remove scene nodes: `godot --headless --path . -s tools/scene_edit.gd -- --remove res://ui/popups/x.tscn Path/To/Node`
  (string values from PowerShell 5.1 lose their quotes: run those edits from Bash as `'"Text"'`)
- Bake levels: `godot --headless --path . -s tools/levelgen/generate_sushi.gd [-- first last]` (about 2 min for 30);
  knob study: `tools/levelgen/bench_sushi.gd`. Ratings land in `tools/levelgen/reports/sushi_v1.csv`.
- Play a level for real (needs a window): `godot --path . -s tools/sushi_playtest.gd -- <level> solve|doom|lose [still]`
  -> frames in `build/playtest/<mode>_<level>/`
- A new `class_name` fails the hook ("not declared") until `godot --headless --path . --import` refreshes the cache.
- Debug APK: `godot --headless --path . --export-debug "Android Debug APK" build/game-debug.apk`
- Phone: `adb install -r build/game-debug.apk`, `adb exec-out screencap -p > shot.png`, Back = `adb shell input keyevent 4`,
  console = `adb shell input keyevent 68` then `adb shell input text fps` + `adb shell input keyevent 66`, logs `adb logcat -s godot`.
- Release AAB: see the play-release skill (needs the game's release keystore).
- Version-exact API reference to search: `godot --doctool docs/api` (ignored by git)

## Google Play rules this template assumes (Oct 2026)
- Target API 36 (Godot 4.7.2 default), AAB uploads, 16 KB page support (Godot 4.5+).
- Rewarded ads are opt-in; full-screen ads never at level start or during play.
- Audience 13+ with adult-looking art, to stay out of the Families policy.
- Billing plugin 3.3.0+ when IAP is added (Billing Library 8+ required).
