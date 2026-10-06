#!/bin/bash
# Builds, launches and drives the ImageAlpha Debug build through System Events
# UI scripting, and screenshots it. Run from the repo root:
#   .claude/skills/run-imagealpha/driver.sh <command> [args]
# Commands are listed in SKILL.md and by `driver.sh help`.
set -euo pipefail

RUN_DIR="${IMAGEALPHA_RUN_DIR:-${TMPDIR:-/tmp}/imagealpha-run}"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROCESS_PATTERN='Debug/ImageAlpha.app/Contents/MacOS/ImageAlpha'

app_path() {
  ls -d "$HOME"/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Debug/ImageAlpha.app 2>/dev/null | head -1
}

app_pid() {
  pgrep -f "$PROCESS_PATTERN" | head -1 || true
}

require_pid() {
  local pid
  pid=$(app_pid)
  if [ -z "$pid" ]; then
    echo "ImageAlpha (Debug) is not running; run: driver.sh launch" >&2
    exit 1
  fi
  echo "$pid"
}

# Runs an AppleScript body inside `tell` blocks for the Debug app's process,
# found by pid so an installed release copy (same process name) is never
# touched. Extra shell arguments arrive as `item 2…` of argv. `content` is the
# front window's split view: `group 1 of content` is the sidebar, `group 2 of
# content` the canvas with the status bar.
as_process() {
  local pid body
  pid=$(require_pid)
  body="$1"
  shift
  osascript - "$pid" "$@" <<EOF
on run argv
  set pid to (item 1 of argv) as integer
  tell application "System Events"
    tell (first process whose unix id is pid)
      try
        set content to splitter group 1 of group 1 of window 1
      end try
$body
    end tell
  end tell
end run
EOF
}

wait_for() { # wait_for <seconds> <command…>: poll until the command succeeds
  local deadline=$((SECONDS + $1))
  shift
  until "$@"; do
    if [ $SECONDS -ge $deadline ]; then return 1; fi
    sleep 0.25
  done
}

has_window() {
  [ "$(as_process 'return count of windows' 2>/dev/null || echo 0)" -gt 0 ]
}

# Launch Services must agree too: `open` straight after the process exits can
# still be handed to the dying instance, and then nothing launches.
not_running() {
  [ -z "$(app_pid)" ] && [ "$(osascript -e "application \"$(app_path)\" is running")" = "false" ]
}

cmd_build() {
  make pngquant >/dev/null
  xcodebuild -project ImageAlpha.xcodeproj -scheme ImageAlpha -configuration Debug \
    CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build -quiet
  app_path
}

