# Sushi Loop

Plates circle a sushi counter one step every time you take one. Pack each bento with three of a
kind before your counter space runs out.

The second game of the studio plan (Halves → **Sushi Loop** → Word Jars): a calm, turn-based sort
puzzle for Android, built in **Godot 4.7.2** from
[godot-mobile-template](https://github.com/MehulKumars/godot-mobile-template).

| | |
|---|---|
| Genre | Sort / organise puzzle, level-based, no timer |
| The twist | The board moves, but only when you act: every take advances the belt one slot, and only the plates in the pick window can be tapped |
| Engine | Godot 4.7.2 stable, GDScript, Compatibility renderer, portrait 720 px canvas |
| Target | Android first, target API 36, AAB for Google Play |
| Rules and design | [docs/SUSHI_LOOP.md](docs/SUSHI_LOOP.md) (the contract the code and tests follow) |

## How to play

1. Plates ride a loop-shaped belt. The gold **pick window** at the bottom shows the plates you can
   take.
2. Tap one. It slides into an open bento of its kind, or onto the **counter** if none matches.
3. Every take moves the belt one step. A plate you leave rides on and comes back a lap later.
4. Three of a kind close a bento. The next one opens, and matching counter plates hop straight in.
5. If the counter is full and the plate fits nowhere, the level is lost.

## Where things are

| Part | Where |
|---|---|
| Rules model, solver, bots, run with undo, doom detector | `game/sushi/` |
| Reusable kit: `StateSolver` (budgeted DFS), `Rack` (buffer slots with cascade), `PathBelt` (items stepping along a loop) | `game/kit/` |
| Board, plates, bentos, counter and feel | `game/sushi/*_view.gd`, `game/sushi/sushi_art.gd` |
| Baked levels | `data/levels/sushi_v1.json` |
| Level plan, generator and rating reports | `tools/levelgen/` |
| Game screen (HUD, boosters, results flow) | `ui/screens/game.gd` |
| Tests | `tests/test_sushi_*.gd` |

## Commands

```powershell
godot --path .                                                   # play on PC (405×720 window)
powershell -ExecutionPolicy Bypass -File tools/check.ps1         # the done check
godot --headless --path . -s tools/levelgen/generate_sushi.gd    # regenerate and bake the levels
powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Styles sushi
godot --headless --path . --export-debug "Android Debug APK" build/sushi-loop-debug.apk
adb install -r build/sushi-loop-debug.apk
```

`godot` is `C:\Users\lordi\GameDev\Tools\bin\godot.cmd` on the studio PC.

## Template

The template is the `template` remote (`git fetch template`), so improvements made there can be
merged in. The template's own guides stay in `docs/` (UI kit, architecture, customizing, services,
testing).

## Licences

Code in `core/`, `game/`, `ui/`, `tests/` and `tools/` is ours. Fonts are SIL OFL 1.1, icons Apache
2.0; every third-party file is listed in [ASSETS_LICENSES.md](ASSETS_LICENSES.md). Maaack's MIT
licence is kept in `LICENSE.txt` and `ATTRIBUTION.md`.
