---
name: run-imagealpha
description: Build, run, and drive ImageAlpha, the macOS PNG quantizer. Use when asked to start or relaunch ImageAlpha, build it, run its tests, take a screenshot of its window, click through its UI (open an image, toggle options, close/save/overwrite, quit), or confirm a change works in the real app.
---

ImageAlpha is a native AppKit/SwiftUI document app, so it only runs on macOS.
Drive it with `.claude/skills/run-imagealpha/driver.sh`. It builds the Debug
app, launches it, clicks through it with System Events UI scripting, and takes
window screenshots with `screencapture`. Mouse drags, scrolls and pointer
moves, which System Events can't post, go through `input.swift`, a small
CoreGraphics helper the driver compiles on first use. All paths are relative to
the repo root.

## Prerequisites

You need Xcode, Rust (for libimagequant), and the `pngquant` submodule checked
out. The submodule line should start with a space, not `-`.

```bash
xcodebuild -version | head -1      # Xcode 26.6 here
cargo --version                    # cargo 1.93.0 here
git submodule status pngquant
```

The terminal running the agent needs **Accessibility** permission (to click)
and **Screen Recording** permission (to screenshot), both under System
Settings → Privacy & Security. To check the first, run this; it should print
`true`:

```bash
osascript -e 'tell application "System Events" to get UI elements enabled'
```

## Build

```bash
.claude/skills/run-imagealpha/driver.sh build
```

This runs `make pngquant` (cargo), then `xcodebuild` for Debug with ad-hoc
signing, and prints the app's path in DerivedData. Two kinds of output are
noise: cargo's "profiles for the non root package will be ignored" warning,
and xcodebuild's "multiple matching destinations" lines.

## Run (agent path)

Each driver command does one thing and prints the app's state afterwards:
its windows, the status bar, and any sheet's text and buttons. Read that
output to decide the next step. Screenshots go to
`$IMAGEALPHA_RUN_DIR/<name>.png`, which defaults to `$TMPDIR/imagealpha-run/`.

This flow opens a fresh copy of `samples/dice.png`, edits it, and overwrites
it through the close sheet:

```bash
D=.claude/skills/run-imagealpha/driver.sh
F=$($D fixture)
$D launch "$F"
$D wait-ready
$D toggle 3                 # Dithered on: the document now has unsaved changes
$D close                    # -> "Do you want to save…" sheet
$D sheet Save               # -> "Overwrite original file?" sheet
$D ss overwrite-alert
$D sheet Overwrite          # writes $F; the window closes
python3 -c "import sys; d=open(sys.argv[1],'rb').read(); print('PNG colour type', d[25])" "$F"
pgrep -x ImageOptim >/dev/null && osascript -e 'tell application "ImageOptim" to quit'
$D quit
```

Look at the screenshot with the Read tool. The colour type should print `3`,
meaning an indexed PNG.

| command | what it does |
|---|---|
| `build` | Builds the Debug app (ad-hoc signed) and prints its path |
| `fixture` | Copies `samples/dice.png` to `$IMAGEALPHA_RUN_DIR/fixtures/` and prints the path |
| `launch [file…]` | Quits any running Debug instance, then opens the app with the given files, or an empty Untitled window if none, and waits for a window |
| `wait-ready` | Waits up to 30 s for quantization to finish, judged by the status bar |
| `state` | Prints windows, status bar and sheets, or `not running` |
| `controls` | Dumps the front window's accessibility elements, in order, with their values |
| `toggle <n>` | Clicks sidebar checkbox n: 1 Show original, 2 Compare, 3 Dithered |
| `close` | Clicks the front window's close button |
| `sheet <button>` | Clicks a button on the front window's sheet, using its exact title (`"Don’t Save"` has a curly apostrophe) |
| `menu <menu> <item>` | Clicks a menu item, e.g. `menu File "Save…"` or `menu ImageAlpha "Quit ImageAlpha"` |
| `key escape\|return` | Presses Escape (Cancel) or Return (the default button) |
| `ss [name] [cursor]` | Screenshots the front window to `$IMAGEALPHA_RUN_DIR/<name>.png`, with the pointer if `cursor` is given |
| `canvas` | Prints the centre of the image canvas as `x y` |
| `scroll <dx> <dy> [command\|option]` | Scrolls over the canvas: pans, or zooms with a modifier |
| `move <x> <y>` | Moves the pointer |
| `drag <x1> <y1> <x2> <y2>` | Presses, drags and releases the mouse. Points can be passed as `"x y"` strings |
| `finder <dir\|file>` | Shows it in a Finder window placed clear of ImageAlpha's. Prints a drop point in the folder, or the file's centre |
| `quit` | Quits through the menu. With unsaved changes it prints the blocking sheet and exits 1 |

