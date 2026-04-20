#!/usr/bin/env bash
# check-skill.sh — validate every SKILL.md under skills/ (plugin path) has required frontmatter.
# Also checks .claude/skills/ (manual install path).
# Required keys: name, description.
# Recommended (warned if missing): metadata.author, metadata.version.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXIT=0

for SKILLS_DIR in "$REPO_ROOT/skills" "$REPO_ROOT/.claude/skills"; do
  if [ ! -d "$SKILLS_DIR" ]; then
    continue
  fi

  while IFS= read -r -d '' skill; do
    rel="${skill#$REPO_ROOT/}"

    # Extract YAML frontmatter (between first two `---` lines).
    fm="$(awk '/^---$/{c++; next} c==1' "$skill")"

    if [ -z "$fm" ]; then
      echo "FAIL  $rel  (no YAML frontmatter)"
      EXIT=1
      continue
    fi

    for key in name description; do
      if ! grep -qE "^${key}:" <<<"$fm"; then
        echo "FAIL  $rel  (missing required key: $key)"
        EXIT=1
      fi
    done

    for key in author version; do
      if ! grep -qE "^[[:space:]]+${key}:" <<<"$fm"; then
        echo "WARN  $rel  (missing recommended metadata.$key)"
      fi
    done

    if [ $EXIT -eq 0 ]; then
      echo "OK    $rel"
    fi
  done < <(find "$SKILLS_DIR" -type f -name SKILL.md -print0)
done

exit "$EXIT"
