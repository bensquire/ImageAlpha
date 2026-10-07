#!/usr/bin/env bash
# PostToolUse hook: flag over-long lines in an edited Swift file.
#
# swift-format.sh has just reflowed the file, but swift-format only breaks what it
# can: a long string, a long doc comment or a long `#expect` message stays long,
# and those are exactly the lines an agent writes. So every line is measured
# against .swift-format's `lineLength` after formatting, and the offenders are
# reported with their widths so the fix needs no second pass to find them.
#
# Advisory (exit 2) rather than blocking, so a long line never stops an edit.
set -euo pipefail

# shellcheck source=.claude/hooks/hook-lib.sh
source "$(dirname "$0")/hook-lib.sh"

file="$(hook_file_path)"

case "$file" in
  *.swift) : ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# The limit is .swift-format's `lineLength`, read from the config so the two can't
# drift; 110 is the fallback if the config is missing or unparseable.
config="${CLAUDE_PROJECT_DIR:-.}/.swift-format"
limit=110
if [ -f "$config" ]; then
  parsed="$(
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("lineLength",""))' \
      "$config" 2>/dev/null || true
  )"
  case "$parsed" in
    '' | *[!0-9]*) : ;;
    *) limit="$parsed" ;;
  esac
fi

# Counted in characters, not bytes: these sources carry em dashes, subscripts and
# superscripts in their prose, and a byte count would flag a formula three
# characters short of the limit.
findings="$(
  python3 -c '
import sys
limit = int(sys.argv[2])
for number, line in enumerate(open(sys.argv[1], encoding="utf-8", errors="replace"), 1):
    width = len(line.rstrip("\n"))
    if width > limit:
        print(f"  {number}: {width} columns")
' "$file" "$limit" 2>/dev/null || true
)"

if [ -n "$findings" ]; then
  {
    echo "Lines over $limit columns in $file:"
    printf '%s\n' "$findings"
    echo "  Reflow them — swift-format could not break these on its own."
  } >&2
  exit 2
fi

exit 0
