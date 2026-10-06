#!/usr/bin/env bash
# Shared helpers for this repo's Claude Code hooks. Sourced, never executed, and
# side-effect-free at source time — each hook still owns its own `set -euo
# pipefail` and its own exit policy.
#
# Adapted from AssemblyAI/blurt's hooks (MIT), by way of Prospect.

# Echo the `tool_input.file_path` from the hook payload on stdin, or nothing when
# the payload has no file path (a non-file tool) or can't be parsed. The one
# definition of the payload contract: every hook reads the same field.
hook_file_path() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
    2>/dev/null || true
}

# Echo the edited file's path if it is a Swift file that still exists, or
# nothing — the one guard both hooks need.
hook_swift_file() {
  local file
  file="$(hook_file_path)"
  case "$file" in
    *.swift) [ -f "$file" ] && echo "$file" ;;
  esac
  return 0
}
