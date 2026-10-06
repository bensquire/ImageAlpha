#!/usr/bin/env bash
# PostToolUse hook: lint an edited Swift file with SwiftLint against the repo's
# .swiftlint.yml. swift-format.sh has already formatted the file; this catches
# what swift-format cannot — a line still over 150 columns (a long string or doc
# comment it can't break), a naming or size rule — at edit time, not in review.
#
# Reads the hook payload (JSON) on stdin; lints only *.swift files. Advisory:
# findings go back to Claude (exit 2) rather than blocking the edit. Skipped if
# swiftlint is absent.
set -euo pipefail

# shellcheck source=.claude/hooks/hook-lib.sh
source "$(dirname "$0")/hook-lib.sh"

file="$(hook_swift_file)"
[ -n "$file" ] || exit 0
command -v swiftlint >/dev/null 2>&1 || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}"

# --strict so a warning counts; --quiet drops the progress banner so only
# findings reach stderr.
findings="$(swiftlint lint --strict --quiet -- "$file" 2>/dev/null || true)"

if [ -n "$findings" ]; then
  {
    echo "SwiftLint flagged $file:"
    printf '%s\n' "$findings" | sed 's/^/  /'
    echo "  (Fix these before handing over; the rules left on in .swiftlint.yml are the ones that matter here.)"
  } >&2
  exit 2
fi

exit 0