cmd_launch() {
  local app
  app=$(app_path)
  [ -n "$app" ] || { echo "No Debug build; run: driver.sh build" >&2; exit 1; }
  if [ -n "$(app_pid)" ]; then cmd_quit; fi
  if [ $# -gt 0 ]; then open -a "$app" "$@"; else open "$app"; fi
  wait_for 15 has_window || { echo "ImageAlpha launched but showed no window" >&2; exit 1; }
  echo "pid $(app_pid)"
}

# Quits through the menu, as a user would. AppleScript's `quit` event instead
# blocks for its two-minute timeout when there are unsaved changes, then fails
# ("User canceled", -128) and takes the save sheet down with it.
cmd_quit() {
  as_process '
      set frontmost to true
      click menu item "Quit ImageAlpha" of menu "ImageAlpha" of menu bar item "ImageAlpha" of menu bar 1' >/dev/null
  if ! wait_for 5 not_running; then
    echo "Still running: a sheet is asking about unsaved changes." >&2
    cmd_state >&2
    exit 1
  fi
  echo "quit"
}

cmd_state() {
  if [ -z "$(app_pid)" ]; then
    echo "not running"
    return
  fi
  as_process '
      set out to "windows: " & (count of windows)
      repeat with w in windows
        set out to out & linefeed & "window: " & (name of w as text)
        try
          set out to out & linefeed & "  status: " & (value of static text 1 of group 2 of splitter group 1 of group 1 of w as text)
        end try
        repeat with s in (sheets of w)
          set AppleScript'"'"'s text item delimiters to " | "
          set texts to {}
          repeat with t in (static texts of s)
            set end of texts to (value of t as text)
          end repeat
          set out to out & linefeed & "  sheet: " & (texts as text)
          set out to out & linefeed & "  sheet buttons: " & ((name of buttons of s) as text)
        end repeat
      end repeat
      return out'
}

cmd_controls() {
  as_process '
      set out to ""
      set elements to entire contents of window 1
      repeat with e in elements
        set line_ to (role of e as text)
        try
          set v to value of e
          if v is not missing value then set line_ to line_ & " = " & (v as text)
        end try
        set out to out & line_ & linefeed
      end repeat
      return out'
}

cmd_toggle() { # toggle <n>: sidebar checkbox 1 Show original, 2 Compare, 3 Dithered
  as_process '
      set box to checkbox ((item 2 of argv) as integer) of group 1 of content
      click box
      delay 0.5
      return "checkbox " & (item 2 of argv) & " = " & (value of box as text)' "$1"
}

cmd_close() {
  as_process '
      click (first button of window 1 whose subrole is "AXCloseButton")
      delay 1
      return "closed or asked"' >/dev/null
  cmd_state
}

cmd_sheet() { # sheet <button title>
  as_process '
      click button (item 2 of argv) of sheet 1 of window 1
      delay 1' "$1" >/dev/null
  cmd_state
}

cmd_menu() { # menu <menu> <item>: e.g. menu File "Save…" (titles exact, … included)
  as_process '
      set frontmost to true
      click menu item (item 3 of argv) of menu (item 2 of argv) of menu bar item (item 2 of argv) of menu bar 1
      delay 1' "$1" "$2" >/dev/null
  cmd_state
}

cmd_key() { # key escape|return
  local code
  case "$1" in
    escape) code=53 ;;
    return) code=36 ;;
    *) echo "key: escape or return" >&2; exit 1 ;;
  esac
  as_process '
      set frontmost to true
      key code ((item 2 of argv) as integer)
      delay 1' "$code" >/dev/null
  cmd_state
}

status_is_ready() {
  local status
  status=$(as_process 'return value of static text 1 of group 2 of content' 2>/dev/null || true)
  case "$status" in
    Original:*" Quantized: "[0-9]*|Quantized:*) return 0 ;;
    *) return 1 ;;
  esac
}

cmd_wait_ready() {
  wait_for 30 status_is_ready || { echo "Quantization didn't finish within 30 s" >&2; cmd_state >&2; exit 1; }
  cmd_state
}

window_frame() { # the front window's frame as "x y w h", after bringing the app forward
  as_process '
      set frontmost to true
      delay 0.5
      set {x, y} to position of window 1
      set {w, h} to size of window 1
      return (x as text) & " " & (y as text) & " " & (w as text) & " " & (h as text)'
}

cmd_ss() { # ss [name] [cursor]: screenshot window 1 to $RUN_DIR/<name>.png, with the pointer if asked
  local name="${1:-screen}" bounds out cursor_flag=""
  [ "${2:-}" = cursor ] && cursor_flag="-C"
  mkdir -p "$RUN_DIR"
  out="$RUN_DIR/$name.png"
  bounds=$(window_frame | tr ' ' ',')
  screencapture -x $cursor_flag -R"$bounds" "$out"
  sips -Z 1000 "$out" >/dev/null
  echo "$out"
}

# Mouse and scroll events go through input.swift (System Events can't post
# them), compiled into $RUN_DIR on first use.
input_tool() {
  local tool="$RUN_DIR/input"
  if [ ! -x "$tool" ] || [ "$SKILL_DIR/input.swift" -nt "$tool" ]; then
    mkdir -p "$RUN_DIR"
    swiftc -O "$SKILL_DIR/input.swift" -o "$tool"
  fi
  "$tool" "$@"
}

