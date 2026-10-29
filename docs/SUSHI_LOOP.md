# Sushi Loop: design and rules contract

Plates circle a sushi counter one step every time you take one. Pack each bento with three of a
kind before your counter space runs out.

Source: `Documents/GameDevPlan/Godot Mobile Studio Plan.html` (concept 2) and
`research_notes/Mobile game plan and design craft/game_loop_concepts_refined.md` §3.2.
This file is the contract: the rules below are what the code implements and what the tests check.
Change the rules here first.

## The twist

The board itself moves, but it is turn-based: every take advances the belt one slot. There is no
timer. Only the plates in the pick window at the bottom of the loop can be tapped. A plate you
leave slides on and comes back a lap later, so the order of takes is the puzzle.

## Rules (v1)

Plate **types** are `0..6`: maki, nigiri, onigiri, gunkan, tamago, dango, temaki. A type is shown
by its silhouette first and its plate-rim colour and pattern second (never colour alone).

A level is: a belt of `N` slots (12-32), the plate type in each slot (or empty), a queue of bento
types, how many bentos are open at once (`open`, 1 or 2), the pick-window size (`window`, 2 or 3),
the counter size (`counter`, 3-7) and how many queued bentos are shown (`preview`, display only).
Every type has exactly 3 plates per bento of that type, so plates = 3 × bentos.

R1. **Belt.** Plate ids are belt slot indices. The plate in slot `i` sits at ring position
`(i + offset) mod N`. The window is ring positions `0 .. window-1`; plates enter at 0 and leave
after `window-1`. At the start `offset` is 0; if the window is empty, the belt rolls on as in R5.

R2. **Window slot.** Window position `w` shows the plate in slot `(w - offset) mod N`, if any.

R3. **Take.** The player must take a plate each turn: tap a window position holding a plate. The
plate leaves the belt and is routed (R4). Unless the level is lost, the belt then advances (R5).
A tap on an empty position, or after the level is over, does nothing.

R4. **Routing** a plate of type `t`:
  1. If an open bento has type `t`, the plate goes into the one with the most plates already
     (ties: the lower open slot). A bento holding 3 plates closes (R6).
  2. Otherwise, if the counter has room, the plate goes on the counter (at the end).
  3. Otherwise the level is **lost** (counter overflow). The plate is held above the counter.

R5. **Advance.** `offset` grows by 1. Then, while plates remain on the belt and none is in the
window, `offset` grows by 1 again (empty stretches roll past on their own).

R6. **Closing.** A closed bento leaves its open slot. The next queued bento (if any) opens in the
same slot, and counter plates of its type hop into it in counter order, up to 3 (the relief
cascade). If that fills it, it closes too and the next one opens (repeat). With no queued bento
left the slot stays empty.

R7. **Win.** The level is won when every bento has closed. (Then the belt and counter are empty.)

R8. **Continue.** After a loss, a continue adds 2 counter slots, puts the held plate on the
counter and advances the belt (R5). It is offered as an opt-in rewarded video, never paid.

R9. **Undo.** Undo restores the state before the last take (including the counter peak). One free
undo per level. Rewinding after the doom detector's proof (below) is always free.

Invariant: after every take no counter plate matches an open bento (R4.1 and R6 send them in).

### API (what tests may call)

- `SushiLevel.make(belt: Array, bentos: Array, open := 2, window := 3, counter := 5)`; fields `belt`,
  `bentos`, `open`, `window`, `counter`, `preview`, `role`, `par`, `star_peak`, `greedy`, `careful`,
  `seed`, `id`; `to_dict()`, `SushiLevel.from_dict(d)`, `validate() -> String` ("" when valid).
- `SushiState.start(level)`; `copy()`; `take(w) -> bool`; `continue_game(extra := 2) -> bool`;
  `window_plate(w) -> int` (plate id or -1); `plate_type(id)`; `on_belt(id)`; `plates_on_belt()`;
  `ring_position(id)`; `fits(type)`; `open_type(slot)` (-1 when empty); `open_fill(slot)`;
  fields `offset`, `counter: Rack` (plate ids), `closed`, `lost`, `held` (-1 when none), `peak`,
  `continues`; `is_won()`, `is_over()`.
- `SushiSolver.solve(state, budget) -> StateSolver`; `SushiSolver.par(level, budget) -> int` (-1 if
  unknown); `SushiSolver.hint(state, budget) -> int` (window position, -1 if none).
- `SushiRun.new(level)`; field `state`; `take(w)`; `undo(extra := false) -> bool` (the free one, or
  an extra one after a rewarded video); `undos_left()`; `mark_safe()` (the current state is proven
  solvable); `rewind_to_safe() -> bool`; `continue_game() -> bool`; `stars() -> int`.
