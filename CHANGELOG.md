# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.2.0] — 2026-04-16

### Added

- New skill: `merge-validate` — run diagnostic checks against a live Merge integration (API key, account_token, sync status, data access, pagination).
- New skill: `migrate-from-apideck` — detect Apideck usage, map concepts to Merge equivalents, rewrite API calls, and highlight behavioral differences.
- Chaining: `merge-onboarding` now suggests running `merge-validate` after the production checklist.

### Fixed

- Python SDK import: `from MergePythonClient import Merge` → `from merge import Merge` (matches actual SDK).
- Replaced nonexistent `merge-kotlin-client` with correct `merge-java-client` artifact.
- Added Go, Ruby, C# SDK quickstart sections (verified against each repo README).
- Extended SDK feature parity table to all 6 languages.
- Removed internal source paths from common-models.md.
- Fixed README overclaim about language auto-detection.

## [0.1.0] — 2026-04-15

### Added

- Initial repo scaffold.
- Plugin + marketplace metadata in `.claude-plugin/`.
- First skill: `merge-onboarding` — signup → working Linked Account, with reference docs for auth flow, common models, SDK quickstarts, and webhooks.
- `_template/` reference skill for contributors.
- `scripts/check-skill.sh` validator + CI workflow.
- Contributor docs: `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`.