cmd_canvas() { # canvas: print the centre of the image canvas as "x y"
  as_process '
      set frontmost to true
      set g to group 2 of content
      set {x, y} to position of g
      set {w, h} to size of g
      return ((x + w div 2) as text) & " " & ((y + h div 2) as text)'
}

# Points may be passed as the "x y" strings `canvas` and `finder` print;
# input.swift splits them.
cmd_scroll() { # scroll <dx> <dy> [command|option]: scroll over the canvas
  input_tool scroll "$(cmd_canvas)" "$@"
  sleep 0.5
}

cmd_move() { # move <x> <y>: move the pointer
  input_tool move "$@"
  sleep 0.5
}

cmd_drag() { # drag <x1> <y1> <x2> <y2>: press, drag and release the mouse
  input_tool drag "$@"
  sleep 1
}

# Finder's window is placed clear of ImageAlpha's (below it, else beside it), so
# a drag between the two lands. Only Finder's window moves: ImageAlpha's frame is
# saved in the user's real preferences.
cmd_finder() { # finder <dir|file>: show it in Finder; print a drop point in the folder, or the file's centre
  local frame
  frame=$(window_frame)
  if [ -d "$1" ]; then open "$1"; else open -R "$1"; fi
  sleep 1.5
  # shellcheck disable=SC2086 # the frame splits into four arguments on purpose
  osascript - $frame "$(basename "$1")" "$([ -d "$1" ] && echo folder || echo file)" <<'EOF'
on run argv
  set {ax, ay, aw, ah} to {(item 1 of argv) as integer, (item 2 of argv) as integer, (item 3 of argv) as integer, (item 4 of argv) as integer}
  tell application "Finder" to set {sx, sy, sw, sh} to bounds of window of desktop
  tell application "System Events" to tell process "Finder"
    if sh - (ay + ah) ≥ 220 then
      set position of window 1 to {ax, ay + ah + 10}
      set size of window 1 to {aw, sh - (ay + ah) - 20}
    else if sw - (ax + aw) ≥ 320 then
      set position of window 1 to {ax + aw + 10, ay}
      set size of window 1 to {sw - (ax + aw) - 20, ah}
    else
      set position of window 1 to {0, ay}
      set size of window 1 to {ax - 10, ah}
    end if
    delay 0.5
    set {x, y} to position of window 1
    set {w, h} to size of window 1
    if (item 6 of argv) is "folder" then return ((x + w * 2 div 3) as text) & " " & ((y + h * 2 div 3) as text)
    set c to entire contents of window 1
    repeat with i from 1 to count of c
      set e to item i of c
      if (role of e) as text is "AXTextField" then
        if (value of e) as text is (item 5 of argv) then
          set {ex, ey} to position of e
          set {ew, eh} to size of e
          return ((ex + ew div 2) as text) & " " & ((ey + eh div 2) as text)
        end if
      end if
    end repeat
    error "The file isn't shown in the front Finder window"
  end tell
end run
EOF
}

cmd_fixture() { # fixture: a fresh copy of samples/dice.png to open and overwrite
  mkdir -p "$RUN_DIR/fixtures"
  cp samples/dice.png "$RUN_DIR/fixtures/dice.png"
  echo "$RUN_DIR/fixtures/dice.png"
}

cmd_help() {
  sed -n '/^cmd_[a-z_]*() {/s/^cmd_\([a-z_]*\)() { *#* *\(.*\)/\1  \2/p' "$0" | sed -E 's/^([a-z]+)_([a-z]+)/\1-\2/'
}

command="${1:-help}"
shift || true
handler="cmd_${command//-/_}"
if declare -F "$handler" >/dev/null; then
  "$handler" "$@"
else
  echo "Unknown command: $command" >&2
  cmd_help >&2
  exit 1
fi
