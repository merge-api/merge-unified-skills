#!/usr/bin/env bash
# convert.sh — Convert Claude Code skills to other AI coding tool formats.
#
# Usage:
#   ./scripts/convert.sh --tool all                        # Convert all to dist/
#   ./scripts/convert.sh --tool cursor                     # Cursor only
#   ./scripts/convert.sh --tool cursor --target .          # Install Cursor rules into current project
#   ./scripts/convert.sh --tool aider --target ./my-app    # Install Aider conventions into my-app/
#   ./scripts/convert.sh --list                            # List supported tools
#
# Supported tools: cursor, aider, windsurf, kilocode, opencode, augment, antigravity, hermes
#
# With --target: installs directly into the target project directory.
# Without --target: outputs to dist/<tool>/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
DIST_DIR="$REPO_ROOT/dist"
DATE_TODAY=$(date +%Y-%m-%d)

SUPPORTED_TOOLS="cursor aider windsurf kilocode opencode augment antigravity hermes codex"

# ── Argument parsing ──────────────────────────────────────────────

ACTION=""
TOOL=""
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; ACTION="convert"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --list) ACTION="list"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ "$ACTION" = "list" ]; then
  echo "Supported tools:"
  for t in $SUPPORTED_TOOLS; do echo "  $t"; done
  exit 0
fi

if [ -z "$ACTION" ]; then
  echo "Usage: bash scripts/convert.sh --tool <name|all>"
  echo "       bash scripts/convert.sh --list"
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────

# Extract YAML frontmatter value by key (single-line values only)
extract_fm() {
  local file="$1" key="$2"
  awk "/^---\$/{c++; next} c==1" "$file" | grep "^${key}:" | sed "s/^${key}:[[:space:]]*//" | head -1
}

# Extract multi-line description (handles > block scalar)
extract_description() {
  local file="$1"
  awk '/^---$/{c++; next} c==1' "$file" | awk '
    /^description:/{found=1; sub(/^description:[[:space:]]*/, ""); if($0 != "" && $0 != ">") print; next}
    found && /^[[:space:]]/{sub(/^[[:space:]]+/, ""); printf " %s", $0; next}
    found{found=0}
  ' | sed 's/^[[:space:]]*//'
}

# Extract body content (everything after second ---)
extract_body() {
  local file="$1"
  awk '/^---$/{c++; next} c>=2{print}' "$file"
}

# ── Output directory helpers ───────────────────────────────────────

# Get the output directory for a given tool.
# With --target: installs into the project's native path.
# Without --target: outputs to dist/<tool>/.
get_outdir() {
  local tool="$1"
  if [ -n "$TARGET" ]; then
    local target_abs
    target_abs="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
    case "$tool" in
      cursor)       echo "$target_abs/.cursor/rules" ;;
      aider)        echo "$target_abs" ;;
      windsurf)     echo "$target_abs/.windsurf/skills" ;;
      kilocode)     echo "$target_abs/.kilocode/rules" ;;
      opencode)     echo "$target_abs/.opencode/skills" ;;
      augment)      echo "$target_abs/.augment/rules" ;;
      antigravity)  echo "$target_abs/.gemini/antigravity/skills" ;;
      hermes)       echo "$target_abs/.hermes/skills" ;;
      codex)        echo "$target_abs/.codex/skills" ;;
    esac
  else
    case "$tool" in
      cursor)       echo "$DIST_DIR/cursor" ;;
      aider)        echo "$DIST_DIR/aider" ;;
      windsurf)     echo "$DIST_DIR/windsurf/skills" ;;
      kilocode)     echo "$DIST_DIR/kilocode/rules" ;;
      opencode)     echo "$DIST_DIR/opencode/skills" ;;
      augment)      echo "$DIST_DIR/augment/rules" ;;
      antigravity)  echo "$DIST_DIR/antigravity/skills" ;;
      hermes)       echo "$DIST_DIR/hermes/skills" ;;
      codex)        echo "$DIST_DIR/codex/skills" ;;
    esac
  fi
}

# ── Conversion functions ──────────────────────────────────────────

