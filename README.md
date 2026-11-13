# Arrow Escape (Godot 4)

Mobile puzzle game inspired by *Amaze GO!* — 1000 levels, **every one a 128x128 board** with ~1700-1900 interlocked arrows (chains 140+ deep).

**Rule:** tap an arrow and it slides out along its own path in the direction its head points.
It only escapes if every cell in a straight line in front of the head is empty. Otherwise it
bumps into the blocker and you lose a drop (3 drops per level). Clear every arrow to win.

Buttons: back / theme palette / settings (top) · fit-to-screen (corner brackets) · hint (bulb, shows a safe arrow).
Zoom with a two-finger pinch (two fingers also pan); 5 colour themes, per-arrow candy colours, haptic feedback, confetti.
Big boards: pinch to zoom, drag to pan (mouse wheel on desktop). Boards past ~20x20 start zoomed in; the grid button cycles fit / comfortable / close, and a hint scrolls to the safe arrow.

## Run
Open this folder in Godot 4.4+ (tested on 4.7.2) and press F5. Main scene: `scenes/menu.tscn`.

## Level maker — how the 1000 levels are produced

Every level = a **random unique base64 seed** + frozen generator params (size, shape, arrow length,
blocking bias…). `scripts/level_gen.gd` is deterministic: the same seed + params always rebuilds
the exact same layout on every device. Levels are **always solvable by construction** (arrows are
placed in reverse removal order) and are re-verified by actually playing them.

```bash
# (re)build all 1000 levels in parallel (all CPU cores) -> data/levels.json + data/layouts.bin
powershell -ExecutionPolicy Bypass -File tools/build_levels.ps1

# same thing in one process (slow: the 128x128 levels take ~2s per candidate seed)
godot --headless --path . --script res://tools/level_maker.gd -- --count 1000 --force

# keep finalized levels, only add missing ones (e.g. grow from 1000 to 1500)
godot --headless --path . --script res://tools/level_maker.gd -- --count 1500

# unhappy with a few levels? draw fresh random seeds for just those
godot --headless --path . --script res://tools/level_maker.gd -- --reroll 17,42,250

# reproducible build from a master phrase instead of true randomness
godot --headless --path . --script res://tools/level_maker.gd -- --count 1000 --force --master "my secret"

# look at one level as ASCII (try any seed for any level number)
godot --headless --path . --script res://tools/level_maker.gd -- --preview 400 --seed hello

# check the file: every baked level solvable + every seed still reproduces its layout
godot --headless --path . --script res://tools/level_maker.gd -- --verify

# difficulty benchmark across the curve
godot --headless --path . --script res://tools/level_maker.gd -- --bench
```

`data/levels.json` stores per level: `seed`, params and stats (`arrows`, `free` = arrows free at start,
`depth` = longest chain, `rating` 0-100). The baked layouts (compact strings, zstd-compressed) live in
`data/layouts.bin`, so phones never have to generate anything. Levels past 1000 are generated endlessly at runtime.

### Tuning difficulty
Edit `scripts/difficulty.gd` (`params_for` = board size / shapes / arrow length / blocking, and
`target_rating` = the difficulty curve the maker aims for) then regenerate with `--force`
(or `--reroll` for specific levels). Early levels: 3x3 with ~4 arrows. Levels from ~875 on: full 128x128
boards with ~2000 arrows and dependency chains 150+ deep (shaped boards - heart, trophy, hourglass… - mixed in). Every 10th level is a breather,
every 50th is a trophy boss.

## Tests
```bash
godot --headless --path . res://tools/selftest.tscn -- --all     # plays all 1000 levels with the real Board logic
```
`tools/shot.tscn` renders screenshots (see the header of `tools/shot.gd`).

## Layout
```
scripts/seed_rng.gd    deterministic PRNG (mulberry32)      scripts/board.gd     board, input, animation
scripts/level_gen.gd   generator + analyzer + encode/decode scripts/game.gd      game screen + dialogs
scripts/difficulty.gd  difficulty curve                      scripts/menu.gd      level select
scripts/level_db.gd    loads data/levels.json                scripts/save.gd      progress/settings (autoload)
tools/level_maker.gd   level maker CLI                       scripts/sfx.gd       procedural sounds (autoload)
```

## Android build
1. Godot editor: *Editor > Manage Export Templates* (install), set the Android SDK + JDK in
   *Editor Settings > Export > Android*.
2. *Project > Export > Add… > Android*, set a package name (e.g. `com.yourname.arrowescape`),
   enable *Use Gradle Build* if you want AAB for Play Store, create/choose a keystore, Export.
3. The project is already portrait-locked, 1080x1920 base, GL Compatibility renderer.

An export preset is already in `export_presets.cfg` (package `com.arrowescape.game`, arm64 + armv7,
no Gradle). Command-line export (needs the export templates, JDK 17 and Android SDK build-tools 35+):
```bash
godot --headless --path . --export-debug "Android" build/ArrowEscape.apk
```
That APK is debug-signed: fine for sideloading. For Google Play, create a release keystore, fill it in
under *Project > Export > Android > Keystore > Release*, switch on Gradle build + AAB and export release.

The slot under the buttons (tan strip) is where a banner ad goes.

## Difficulty switch
`scripts/difficulty.gd` has `ALL_LEVELS_MAX := true`: every level uses the level-1000 settings (128x128). Set it to `false` and rebuild to get the gentle ramp (3x3 on level 1 up to 128x128 around level 875) back.
