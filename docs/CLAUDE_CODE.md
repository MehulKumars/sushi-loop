# Working with Claude Code

This repository is set up so Claude Code writes correct Godot 4.7 code for this studio's rules.
Start Claude Code **inside the game's folder**; that is what loads everything below.

## What is set up, and what each piece does

| Piece | File | What it does |
|---|---|---|
| Rules | `CLAUDE.md` | Read by Claude at the start of every session: Godot version, banned Godot 3 APIs, ad placement, touch sizes, performance rules, what to ask you first, the "done" check |
| Auto-check hook | `.claude/settings.json` > `tools/hooks/gd_check.ps1` | After every edit to a `.gd` file, compiles it inside the project and sends real errors back to Claude, which then fixes them |
| Project checker | `tools/hooks/check_script.gd` | Used by the hook. Plain `godot --check-only` reports false "Identifier not found" errors for autoload names, so this loads scripts in full project context instead |
| Done check | `tools/check.ps1` | Import, boot the game headless for 300 frames, run all tests. Claude must pass it before saying a task is done |

## How to work with Claude

1. **One small step at a time, plan first.** Ask for a plan, read it, then say "build step 1".
2. **Ask for tests with logic** (generators, solvers, scoring, ad rules). For generators and
   solvers, write the test cases yourself or in a separate session: a session grading its own work
   tends to write tests that pass.
3. **Ask for explanations:** "Explain what you just wrote like I'm a beginner."
4. **Play every step yourself**, on PC and on the phone, before moving on.
5. **Commit after each working step**, so you can always go back.
6. **For UI work, ask Claude to look at the screenshots** ("run the snapshots and check home at
   720x1280 and 960x1280"). It can read the PNGs and catch overlaps, clipping and contrast problems.

A good first session on a new game:
```
Review this idea as a mobile game designer: <one paragraph>.
Plan a greybox: one screen, placeholder shapes, the core action only. Plan only, no code yet.
Build step 1 of the plan with tests, then run tools/check.ps1.
Explain the new scripts to me like I'm a beginner.
Make a debug APK so I can try it on my phone.
```

## Who does what

| Claude is good at | Only you can do |
|---|---|
| Code and game systems | Decide whether it is fun |
| Level generators, solvers, bots | Judge feel on a real phone |
| Tests and fixing errors | Art, sound and music (no AI-generated assets) |
| Explaining code | Tune difficulty and balance |
| Android exports and checklists | Play Console account, payments, store page and video |
| Performance investigation | Read player feedback and make release decisions |

A real 2026 case: a solo developer shipped 7 games in two months with Claude Code and earned about
US$1 in ads, because nobody owned fun, player feedback or the store page.

## Optional: let Claude see the game

Claude can already run the game headless and read errors. To let it take screenshots and simulate
taps, add a Godot MCP server later; the free `hi-godot/godot-ai` (MIT, needs Godot 4.7+) does both.
Register MCP servers at Claude Code's default `local` scope so a cloned template never loads them
automatically, and only connect servers you trust.

## Troubleshooting the hook

- **The hook does not run:** Claude Code reads `.claude/settings.json` when a session starts.
  Restart the session or open `/hooks` once. Hooks on Windows need Windows PowerShell (built in).
- **It cannot find Godot:** set the `GODOT` environment variable to the console executable, or put
  `godot` on PATH.
- **See why it skipped a file:** set `GD_CHECK_DEBUG=1` and test by hand:
  ```powershell
  '{"tool_input":{"file_path":"core/events.gd"}}' | powershell -NoProfile -File tools/hooks/gd_check.ps1
  ```
- Files in `addons/` and non-`.gd` files are skipped on purpose.