- `SushiBot.choose(state, kind, rng) -> int`; `SushiBot.play(level, kind, rng) -> bool`;
  `SushiBot.win_rate(level, kind, runs, seed) -> float`; kinds `SushiBot.GREEDY` (a fitting plate
  at random, else any plate at random) and `SushiBot.CAREFUL` (the fitting plate nearest the exit;
  else the plate whose bento comes soonest among those shown, more of the same kind on the counter
  first, then nearest the exit). `choose()` is exact; in `play()` the careful bot slips into a
  greedy move one take in ten (`SushiBot.SLIP`), so its win rate is graded, like a person's.
- `SushiMeta` (progression): `chapter_count()`, `chapter_range(chapter) -> Vector2i`,
  `chapter_name(chapter)`, `chapter_stars(chapter)`, `chapter_won(chapter)`,
  `is_chapter_finale(level)`, `first_level_of(type)`, `new_dishes(level) -> Array[int]`,
  `mark_dish_seen(type)`, `gifts_ready()`, `gift_progress() -> Vector2i`, `open_gift() -> int`;
  constants `GIFT_EVERY`, `GIFT_COINS`, `CHAPTER_BONUS`. The game screen's
  `coins_for(stars, role)` pays the stars.
- `SushiBoardView`: `play(level)`, `tap(w)`, `window_at(point)`, `window_point(w)`, `undo(extra)`,
  `rewind()`, `continue_game()`, `hint()`, `is_busy()`, `star_outlook() -> int`; fields `run`,
  `guide`, `chapter`, `collect_point`; signals `changed`, `took`, `bento_closed`,
  `bento_collected`, `won`, `lost`, `doomed`, `counter_low(room)`, `counter_used`, `combo(count)`.
  Effects never keep `is_busy()` true; only the model's events do.

### Stars

- 3 stars: won without a continue, and the counter never held more than `star_peak` plates.
- 2 stars: won without a continue.
- 1 star: won after a continue.

`star_peak` is baked per level: the counter size on levels 1-10 (any clean win is 3 stars), then
`par + 1`, where `par` is the smallest counter size with which the level can still be solved.

### Forgiveness

- **Doom detector:** after each take, the solver searches from the current state in small slices
  per frame (it never blocks input). If it *proves* no solution remains, the game says so and
  offers to rewind to the most recent state known to be solvable (for free), to retry the level
  from the start, or to keep going. If its budget runs out it says nothing.
- The counter pulses when one slot is left.
- Hint: the solver's next move, pulsed in the window.

## Levels

Levels are generated offline, checked and baked, never generated at run time. **1000 levels in
100 chapters of ten** (gen_version 2, `data/levels/sushi_v2.json`, about 100 KB: the belt and
queue are short strings such as `"01.2"`).

1. `tools/levelgen/sushi_plan.gd` gives each level its role, knobs (types, bentos, belt length,
   open, window, counter, preview, spread) and band. Levels 1-60 are frozen from the first bake
   (`tools/levelgen/frozen_v1.json`, played on phones in 0.3.0); later levels follow their
   chapter's twists (below).
2. The generator deals a bento queue and a belt from a seed (`SeedService`), then:
   - the solver must find a solution with the level's counter (budget-limited; unknown = reject);
   - `par` is the smallest counter size that still solves it (unknown = reject);
   - a random-greedy bot (fits first, else random: a careless player) and a careful bot
     (exit-first, preview-aware, slips one take in ten: an attentive player) each play it 200
     times; their win rates rate the level (a quick 40-run look drops deals far outside first).
3. It keeps the deal nearest the middle of the role's band. When no deal lands in the band, it
   deals again over a grid: the counter 0, -1, +1, -2, +2 from the plan, each with plates in
   good order, mixed, or scrambled (300 deals per try), until one lands; otherwise the nearest
   miss. Which way helps depends on the twists (one bento and a two-plate window can need plates
   in better order to get harder), so the grid is tried, not guessed.
4. After chapter 1, no level except a rest level may be trivial (greedy wins more than 95%), hard
   and super-hard levels must reward care (careful beats greedy by more than 0.2), and no level is
   one narrow line (careful wins at least 35%). `tests/test_sushi_levels.gd` checks the bake.
5. `tools/levelgen/generate_sushi.gd` runs one worker process per spare CPU core (about 25 min for
   all 1000 on 14 workers), merges them, and writes the rating CSV and a summary with the curve
   (`tools/levelgen/reports/sushi_v2.csv`, `.md`). `--misses` bakes again only levels outside their band.

**Difficulty targets.** Pass = 0.6 × careful + 0.4 × greedy, a rough first-try pass rate for a
typical player (to be replaced by real per-level pass rates from analytics after launch):

