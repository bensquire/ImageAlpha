#!/usr/bin/env bash
# PostToolUse hook: format an edited Swift file with swift-format, against the
# repo's .swift-format — the formatting authority. Running it on every edit keeps
# the tree formatted by construction, so formatting never shows up as a diff of
# its own.
#
# Reads the hook payload (JSON) on stdin; formats only *.swift files. Always
# exits 0 so a formatting hiccup never blocks the edit.
set -euo pipefail

# shellcheck source=.claude/hooks/hook-lib.sh
source "$(dirname "$0")/hook-lib.sh"

file="$(hook_swift_file)"
[ -n "$file" ] || exit 0

# Xcode's toolchain carries swift-format; a bare one on PATH will do too.
# Absent both, silently skip.
if command -v xcrun >/dev/null 2>&1 && xcrun --find swift-format >/dev/null 2>&1; then
  swift_format=(xcrun swift-format)
elif command -v swift-format >/dev/null 2>&1; then
  swift_format=(swift-format)
else
  exit 0
fi
"${swift_format[@]}" format -i --configuration "${CLAUDE_PROJECT_DIR:-.}/.swift-format" "$file" >/dev/null 2>&1 || true

exit 0
