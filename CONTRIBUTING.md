# Contributing

Thanks for your interest in contributing to the Merge Unified API skills.

## Reporting issues

If you've found a bug, want to request a new skill or feature, or have a question, please open an issue using the provided templates. For security issues, see [SECURITY.md](SECURITY.md) — do not file a public issue.

## Submitting changes

1. Fork the repository and create a topic branch from `main`.
2. Make focused, well-scoped changes. One concern per pull request keeps review tractable.
3. Run the conversion script locally to sanity-check that your changes still produce valid output for all supported tools:
   ```bash
   ./scripts/convert.sh --tool all
   ```
4. Open a pull request using the provided template. Describe what changed and why, and link any related issue.

## Skill conventions

- Skill files live under `skills/<skill-name>/SKILL.md` with optional `references/` for longer-form material.
- Front-matter must include a clear `description` so Claude can route to the right skill.
- Keep skills task-oriented: the user invokes a skill to accomplish a specific goal, not to read a textbook.
- Code examples should use the official Merge SDKs. Cover the language(s) the skill targets explicitly.

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