| Role | Greedy band | Careful band | Pass about | Tries |
|---|---|---|---|---|
| easy | 0.75-0.95 | 0.95-1.0 | 0.93 | 1 |
| medium | 0.4-0.85 | 0.85-1.0 | 0.8 | 1-2 |
| hard | 0.1-0.45 | 0.55-0.85 | 0.55 | 2 |
| super | 0-0.2 | 0.35-0.75 | 0.4 | 2-3 |
| rest | 0.7-1.0 | 0.95-1.0 | 0.93 | 1 |

**Roles per 10 levels** (roller-coaster sawtooth). Slots 5 (hard), 6 (rest), 9 (super-hard) and
10 (rest) never move; as players grow, easy slots turn medium and a second hard level arrives:

| Chapters | Roles 1-10 | Hard + super per ten |
|---|---|---|
| 1 | easy easy easy medium **hard** rest medium medium **super** rest | 2 |
| 2-10 | easy easy medium medium **hard** rest medium medium **super** rest | 2 |
| 11-40 | easy easy medium medium **hard** rest medium **hard** **super** rest | 3 |
| 41-100 | easy medium medium medium **hard** rest medium **hard** **super** rest | 3 |

**Chapter twists** (`SushiChapters`, shown on the card that opens a chapter; the plan reads the
same ids, so the card tells the truth). Each changes knobs, never rules:

| Twist | Knobs |
|---|---|
| learn (ch 1) | 2 → 4 dishes, the hand-made tutorials |
| more (ch 2) | 5-6 dishes, longer belts |
| all (ch 3) | all 7 dishes; a two-plate window on some levels |
| narrow | a two-plate window |
| single | one bento open at a time, one more counter slot |
| hidden | no queue preview |
| long | belts of 27-32 slots |
| dense | a full belt: no empty slots |
| tight | one counter slot fewer, three bentos previewed |
| mixed | each level one of the six above |

Chapters 1-6: learn, more, all, narrow, single, hidden. From chapter 7 the cycle long, narrow,
single, hidden, dense, tight, mixed repeats; from chapter 21 each chapter but a mixed one adds a
second twist that rotates (never hidden with tight). Belts grow a step each time round (at most
three). Hard and super-hard levels have one counter slot fewer, rest levels one more.

**The reskin trap:** if the greedy bot wins more than 90% of mid-chapter levels, the moving window
is not creating real choices. The bake summary prints this check.

## Feel (calm ASMR, crescendo when a bento closes)

| Moment | Effect |
|---|---|
| Belt steps | one tween on the shared belt offset, 0.14 s ease-out; crescent slats move; a soft tick |
| Take | the plate squashes as it lifts, its shadow drops away, it arcs (turning a little) into the bento or onto the counter in about 0.22 s; a ceramic chip on the lift |
| Dish lands in a bento | the cell pops, three sparkles, a porcelain clink (5 recorded variants) |
| Plate lands on the counter | a squash and settle, a wooden knock |
| Bento closes | lid drops with a squash, gold cord and bow, a puff of sakura petals; lid knock, then a koto chime; the packed bento flies up to the HUD bar, whose icon pops |
| Several bentos from one take | the chime climbs the pentatonic scale; "Double!" / "Triple!" over the bentos |
| Cascade | counter plates hop in 0.08 s apart, each a step higher on the D yo pentatonic scale |
| One slot left | counter settings pulse vermillion and a low muted pluck, no shake |
| Three stars lost | the HUD stars pop and drop to two; a one-time tip says the limit |
| Fail | the held plate rings vermillion, counter nudges ±4 px, a soft three-note fall |
| Level complete | the music dips, a koto phrase, sakura petals drift down over the counter; results stars ping in rising notes and the coins count up with a coin sound |

All motion scales with Reduce Motion (off = no particles, no squash, no flights to the HUD);
particles are pooled one-shot CPUParticles2D. Sound cues are tuned to one scale so ladders never
clash. Music: one calm CC0 piano-ambient track, ducked under fanfares.

Haptics: 12 ms on a take, 30 ms when a bento closes, 40 ms on a combo, 60 ms on a win, 80 ms on a
loss (Settings toggle).

## Palette

| Role | Hex |
|---|---|
| Cream: counter, porcelain, background | `#F6EFE3` |
| Ink: belt, text, rim 3 (black lacquer) | `#23283B` |
| Vermillion: rim 1 | `#B8461A` |
| Blue: rim 2 | `#1F64A8` |
| Gold: accent on ink (buttons, ribbons, the window) | `#E8B04B` |

The dish is the identity; the rim backs it up with a colour and a pattern unique to each type:

