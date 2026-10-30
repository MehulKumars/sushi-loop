# Accessibility

Accessible games are also easier to play one-handed, on a bus, muted, or on a cheap phone, which is
most of this audience. Puzzle players skew 35+, so readable text and generous touch targets matter.

## Built into the template

| Feature | Where | Detail |
|---|---|---|
| Large touch targets | every theme (`tools/build_theme.gd`) | Every button, switch, slider and tile is at least 96 px on the 720 px canvas (= Android's 48 dp minimum, which also meets Apple's 44 pt and WCAG 2.2's 24 px). Checked for every style by `tests/test_theme.gd` and on every screen at three sizes by `tests/test_screens.gd` |
| Text contrast | every theme | WCAG AA: 4.5:1 for normal text, 3:1 for large text, in the `sushi` style, the game's only one (`tests/test_theme.gd`). Outlined text is measured against its outline |
| Readable text | every theme | 32 px body text (16 dp on a 360 dp phone), 26 px minimum for captions |
| State not by colour alone | switches, level tiles, the special plates | Switches change knob size and position. Level tiles show their stars or a lock, and the next level's tile its number without stars; locked chapters carry a lock and are faded; the Play button names hard levels in words ("Level 15 · Hard"). In play, a covered plate wears a cloche, the chef's special is a star on a gold plate, and a rush order's badge shows the takes left as a number (it also turns vermillion from two takes left) |
| Reduce Motion | Settings; `AppLifecycle`, `Juice.motion_scale` | Turns off button squash, popup pop-ins, the logo intro, Play button breathing, star pops, coin count-ups and background drift. Your own effects must check `Juice.motion_scale` too |
| Vibration toggle | Settings; `Haptics.enabled` | Haptics can be turned off; never the only signal |
| Notch-safe layout | `SafeAreaMargin` on every screen and popup | Keeps UI clear of camera holes, rounded corners and the gesture bar |
| Back button | `ui_cancel` includes Android Back | Closes the top popup, then goes back a screen; the game opens pause; home asks before quitting |
| Focus rings for keyboard and gamepad | `UI` autoload | Rings appear after a key or pad press and hide again after a tap |
| Interruptions | `AppLifecycle` > `Events.app_paused` | Progress saves on every change; pause state is restored when popups close |
| Separate volume controls | Settings | Music and Sound sliders, plus quick toggles in the pause menu |
| Offline play | design | Everything except ads works offline |
| Rules to look up | How to play (from home) | Short illustrated cards for each rule and special plate, and a button that replays the guided first level |

## Each game must still do

- **Never carry information by colour alone.** About 1 in 12 men has red-green colour blindness.
  Pair every meaningful colour with a shape, symbol or pattern, and check screenshots in greyscale
  and a colour-blind simulator.
- **Contrast for game pieces:** at least 3:1 against the board.
- **Never carry information by sound or vibration alone.** Many players play muted and phones can
  block haptics. Every important event needs a visual on the same frame.
- **No held buttons or button-mashing**; keep tap targets still while the player is aiming at them.
- **Primary actions in the bottom third** of the screen (one-thumb reach); pause and rare actions
  away from the thumb.
- **Teach by doing** in the first minute; no walls of text.
- **No flashing** effects that could trigger photosensitivity; keep screen shake out of calm games
  and scale it by `Juice.motion_scale` in loud ones.
- **Forgiveness:** undo, hints and free paths on hard levels.

## Known gaps

- **Screen readers:** Godot's AccessKit support for Android TalkBack was merged for Godot 4.8,
  which is still in development. Plan a TalkBack test for menu-heavy games once 4.8 is stable.
- **No text-size setting yet.** Word games should add one (a setting that raises the style's
  `font_size` and `text_scale` and rebuilds, or scales the theme at runtime).
- **No translations yet.** Strings live in scenes and scripts.

## Checklist before release

- [ ] `tools/check.ps1` passes (contrast, touch sizes, every screen at three sizes)
- [ ] Your game screens added to `tests/test_screens.gd` and pass
- [ ] Game pieces at least 3:1 against the board
- [ ] Game playable in greyscale and with sound off
- [ ] Reduce Motion removes or softens every effect
- [ ] Back button and app switching tested on a phone
- [ ] No important UI under the camera hole or the gesture bar (`safe_area` console command on PC, a
      real phone before release)
