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

A level is: a belt of `N` slots (12-24), the plate type in each slot (or empty), a queue of bento
types, how many bentos are open at once (`open`, 1 or 2), the pick-window size (`window`, 2 or 3),
the counter size (`counter`, 4-6) and how many queued bentos are shown (`preview`, display only).
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

### Stars

- 3 stars: won without a continue, and the counter never held more than `star_peak` plates.
- 2 stars: won without a continue.
- 1 star: won after a continue.

`star_peak` is baked per level: the counter size on levels 1-10 (any clean win is 3 stars), then
`par + 1`, where `par` is the smallest counter size with which the level can still be solved.

### Forgiveness

- **Doom detector:** after each take, the solver searches from the current state in small slices
  per frame (it never blocks input). If it *proves* no solution remains, the game offers to rewind
  to the most recent state known to be solvable, for free. If its budget runs out it says nothing.
- The counter pulses when one slot is left.
- Hint: the solver's next move, pulsed in the window.

## Levels

Levels are generated offline, checked and baked, never generated at run time.

1. `tools/levelgen/sushi_plan.json` lists each level's role and knobs (types, bentos, belt length,
   open, window, counter, preview).
2. The generator deals a bento queue and a belt from a seed (`SeedService`), then:
   - the solver must find a solution with the level's counter (budget-limited; unknown = reject);
   - `par` is the smallest counter size that still solves it;
   - a random-greedy bot (fits first, else random) and a careful bot (exit-first, preview-aware)
     each play it 200 times; their win rates rate the level.
3. It keeps the candidate closest to the role's target band and bakes it to
   `data/levels/sushi_v1.json` with `gen_version`. Levels 1-2 are hand-made tutorials (level 1
   forces the counter: its par is at least 1); level 3 is dealt with a very gentle band.
4. After chapter 1, no level except a rest level may be trivial (greedy wins more than 95%), hard
   and super-hard levels must reward care (careful beats greedy by more than 0.2), and no level is
   one narrow line (careful wins at least 35%). `tests/test_sushi_levels.gd` checks the bake.

Roles per 10 levels (roller-coaster sawtooth): 1-3 easy, 4 medium, 5 hard, 6 rest (a new idea at
low stakes), 7-8 medium, 9 super-hard, 10 rest. Knobs over the game: types 2 → 7, belt 12 → 24,
window 3 → 2, counter 6 → 4, preview 3 → 1.

**The reskin trap:** if the greedy bot wins more than 90% of mid-chapter levels, the moving window
is not creating real choices. `tools/levelgen/reports/` keeps the rating CSV that answers this.

## Feel (calm ASMR, crescendo when a bento closes)

| Moment | Effect |
|---|---|
| Belt steps | one tween on the shared belt offset, 0.12 s ease-out; wooden tick |
| Take | plate lifts (1.08) and arcs into the bento or onto the counter, about 0.2 s; porcelain clink |
| Bento closes | lid drops with a squash, gold ribbon, rice-grain particles; lid clack |
| Cascade | counter plates hop in 0.08 s apart, each a semitone higher |
| One slot left | counter outline pulse and a low tone, no shake |
| Fail | belt eases to a stop, counter nudges ±3 px, two-note fall |
| Level complete | small confetti, results |

Haptics: 12 ms on a take, 30 ms when a bento closes, 60 ms on a win (Settings toggle).

## Palette

| Role | Hex |
|---|---|
| Cream: counter, porcelain, background | `#F6EFE3` |
| Ink: belt, text, rim 3 (black lacquer) | `#23283B` |
| Vermillion: rim 1 | `#B8461A` |
| Blue: rim 2 | `#1F64A8` |
| Gold: accent on ink (buttons, ribbons, the window) | `#E8B04B` |

Vermillion and blue are close in greyscale, so the silhouette is the identity and rims also differ
by pattern (solid, dashed, double).

## Ads (when ads are switched on)

Rewarded: continue (+2 counter slots). Interstitials: none in the first session or before level 8,
then at most 1 per 2 won levels, 120 s apart, when the results screen opens. Never on the fail
screen, never after a rewarded ad, no paid continue on spike levels.

## Later mechanics (one per chapter, not built yet)

Stacked plates (lower plate dimmed), a chef who refills empty slots from a visible tray, a mixed
bento (3 different types), domed plates that reveal only in the window.

## Who owns what

- Claude builds: belt stepping, the solver, generator, bots and rating CSV, the doom detector,
  `Rack`, tests.
- The human owns: the seven sushi silhouettes (the code-drawn ones are placeholders), level order,
  the greybox question ("is choosing between 3 plates an interesting decision?"), foley, a
  respectful-theme check (no caricature, no fake Japanese text), the store video.

## Keep / kill (written before building)

| Metric | Kill | Iterate | Keep | Scale |
|---|---|---|---|---|
| Day-1 retention | < 22% | 22-29% | ≥ 30% | ≥ 38% |
| Day-7 retention | < 4% | 4-7.9% | ≥ 8% | ≥ 12% |
| Average session | < 3 min | 3-3.9 min | ≥ 4 min | ≥ 5.2 min |
| Ad revenue per daily player | < $0.006 | $0.006-0.011 | ≥ $0.012 | ≥ $0.02 |

Judge only on 500+ installs from strangers.