| Type | Dish | Rim |
|---|---|---|
| 0 | Salmon nigiri | blue `#1F64A8`, solid |
| 1 | Onigiri | vermillion `#B8461A`, dashed |
| 2 | Dango | ink `#23283B`, double |
| 3 | Ebi fry | green `#4F8A3A`, solid |
| 4 | Naruto | purple `#7A5BA6`, dashed |
| 5 | Purin | teal `#2E8B8B`, double |
| 6 | Ika | gold `#C98A1B`, solid |

Each chapter is a restaurant with its own belt, rail, wood and noren colours (`SushiPalette.SHOPS`).

## Progression (between levels)

- **First launch:** a player who has not won a level goes from the splash straight into level 1;
  no menu first. Every later launch opens home.
- **Chapters** of ten levels, each a restaurant: twelve looks (`SushiPalette.SHOPS`) that come round
  again with a numeral ("Corner Stall II"). Home shows the next level's chapter as a road of
  plates (`SushiLevelRoad`): won plates with their stars (tap to replay), the next level as the
  big gold plate, locked plates dimmed, "Hard" and "Super hard" tags so the sawtooth is visible
  ahead; arrows page back through earlier chapters. One big Play button starts the next level.
  Win → Next goes straight into the next level, never through home.
- **Welcome card:** a chapter's first level (from chapter 2) names the restaurant and its twist,
  once (`SushiChapters.text()`).
- **New on the menu:** the first time a dish rides the belt (from level 2) a card shows it on its
  plate, with its name and a line about it. Once per install.
- **Star gifts:** every 15 stars opens a gift of 100 coins, right after the win that earned it (or
  from the gift button in home's top bar, whose badge counts the stars still needed).
- **Chapter bonus:** the first win of a chapter's last level gives 100 coins and a card naming the
  next restaurant.
- **Three-star outlook:** the HUD shows the stars this attempt is on course for; the counter
  marks its first `star_peak` settings with a small gold star.
- **One-time tips:** the first plate on the counter, the first lost third star.

## Economy (coins; no purchases)

No shop, purchases, daily reward or ranks. Coins are the booster currency: 10 per star, ×1.5 on
hard levels, ×2 on super-hard levels; star gifts and chapter bonuses as above.

| Booster | Free per level | Then |
|---|---|---|
| Undo (R9) | 1 | 30 coins, or a rewarded video when short of coins |
| Hint (the solver's next move) | 1 | 30 coins, or a rewarded video when short of coins |
| Continue after a loss (R8: +2 counter slots) | - | one free rewarded video per attempt, or 50 coins; at most 3 continues per attempt (Retry is always free) |
| Step back after a doom proof | always free | - |

Levels 1-2 guide the first take: the window frame breathes and the plate that fits glows with a tap ripple.

## Ads (all through `Services.ads`; mocks until AdMob is wired)

Rewarded, always the player's choice and clearly labelled: the continue (free, once per attempt),
×2 coins on the results of a win, a hint or an undo when the player is short of coins (asked in a
confirm first). Interstitials: none in the first session or before level 8, then at most 1 per 2
won levels, 120 s apart, 60 s clear of a rewarded video, only when the results screen of a win
opens. Never on the fail screen, never on Next / Retry, never during play. No banners. In a
release build the mock reports no ads ready, so no video offers show until AdMob is wired (phone test
builds made from the APK preset carry the `test_ads` feature and keep the mock offers; the Play preset never does).

Review: the Play in-app review sheet is requested once, after the first win of level 10 (the end
of chapter 1); Play decides whether it shows. Never after a loss.

## Later mechanics (one per chapter, not built yet)

Stacked plates (lower plate dimmed), a chef who refills empty slots from a visible tray, a mixed
bento (3 different types), domed plates that reveal only in the window.

## Who owns what

- Claude builds: belt stepping, the solver, generator, bots and rating CSV, the doom detector,
  `Rack`, tests.
- The human owns: the dish art (Fluent Emoji 3D renders, MIT, stand in; own art can replace
  `assets/food/` file for file), level order, the greybox question ("is choosing between 3 plates
  an interesting decision?"), foley and music by ear (Kenney CC0 recordings, synthesised koto cues
  and a CC0 track stand in), a respectful-theme check (no caricature, no fake Japanese text), the
  store video.

## Keep / kill (written before building)

| Metric | Kill | Iterate | Keep | Scale |
|---|---|---|---|---|
| Day-1 retention | < 22% | 22-29% | ≥ 30% | ≥ 38% |
| Day-7 retention | < 4% | 4-7.9% | ≥ 8% | ≥ 12% |
| Average session | < 3 min | 3-3.9 min | ≥ 4 min | ≥ 5.2 min |
| Ad revenue per daily player | < $0.006 | $0.006-0.011 | ≥ $0.012 | ≥ $0.02 |

Judge only on 500+ installs from strangers.