Dragging in and out of Finder:

```bash
D=.claude/skills/run-imagealpha/driver.sh
OUT=$IMAGEALPHA_RUN_DIR/out; mkdir -p "$OUT"
TARGET=$($D finder "$OUT")       # first: it brings Finder forward
SRC=$($D canvas)                 # then ImageAlpha, so its canvas takes the click
$D drag "$SRC" "$TARGET"         # -> $OUT/dice-quantized.png
cp samples/dice.png "$OUT/drop-me.png"
ITEM=$($D finder "$OUT/drop-me.png")
$D drag "$ITEM" "$($D canvas)"   # opens drop-me.png as a document of its own
```

Scrolling and the pointer:

```bash
$D scroll 0 120                  # pans: the image moves down
$D scroll 0 60 command           # zooms in one step
$D move $($D canvas); $D ss hand cursor
```

To discard unsaved changes, close the window and choose Don't Save:

```bash
.claude/skills/run-imagealpha/driver.sh close
.claude/skills/run-imagealpha/driver.sh sheet "Don’t Save"
```

## Run (human path)

```bash
open "$(ls -d ~/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Debug/ImageAlpha.app)"
```

## Test

```bash
make test
```

All tests should pass. The test host logs
`Unable to get synchronousRemoteObjectProxy … com.apple.linkd.autoShortcut`
lines; they're system noise.

## Gotchas

- **`make debug` fails** with `Signing for "ImageAlpha" requires selecting
  either a development team or a provisioning profile`. Use
  `driver.sh build`, which signs ad-hoc (`CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`).
- **The sidebar's controls have no accessibility names.** SwiftUI exposes the
  checkboxes as bare `AXCheckBox`es, so the driver addresses them by position.
  Run `controls` to see the order.
- **Don't use the Tools → Dithering or Quality menus to dirty a document.**
  They write the user's real preferences (bundle id `net.pornel.ImageAlpha`,
  shared with any installed copy). `toggle 3` only changes the document.
- **AppleScript `quit` with unsaved changes** blocks for the two-minute Apple
  Event timeout, then fails with `User canceled. (-128)`, and the save sheet
  disappears with it. That's why `quit` clicks the Quit menu item instead.
  Exercise the quit sheet with `menu ImageAlpha "Quit ImageAlpha"`.
- **`open` straight after quitting can launch nothing.** Launch Services hands
  the request to the instance that's still exiting. `launch` waits until Launch
  Services reports the app gone.
- **Saving can launch ImageOptim.** If ImageOptim is installed, Save and
  Overwrite open the file in it, because the Save panel's "Optimize with
  ImageOptim" option is on by default. ImageOptim then rewrites the file:
  34,652 bytes became 31,682 here. Don't compare file sizes after a save, and
  quit ImageOptim afterwards.
- **The Save panel's buttons aren't direct children of its sheet.** Use
  `key escape` to cancel it.
- **Opening a file leaves an empty Untitled window open.** AppKit doesn't
  replace it. `launch "$F"` avoids it by launching with the file.
- **Points are `"x y"` strings.** zsh doesn't split an unquoted `$VAR` into
  words the way bash does, so `input.swift` splits each argument itself. Pass
  points quoted, as above.
- **A drag must start in the frontmost app.** A first click on an inactive
  window only activates it. Call `finder` before `canvas`, since each brings
  its app forward.
- **System Events reports a SwiftUI button's `description` as "button".** The
  real label is there: the Accessibility API's `AXDescription` for a
  background thumbnail reads "Blue".
- **When extending the driver's AppleScript:**
  - `before` is a reserved word.
  - Looping `repeat with e in (entire contents of …)` and filtering by role
    silently matched nothing. Loop by index over a saved list instead
    (`set c to entire contents of …` then `item i of c`), or address elements
    by path, e.g. `checkbox 3 of group 1 of splitter group 1 of group 1 of window 1`.

## Troubleshooting

- **`Still running: a sheet is asking about unsaved changes.`** from `quit` or
  `launch`: the document has unsaved changes. Run `sheet "Don’t Save"`, or
  `sheet Cancel` to keep the app open.
- **`Can’t get button "Cancel" of sheet 1 of window 1`**: the sheet is the
  Save panel. Use `key escape`.
- **`ImageAlpha (Debug) is not running; run: driver.sh launch`**: the app has
  quit, for example after `sheet "Don’t Save"` during a quit.
