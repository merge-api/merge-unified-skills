#!/usr/bin/env bash
# check-mirrors.sh — verify that skills/ and .claude/skills/ stay in sync.
#
# The repo intentionally maintains two parallel skill paths:
#   - skills/               — what the Claude Code plugin system reads
#   - .claude/skills/       — what is loaded when working IN this repo (dogfooding)
#
# These must be byte-identical, with one exception: .claude/skills/_template/
# is the contributor scaffold and only lives in the .claude/ tree.
#
# This script catches mirror drift before it reaches main. CI runs it on every PR
# that touches either path; contributors can run it locally before pushing.
#
# Exit codes:
#   0  — mirrors are in sync (modulo _template)
#   1  — drift detected; the diff is printed for inspection

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEFT="$REPO_ROOT/skills"
RIGHT="$REPO_ROOT/.claude/skills"

if [ ! -d "$LEFT" ] || [ ! -d "$RIGHT" ]; then
  echo "FAIL  one of the skill paths does not exist:" >&2
  [ -d "$LEFT" ]  || echo "      missing: $LEFT" >&2
  [ -d "$RIGHT" ] || echo "      missing: $RIGHT" >&2
  exit 1
fi

# diff -rq lists every divergence. --exclude=_template skips the contributor
# scaffold which intentionally has no counterpart in skills/.
DRIFT="$(diff -rq --exclude=_template "$LEFT" "$RIGHT" 2>&1 || true)"

if [ -n "$DRIFT" ]; then
  echo "FAIL  mirror drift detected between skills/ and .claude/skills/" >&2
  echo "" >&2
  echo "$DRIFT" >&2
  echo "" >&2
  echo "Fix: cp the authoritative version across, then re-run this script." >&2
  echo "     (skills/ is typically the canonical edit target.)" >&2
  exit 1
fi

echo "OK    skills/ and .claude/skills/ are in sync"
