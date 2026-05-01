# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.6.0] — 2026-05-01

Post-link friction pass. Surfaced from a from-scratch developer build of a ticketing app that hit ~14 distinct gaps where skills were silent, ambiguous, or pointed at the wrong place. All edits target the first 30 minutes after the connect button works — the period most likely to make a developer abandon.

### Fixed

- `merge-onboarding` (v0.3.0): scope-config URL pointed to nonexistent `/common-models/{category}` (3 sites: production checklist, troubleshooting); corrected to `/configuration/common-model-scopes`, aligning with `merge-validate`.

### Added

- `merge-onboarding` (v0.3.0) Step 4: callout that real-named integrations behave like Test in test mode — auto-auth, shared demo dataset, no cross-customer isolation visible with a test key.
- `merge-onboarding` (v0.3.0) Step 4: orphan-Linked-Account race in `onSuccess` — Merge creates the account on its side regardless of whether `/exchange` runs. Recommend `linked_account.created` webhook as the source-of-truth backstop.
- `merge-onboarding` (v0.3.0) Step 5: try/catch around `accountToken.retrieve` (a stale `public_token` throws `MergeError 404` and crashes unhandled), plus dev-server `unhandledRejection`/`uncaughtException` handlers as a backstop.
- `merge-onboarding` (v0.3.0) Step 6: write-operation response shape `{ model, warnings, errors }`. Provider field requirements not in the Common Model surface as `result.warnings` (no thrown error). GitLab tickets need `collections` — concrete worked example.
- `merge-onboarding` (v0.3.0) Step 6: reinforce that `X-Account-Token` is required on writes too, not just reads.
- `merge-onboarding` (v0.3.0) Step 7: tunnel-hostname rotation warning (cloudflared quick mode + ngrok free tier rotate on every restart, breaking emitter URLs); recommend named/reserved tunnels for repeated dev work. Emitter-vs-receiver terminology clarified.
- `merge-onboarding` (v0.3.0) Step 8 + sidebar: "Default scopes are minimal" warning — fresh Ticketing org has User, Account, Project, Comment, Attachment, Viewer disabled; common ticketing-dashboard scopes need flipping. "Multiple integrations same category" sidebar — codifies the `${customer_id}:${integration_slug}` disambiguator and warns against random/counter suffixes.
- `merge-onboarding` (v0.3.0) Troubleshooting: 4 new SYMPTOM/CAUSE/FIX entries — orphan-after-OAuth, duplicate-on-Reconnect, Delete-then-Reconnect-creates-new-account, silent write warnings.
- `merge-link-implement-backend` (v0.2.0): explicit reconnect data-flow code example — pull the broken row's exact `end_user_origin_id` and reuse it in the `link_token.create` call. Codified the deterministic `end_user_origin_id` rule (no random/counter suffixes).
- `merge-link-setup-database` (v0.2.0): `account_token` column should be `TEXT`, not a fixed `VARCHAR`; tokens can exceed 100 chars and tight columns truncate silently in some drivers.
- `merge-post-connection-implement-relinking` (v0.2.0): "Two relink paths" distinction — credentials revoked at source preserves `merge_account_id`; Linked Account deleted from dashboard creates a new one. "Delete + Reconnect" is not equivalent to "Reconnect."
- `implementing-merge-sync` (v0.2.0) and the polling skills (initial v0.2.0, subsequent v0.2.0), plus `references/sync-fundamentals.md` and `references/platform-overview.md`: top-of-doc callout that pseudo-code uses snake_case (HTTP shape) while SDKs return camelCase. No pseudo-code rewritten — callout disambiguates.

## [0.4.2] — 2026-04-27

### Changed

- `oncall-handoff` (v0.3.2): Title format aligned to the team's `@Month Day, Year` convention (e.g. `@April 27, 2026`) — previously `On-Call Handoff — Month Day, Year`. In Notion mode the title is set on the `Handoff date` property and not duplicated in page content.
- `oncall-handoff` (v0.3.2): Step 6 "Notion mode mechanics" now spells out the required `notion-fetch` → `data_source_id` → `notion-create-pages` flow (instead of the misleading "use database ID as parent"), which the create-pages tool rejects.

## [0.4.1] — 2026-04-27

### Changed

- `oncall-handoff` (v0.3.1): Notion is now the only routine output target. Local markdown file output is reserved as a fallback for when the Notion connector is unreachable. Removed the routine "Notion or local file?" prompt from first activation and the "user explicitly requested local" branch from Step 2.

## [0.4.0] — 2026-04-20

### Added

- New skill: `implementing-merge-link` — full Merge Link implementation guide (database schema, backend endpoints, frontend connect button and marketplace UI).
- New skill: `implementing-merge-sync` — sync trigger implementation via polling and webhooks, covering initial and incremental syncs.
- New skill: `implementing-merge-post-connection` — post-connection management (settings page, sync status, relinking, configuration, custom fields, HRIS filtering).
- 15 focused sub-skills covering each implementation step independently:
  - `merge-link-set-context`, `merge-link-setup-database`, `merge-link-implement-backend`, `merge-link-implement-frontend-connect`, `merge-link-implement-frontend-marketplace`
  - `merge-sync-set-context`, `merge-sync-implement-initial-polling`, `merge-sync-implement-initial-webhooks`, `merge-sync-implement-subsequent-polling`, `merge-sync-implement-subsequent-webhooks`
  - `merge-post-connection-set-context`, `merge-post-connection-build-settings-page`, `merge-post-connection-surface-sync-status`, `merge-post-connection-implement-relinking`, `merge-post-connection-configure-integration-settings`, `merge-post-connection-enable-custom-fields`, `merge-post-connection-hris-employee-filtering`

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