convert_cursor() {
  local outdir
  outdir="$(get_outdir cursor)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name dir body desc
    dir="$(dirname "$skill")"
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"
    body="$(extract_body "$skill")"

    # Cursor uses .mdc files with specific frontmatter
    cat > "$outdir/${name}.mdc" <<MCEOF
---
name: ${name}
description: ${desc}
globs: ["**/*"]
alwaysApply: true
---

${body}
MCEOF

    # Copy references alongside if they exist
    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/${name}-references"
    fi

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Cursor: $(ls "$outdir"/*.mdc 2>/dev/null | wc -l | tr -d ' ') skill files → $outdir/"
}

convert_aider() {
  local outdir
  outdir="$(get_outdir aider)"
  mkdir -p "$outdir"

  local outfile="$outdir/CONVENTIONS.md"
  echo "# Merge Unified API Skills" > "$outfile"
  echo "" >> "$outfile"
  echo "Generated from merge-unified-skills on ${DATE_TODAY}." >> "$outfile"
  echo "" >> "$outfile"

  while IFS= read -r -d '' skill; do
    local name body
    name="$(extract_fm "$skill" "name")"
    body="$(extract_body "$skill")"

    echo "---" >> "$outfile"
    echo "" >> "$outfile"
    echo "## ${name}" >> "$outfile"
    echo "" >> "$outfile"
    echo "${body}" >> "$outfile"
    echo "" >> "$outfile"

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0 | sort -z)

  echo "  Aider: 1 CONVENTIONS.md → $outdir/"
}

convert_windsurf() {
  local outdir
  outdir="$(get_outdir windsurf)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name dir
    dir="$(dirname "$skill")"
    name="$(basename "$dir")"

    mkdir -p "$outdir/$name"
    cp "$skill" "$outdir/$name/SKILL.md"

    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/$name/references"
    fi

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Windsurf: $(find "$outdir" -name SKILL.md | wc -l | tr -d ' ') skills → $DIST_DIR/windsurf/"
}

convert_opencode() {
  local outdir
  outdir="$(get_outdir opencode)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name dir desc body
    dir="$(dirname "$skill")"
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"
    body="$(extract_body "$skill")"

    mkdir -p "$outdir/$name"

    # Add compatibility field to frontmatter
    cat > "$outdir/$name/SKILL.md" <<OCEOF
---
name: ${name}
description: ${desc}
license: MIT
compatibility: opencode
metadata:
  author: Merge
  version: 0.1.0
---

${body}
OCEOF

    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/$name/references"
    fi

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  OpenCode: $(find "$outdir" -name SKILL.md | wc -l | tr -d ' ') skills → $DIST_DIR/opencode/"
}

convert_augment() {
  local outdir
  outdir="$(get_outdir augment)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name desc body
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"
    body="$(extract_body "$skill")"

    cat > "$outdir/${name}.md" <<AUGEOF
---
name: ${name}
description: ${desc}
type: auto
---

${body}
AUGEOF

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Augment: $(ls "$outdir"/*.md 2>/dev/null | wc -l | tr -d ' ') rule files → $outdir/"
}

convert_antigravity() {
  local outdir
  outdir="$(get_outdir antigravity)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name dir desc body
    dir="$(dirname "$skill")"
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"
    body="$(extract_body "$skill")"

    mkdir -p "$outdir/$name"

    cat > "$outdir/$name/SKILL.md" <<AGEOF
---
name: ${name}
description: ${desc}
license: MIT
risk: low
source: community
date_added: ${DATE_TODAY}
metadata:
  author: Merge
  version: 0.1.0
---

${body}
AGEOF

    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/$name/references"
    fi

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Antigravity: $(find "$outdir" -name SKILL.md | wc -l | tr -d ' ') skills → $DIST_DIR/antigravity/"
}

convert_hermes() {
  local outdir
  outdir="$(get_outdir hermes)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  local index_entries=""

  while IFS= read -r -d '' skill; do
    local name dir desc
    dir="$(dirname "$skill")"
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"

    mkdir -p "$outdir/$name"
    cp "$skill" "$outdir/$name/SKILL.md"

    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/$name/references"
    fi

    # Build index entry
    if [ -n "$index_entries" ]; then
      index_entries="${index_entries},"
    fi
    # Clean description for JSON (strip newlines/tabs, escape quotes, truncate)
    local clean_desc
    clean_desc=$(echo "$desc" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/"/\\"/g' | cut -c1-200)
    index_entries="${index_entries}
    {\"name\": \"${name}\", \"description\": \"${clean_desc}\", \"path\": \"skills/${name}/SKILL.md\"}"

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0 | sort -z)

  # Generate skills-index.json using Python for proper JSON escaping
  python3 -c "
import json, os, sys
sys.path.insert(0, '.')
skills_dir = '$outdir'
skills = []
for name in sorted(os.listdir(skills_dir)):
    skill_path = os.path.join(skills_dir, name, 'SKILL.md')
    if not os.path.isfile(skill_path):
        continue
    # Extract description from frontmatter
    desc = ''
    in_fm = False
    with open(skill_path) as f:
        for line in f:
            if line.strip() == '---':
                in_fm = not in_fm
                if not in_fm and desc:
                    break
                continue
            if in_fm and line.startswith('description:'):
                desc = line.split(':', 1)[1].strip()
                if desc in ('>', '|'):
                    desc = ''
            elif in_fm and desc == '' and line.startswith('  '):
                desc += line.strip() + ' '
    skills.append({
        'name': name,
        'description': desc.strip()[:200],
        'path': f'skills/{name}/SKILL.md'
    })
index = {'version': '0.4.0', 'generated': '${DATE_TODAY}', 'skills': skills}
with open('$DIST_DIR/hermes/skills-index.json', 'w') as f:
    json.dump(index, f, indent=2)
"

  echo "  Hermes: $(find "$outdir" -name SKILL.md | wc -l | tr -d ' ') skills + index → $DIST_DIR/hermes/"
}

convert_kilocode() {
  local outdir
  outdir="$(get_outdir kilocode)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name desc body
    name="$(extract_fm "$skill" "name")"
    desc="$(extract_description "$skill")"
    body="$(extract_body "$skill")"

    # Kilo Code uses .md files in rules/ directory
    cat > "$outdir/${name}.md" <<KCEOF
---
name: ${name}
description: ${desc}
---

${body}
KCEOF

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Kilo Code: $(ls "$outdir"/*.md 2>/dev/null | wc -l | tr -d ' ') rule files → $outdir/"
}

convert_codex() {
  local outdir
  outdir="$(get_outdir codex)"
  rm -rf "$outdir"
  mkdir -p "$outdir"

  while IFS= read -r -d '' skill; do
    local name dir
    dir="$(dirname "$skill")"
    name="$(basename "$dir")"

    mkdir -p "$outdir/$name"
    cp "$skill" "$outdir/$name/SKILL.md"

    if [ -d "$dir/references" ]; then
      cp -r "$dir/references" "$outdir/$name/references"
    fi

  done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -not -path "*/_template/*" -print0)

  echo "  Codex: $(find "$outdir" -name SKILL.md | wc -l | tr -d ' ') skills → $outdir/"
}

# ── Main ──────────────────────────────────────────────────────────

run_conversion() {
  local tool="$1"
  case "$tool" in
    cursor)       convert_cursor ;;
    aider)        convert_aider ;;
    windsurf)     convert_windsurf ;;
    kilocode)     convert_kilocode ;;
    opencode)     convert_opencode ;;
    augment)      convert_augment ;;
    antigravity)  convert_antigravity ;;
    hermes)       convert_hermes ;;
    codex)        convert_codex ;;
    *)            echo "Unknown tool: $tool"; exit 1 ;;
  esac
}

if [ -n "$TARGET" ]; then
  echo "Installing skills for ${TOOL} into ${TARGET}..."
else
  echo "Converting skills to ${TOOL} format..."
fi
echo "================================================"

if [ "$TOOL" = "all" ]; then
  for t in $SUPPORTED_TOOLS; do
    run_conversion "$t"
  done
else
  run_conversion "$TOOL"
fi

echo "================================================"
if [ -n "$TARGET" ]; then
  echo "Done. Skills installed into ${TARGET}/"
else
  echo "Done. Output in dist/"
fi
