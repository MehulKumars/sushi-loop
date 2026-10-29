# Getting started

This guide takes you from a fresh Windows PC to the template running on your phone, then to your
first game. No prior Godot or Android experience is assumed.

## 1. Tools you need (one-time)

| Tool | Version | What it is for |
|---|---|---|
| Godot | **4.7.2** (standard build, not .NET) | The engine and editor. Every game in this studio is pinned to this version. |
| Godot Android export templates | 4.7.2 | The pre-built engine Godot packs into your Android app. Install from the editor: *Editor > Manage Export Templates*. |
| OpenJDK | **17** | Android's build tools run on Java. Set `JAVA_HOME` to its folder. |
| Android SDK | Platform **36**, Build-Tools **36.1.0**, NDK **29.0.14206865**, CMake 3.10.2, platform-tools | Google's Android toolkit. Platform 36 is what Google Play requires; the NDK and CMake are needed for Gradle builds (Play's AAB format and plugins). platform-tools contains `adb`, which talks to your phone. Set `ANDROID_HOME`. |
| Git + GitHub CLI (`gh`) | any recent | Version history and GitHub. |
| VS Code + Claude Code | any recent | Where you work with Claude. |

Then, in Godot: *Editor > Editor Settings > Export > Android*: set **Java SDK Path** and
**Android SDK Path** (for example `%LOCALAPPDATA%\Android\Sdk`).

Not needed: Android Studio, the Android emulator (Godot 4's renderers often fail in emulators; use
a real phone), Python, Node.

## 2. Start a new game from the template

```powershell
gh repo create my-game --template MehulKumars/godot-mobile-template --private --clone
cd my-game
```

Every game gets its own repository. Improvements that every game should get go back into the
template repository, not just into one game.

## 3. Run it on your PC

```powershell
godot --path . -e          # open the editor (then press F5 to run)
godot --path .             # run the game directly
```

The game window opens at 405×720, a phone-shaped preview of the 720×1280 design canvas. The mouse
acts as a finger (`emulate_touch_from_mouse`). Ads, purchases and leaderboards are **mock**
versions that only print to the Output panel.

Check that everything is healthy:

```powershell
powershell -ExecutionPolicy Bypass -File tools/check.ps1
```

## 4. Run it on your Android phone

1. On the phone: *Settings > About phone*, tap **Build number** seven times to unlock
   **Developer options**, then turn on **USB debugging**.
2. Connect the phone by USB and accept the "Allow USB debugging?" prompt.
3. Check the connection: `adb devices` should list your phone.
4. Either:
   - **From the editor:** press the Android **Remote Deploy** button (top right). The preset
     "Android Debug APK" is marked runnable, so Godot builds, installs and starts the game, and the
     editor's debugger shows errors and profiling data from the phone.
   - **From the terminal:**
     ```powershell
     godot --headless --path . --export-debug "Android Debug APK" build/game-debug.apk
     adb install -r build/game-debug.apk
     ```
5. Phone logs (useful when something only breaks on the device): `adb logcat -s godot`

Things to try on the phone: tap through every screen, win and lose a level, page through the
chapters on home, press the Back button everywhere, and tap with three fingers at once to open the
debug console. A fresh install starts straight in level 1; home appears after the first win.

## 5. Your daily loop

1. Open the game folder in VS Code and start Claude Code **in that folder** (that is what loads
   `CLAUDE.md` and the auto-check hook).
2. Ask for one small step at a time, plan first. See [CLAUDE_CODE.md](CLAUDE_CODE.md).
3. Play the result on PC, then on the phone.
4. Run `tools/check.ps1`, then commit:
   ```powershell
   git add -A
   git commit -m "Describe the step"
   git push
   ```

## 6. Learning path for beginners

Before letting Claude write gameplay, spend about two weeks part-time on the basics:

1. **Godot Tours 101**, built into the editor.
2. **GDQuest "Learn GDScript From Zero"** (free, about 10 hours).
3. **One small 2D tutorial game by hand**, such as "Your first 2D game" in Godot's documentation.

Concepts you need to be able to read: nodes and scenes, signals, `_ready` / `_process` /
`_physics_process`, Resources, autoloads, the Input Map and touch events, Control containers and
anchors (most phone layout bugs live here), static typing, export presets and keystores, and the
remote debugger.

Coming from Unreal: a Godot **scene** is roughly a Blueprint class or prefab, **signals** play the
role of event dispatchers, and **autoloads** are like GameInstance subsystems (always-on singletons).

After that: ask Claude to explain every new script it writes, and build one small feature a week
with AI switched off.

## Where to go next
- [SUSHI_LOOP.md](SUSHI_LOOP.md): this game's rules, 1000 levels in 100 chapters, progression and economy.
- [UI_KIT.md](UI_KIT.md): the screens, the game's style, and how to add another.
- [ARCHITECTURE.md](ARCHITECTURE.md): what every part of the template does and how they connect.
- [CUSTOMIZING.md](CUSTOMIZING.md): what to change for each new game.
- [SERVICES.md](SERVICES.md): ads, purchases, leaderboards, analytics (the "backend").
- [ACCESSIBILITY.md](ACCESSIBILITY.md): what is built in and what each game must still do.
- [CLAUDE_CODE.md](CLAUDE_CODE.md): working with Claude and the hook.
- [TESTING_AND_DEBUGGING.md](TESTING_AND_DEBUGGING.md): tests, the debug console, phone debugging.
