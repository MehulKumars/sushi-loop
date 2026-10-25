# Assets and code licences

Every third-party file in a shipped game must be listed here with its author, licence and source.
Allowed: CC0, MIT, Apache 2.0, CC-BY (with credit in the Credits screen), SIL OFL for fonts.
Never: CC-BY-NC (bars ad-supported games), CC-BY-ND, GPL or CC-BY-SA in closed-source games, AI-generated assets.

## Code (addons)
| Item | Version | Author | Licence | Ships in release? |
|---|---|---|---|---|
| Maaack's Game Template, Scene Loader, Music Controller, UI Sound Controller | 1.7.0 | Marek Belski and contributors | MIT (`LICENSE.txt`, packed into builds and shown in the credits) | Yes (examples folder and logos excluded) |
| Maaack's Plugin Updater, Clean Copy Examples | 1.7.0 | Marek Belski and contributors | MIT | No (editor only, excluded) |
| GUT (Godot Unit Test) | 9.7.1 | Butch Wesley and contributors | MIT (`addons/gut/LICENSE.md`) | No (excluded) |
| LimboConsole | 0.8.0 | Serhii Snitsaruk | MIT (`addons/limbo_console/LICENSE.md`) | Yes, but disabled in release builds; its Monaspace fonts are excluded (the console uses `addons/limbo_console_theme.tres`) |

## Written for this template
| Item | Notes |
|---|---|
| `core/`, `ui/`, `tests/`, `tools/`, the five styles and their themes, `styled_background.gdshader`, `hit_flash.gdshader`, the switch and slider artwork (SVG drawn in `tools/build_theme.gd`), the placeholder app icon (`icon.png`, `assets/template_icon/`) | Original work for this template; reuse freely in your games |

## Fonts (all SIL Open Font License 1.1, from Google Fonts)
The licence text for each is next to it in `core/ui/fonts/OFL_<name>.txt`. OFL fonts may be
bundled in commercial games if each copy carries the licence: both export presets pack the
`OFL_*.txt` files (and the icons' Apache licence) into the app, and the credits list the fonts.

| Font | Used by style | Copyright |
|---|---|---|
| Outfit | Sleek Dark | The Outfit Project Authors (github.com/Outfitio/Outfit-Fonts) |
| Fredoka | Candy Casual | The Fredoka Project Authors (github.com/hafontia/Fredoka-One) |
| Orbitron (Reserved Font Name "Orbitron") | Neon Arcade titles | The Orbitron Project Authors (github.com/theleagueof/orbitron) |
| Exo 2 | Neon Arcade text | The Exo 2 Project Authors (github.com/googlefonts/Exo-2.0) |
| Nunito | Cozy Paper, Sushi Loop | The Nunito Project Authors (github.com/googlefonts/nunito) |
| Pixelify Sans | Pixel Retro titles | The Pixelify Sans Project Authors (github.com/eifetx/Pixelify-Sans) |
| VT323 | Pixel Retro text and numbers | The VT323 Project Authors (peter.hull@oikoi.com) |
| Anonymous Pro, Courier Prime, Lobster Two | GUT only (not shipped) | See `addons/gut/fonts/` |

## Icons
| Item | Licence | Source |
|---|---|---|
| 38 icons in `core/ui/icons/` (Material Symbols Rounded, filled; recoloured white and resized to 48 px) | Apache 2.0 (`core/ui/icons/LICENSE_material_symbols.txt`) | Google, github.com/google/material-design-icons |

## Game assets
Add one row per asset as you add them: file, author, licence, source URL.
| File | Author | Licence | Source |
|---|---|---|---|
| `assets/audio/sfx/*.wav` (tick, take, clink, counter, lid, chime, hop, warn, fail, win, click) | Synthesised by `tools/audio/synth_sushi_sfx.gd` (no samples) | Original work | - |
| Plates, sushi silhouettes, bentos, belt and the menu emblem | Drawn in code (`game/sushi/sushi_art.gd`, `game/kit/path_belt.gd`) | Original work | - |
| The Sushi Loop style (`core/ui/styles/sushi.tres`) and its theme | Palette from the studio plan | Original work | - |
