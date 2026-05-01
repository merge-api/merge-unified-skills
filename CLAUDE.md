# CLAUDE.md — repo conventions

Context for Claude Code working in `merge-unified-skills`. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the full contributor guide; this file gives Claude the short version.

## What this repo is

A Claude Code plugin packaging skills for the [Merge Unified API](https://docs.merge.dev/).

## Layout in one paragraph

Plugin metadata in `.claude-plugin/{plugin,marketplace}.json`. Skills under `skills/<name>/SKILL.md` (for the plugin system) and mirrored under `.claude/skills/<name>/SKILL.md` (for manual install). Long supporting docs in `<name>/references/*.md`. Validator at `scripts/check-skill.sh`. CI at `.github/workflows/validate-skills.yml`. Reference skeleton for new skills at `.claude/skills/_template/`.

## When asked to add a skill

1. Copy `.claude/skills/_template/` to `skills/<new-skill-name>/`.
2. Copy the same to `.claude/skills/<new-skill-name>/` (for manual install path).
3. Edit `SKILL.md` frontmatter: `name`, `description` (with many trigger phrases), `metadata.author: Merge`, `metadata.version: 0.1.0`.
4. Move long content into `references/*.md`.
5. Run `bash scripts/check-skill.sh` before committing.
6. Bump version in `.claude-plugin/plugin.json` and add a `CHANGELOG.md` entry.

Read `.claude/skills/merge-onboarding/SKILL.md` as the reference for how a finished skill looks: clear "When to use", explicit step-by-step body, embedded SDK + HTTP examples, Troubleshooting section with SYMPTOM/CAUSE/FIX entries.

## Style rules

- **No personal names in user-facing files.** Use "Merge" as author/owner. (Git commit history is fine — that's separate.)
- **Default to Merge's test environment** in every example.
- **Show both SDK and HTTP examples** for any API call (developers come from both worlds).
- **Embed real values** (real endpoint paths, real schema field names) — never hand-wave to "see the docs".

## Don't do

- Don't flip this repo from private to public; use the orphan-branch publish flow in CONTRIBUTING.md.
- Don't add package.json, bun, or build tooling unless we actually need it. Keep the repo lean.
- Don't bundle multiple new skills into one PR.
