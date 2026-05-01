# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.7.4] — 2026-05-01

Pre-release scan pass before sharing with prospects. External-doc verification turned up that `docs.merge.dev` migrated its URL structure under `/merge-unified/...`, breaking ~14 reference links in skill documentation. Also caught two example email addresses on the `merge.dev` domain (one a real internal address, the other a generic `test@`) and a couple of small typos in repo conventions.

### Fixed

- **Broken docs.merge.dev links (14 paths).** The Merge documentation site restructured under a `/merge-unified/...` namespace. Old paths under `/basics/`, `/guides/`, `/hris/`, `/merge-unified/link/`, and `/supplemental-data/` all 404. Each old URL was remapped to its current home, verified with a live fetch or the live sitemap. Includes the singular→plural shift in the field-mapping section (`field-mappings/` → `field-mapping/`) and the move from anchor URLs to dedicated endpoint pages (`/hris/sync-status/#sync_status_list` → `/merge-unified/hris/data-management/sync-status/list`). Affects `skills/implementing-merge-post-connection/references/post-connection-fundamentals.md` (13 URLs) and `skills/merge-onboarding/SKILL.md` (1 URL, retargeted to docs root since the surrounding label is generic "Merge docs").
- **Example email addresses on the `merge.dev` domain.** `skills/implementing-merge-link/references/backend-implementation.md` had a real internal address (`ashwin.prakash@merge.dev`) and an `end_user_organization_name` of `"Merge"` in a worked sample. `skills/implementing-merge-post-connection/references/post-connection-fundamentals.md` used `test@merge.dev` as a generic placeholder. Replaced with `customer@example.com` and `Acme Corp` so prospects don't see real Merge personnel data in worked examples.
- **`CLAUDE.md`: duplicate step number** — the "When asked to add a skill" list had `1, 2, 3, 3, 4, 5`. Renumbered to `1–6`.
- **`.github/workflows/claude.yml` review prompt** — referenced `skills/_template/SKILL.md` (which doesn't exist; the template is intentionally only mirrored in `.claude/skills/_template/`). Updated to point at the correct path with the rationale inline.

Customer-readiness pass. Eleven concrete inconsistencies and ambiguities surfaced from a final pre-ship audit. None are show-stoppers, but every one is the kind of friction that costs a developer 10–30 minutes of confusion or a support ticket.

### Fixed

- `implementing-merge-link` (v0.3.0): troubleshooting entry referenced the nonexistent npm package `@mergeapi/merge-link`. Verified against npm registry — only `@mergeapi/react-merge-link` exists. Entry now distinguishes the React package vs the vanilla CDN script (`https://cdn.merge.dev/initialize.js`).
- `merge-onboarding` (v0.5.0) — Step 5 Linked Account states: previously documented the lowercase `pending`/`active`/`relink_needed`/`incomplete` values as if they were Merge API states. They aren't — those are the local DB convention used in the example schemas. Merge API returns **uppercase** `COMPLETE`/`INCOMPLETE`/`RELINK_NEEDED`/`IDLE` (matches `references/auth-flow.md`). Customers checking `payload.status === "active"` from a webhook would never match. Now clearly distinguishes the two.
- `references/auth-flow.md` + `references/sdk-quickstarts.md`: `link_expiry_mins` documented as "Default 30. Max 30." Actual range is 30–720 minutes (12 h) standard, up to 10080 (7 days) with `should_create_magic_link_url`. Customers needing longer sessions were told they couldn't have them. Aligned both files with the parent SKILL.
- `merge-post-connection-enable-custom-fields` (v0.2.0): description said "Step 6 of post-connection" but parent calls it Step 5. Aligned.
- Webhook timeout: SKILL.md and two `platform-overview.md` references said 30s; the dedicated `references/webhooks.md` says 10s with "respond under 5s." Aligned all five sites to **10s timeout, ACK in <5s, 5 retries over ~1h with exponential backoff**.
- `merge-onboarding` (v0.5.0) Step 6: hardcoded `merge.crm.contacts.list` examples without the "replace `.crm` with your category" disclaimer that every earlier step carries. HRIS/ATS/Ticketing customers copy-pasting would silently query the wrong category and get empty arrays with no error. Disclaimer + inline `// replace .crm + .contacts` comments restored.
- `public_token` TTL documented three different ways (`~minutes`, `~10 min`, `30 minutes`). Aligned to **~10 min** with synchronous-exchange guidance everywhere.
- `merge-onboarding` (v0.5.0) Step 6 first-API-call: silently assumed `account_token` was already in scope. Added one-line "Where does `account_token` come from?" callout pointing at Step 5 persistence or the Test Linked Accounts dashboard.
- `README.md` Multi-Tool Support table: said Antigravity/Hermes install at `~/.gemini/...` and `~/.hermes/...` but `convert.sh` writes to `<target>/.gemini/...` and `<target>/.hermes/...` (project-relative, not home-relative). Updated to show both options with the explicit `--target $HOME` invocation for the user-global path.

### Added

- `CHANGELOG.md`: backfilled entries for `v0.5.0` (onboarding rewrite + 47-item audit pass) and `v0.4.3` (8-bug customer-simulation fix + inline schemas), based on git log of commits between bumps.

## [0.7.2] — 2026-05-01

Pre-customer hygiene fixes.

### Fixed

- `implementing-merge-post-connection/references/post-connection-fundamentals.md`: a sample webhook payload had a stale test endpoint as the `target` value; replaced with the standard `yourapp.com/webhooks/merge` placeholder used in sibling reference files so the sample reads consistently across the repo.
- `CHANGELOG.md`: removed two entries (`[0.4.2]` and `[0.4.1]`) that documented changes to a skill which was briefly in this repo and later removed. Those entries described internal-only conventions and tooling that aren't part of the customer-facing Merge Unified API skill set.

## [0.7.1] — 2026-05-01

Focus pass plus mirror-discipline guardrail. Drops the standalone Apideck migration tool to keep this repo focused on the Merge Unified API teaching surface, and adds CI enforcement that the `skills/` and `.claude/skills/` mirrors stay byte-identical.

### Removed

- `migrate-from-apideck` (skill) and its references (`apideck-patterns.md`, `concept-mapping.md`) — removed to keep the repo focused on the Merge Unified API. The Apideck → Merge migration tool sat outside the unified-API teaching surface this repo is meant to ship. The negative-trigger callout in `merge-onboarding`'s description ("Do NOT activate for ... questions about other unified API providers (Apideck, Finch, Codat, Kombo, Nango)") stays in place to deflect unrelated questions.

### Added

- `scripts/check-mirrors.sh` — verifies `skills/` and `.claude/skills/` are byte-identical (excluding `_template/`, which is contributor scaffolding and intentionally only lives in `.claude/skills/`). Wired into the existing `validate-skills.yml` CI workflow as a second job; also runnable locally.
- `validate-skills.yml` workflow path triggers expanded to include `skills/**` (previously only triggered on `.claude/skills/**` changes — a path bug that meant edits to `skills/` could ship without frontmatter validation).

### Fixed

- Mirror drift in 4 reference files left over from commit `846dbcb` ("Fix code block language tags across skills and reference docs"), which updated only `skills/` and missed the `.claude/skills/` copies. The drift was invisible until the new `check-mirrors.sh` caught it. Files reconciled by copying `skills/` → `.claude/skills/`:
  - `implementing-merge-link/references/backend-implementation.md`
  - `implementing-merge-link/references/platform-overview.md`
  - `implementing-merge-post-connection/references/post-connection-fundamentals.md`
  - `merge-onboarding/references/auth-flow.md`
- `README.md`: dropped the "Migrate from Apideck" example trigger and the table row; refreshed the post-consolidation skill descriptions for the three orchestrators (the table was still describing the pre-0.7.0 5-step / 7-step / per-approach-sub-skill structure); corrected stale "23 skills" count to "16 skills" in the Multi-Tool Support section.

## [0.7.0] — 2026-05-01

Skill consolidation pass. Reduced the surface from 23 functional skills (24 with `_template`) to 17 (18 with `_template`) by folding thin context-loading stubs into their parent orchestrators, merging structurally identical sync variants, combining the two settings skills, and generalizing the HRIS-only filtering skill to cover all categories. No content lost — every step still has a home, just inside fewer skills. Vertical bias reduced: data-scope filtering now covers HRIS, ATS, CRM, Ticketing, and Accounting on equal footing.

### Removed

- `merge-link-set-context`, `merge-post-connection-set-context`, `merge-sync-set-context` — folded into Step 1 of their parent `implementing-merge-{link,post-connection,sync}` orchestrators. The three were structurally identical "read these docs, scan codebase, confirm readiness" stubs; promoting them inline removes a layer of indirection without losing the procedure.
- `merge-sync-implement-initial-polling`, `merge-sync-implement-subsequent-polling` — merged into a single `merge-sync-implement-polling` skill that covers both phases. Same job branches on `initial_sync_complete`.
- `merge-sync-implement-initial-webhooks`, `merge-sync-implement-subsequent-webhooks` — merged into a single `merge-sync-implement-webhooks` skill. Same endpoint handles initial and subsequent events.
- `merge-post-connection-configure-integration-settings` — folded into `merge-post-connection-build-settings-page`. The settings page (UI) and its persistence model are now treated as one artifact; builders think of "the settings page" as one thing.
- `merge-post-connection-hris-employee-filtering` — replaced by the category-agnostic `merge-post-connection-data-scope-filtering` (see Added).

### Added

- New skill: `merge-sync-implement-webhooks` (v0.1.0) — production-recommended sync trigger via a single Merge webhook endpoint. Covers initial and subsequent syncs in one place with HMAC-SHA256 verification, async background processing, and bounded `modified_after` / `modified_before` fetches. Description and self-introduce explicitly position webhooks as primary and polling as fallback.
- New skill: `merge-sync-implement-polling` (v0.1.0) — single scheduled job covering both initial sync detection and subsequent incremental fetches. Framed as a development starting point and a production fallback alongside webhooks, not as an equal alternative.
- New skill: `merge-post-connection-data-scope-filtering` (v0.1.0) — same pre-storage vs post-storage decision framework as the deleted HRIS-only skill, but with parallel filter parameter tables for HRIS (employee filtering), ATS (candidate / application), CRM (account / contact / opportunity), Ticketing (project / status / priority / assignee), and Accounting.

### Changed

- `implementing-merge-link` (v0.2.0): Step 1 now runs inline instead of invoking a separate `merge-link-set-context` skill. Step 2–4 unchanged.
- `implementing-merge-post-connection` (v0.2.0): Step 1 inlined. Step 2 is now the consolidated settings skill (build + configure together). Step 7 (HRIS-only filtering) replaced by Step 6 (category-agnostic data-scope filtering); description updated accordingly.
- `implementing-merge-sync` (v0.3.0): Step 1 inlined. Step routing reorganized from 2a/2b/3a/3b (initial/subsequent × polling/webhooks) to 2a (webhooks PRIMARY) + 2b (polling fallback) + Step 3 (run both for production reliability). Frontmatter description and self-introduce both lead with the webhooks-primary framing.
- `merge-post-connection-build-settings-page` (v0.2.0): Absorbed the configure-integration-settings backend (settings persistence, `setup_complete` state, GET/PATCH `/api/merge/settings` endpoints) as Component 4. The UI and the persistence model now ship together.
- `merge-onboarding` (v0.4.0): Stale `v0.2.0` self-introduce string corrected to `v0.4.0`. Connect-button code example genericized from "Connect your CRM" to "Connect your provider" with a category-substitution comment. No other content changes.
- `merge-link-setup-database`, `merge-post-connection-enable-custom-fields`: Cross-references to the deleted set-context skills updated to point at Step 1 of the parent orchestrator.

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

## [0.5.0] — 2026-04-30

Onboarding skill rewrite + cross-skill audit pass. ~47 audit items addressed across `merge-onboarding`, the implementation skills, and reference docs.

### Changed

- `merge-onboarding` (v0.2.0): full rewrite — new step structure, embedded SDK + HTTP examples for every API call, `Troubleshooting` section with SYMPTOM/CAUSE/FIX entries, hardcoded provider names removed in favor of category-substitution comments.
- 13 implementation skills + 4 reference docs: inline schemas instead of "see the docs"; SDK type warnings (e.g., `account-token.integration` is an SDK model, `account-details.integration` is a string); error handling patterns added.

### Fixed

- Documented `link_token` expiry ranges (default 30, max 720, up to 10080 for Magic Link).
- Clarified `public_token` TTL is short and to exchange synchronously inside `onSuccess`.
- Removed an internal `AUDIT_FIXES.md` working doc that wasn't intended to ship.

## [0.4.3] — 2026-04-29

Two follow-up fixes after a customer simulation run on `merge-onboarding`.

### Fixed

- `merge-onboarding`: 8 bugs surfaced by an end-to-end customer build (token-flow ordering, response shape mismatches, frontend gating, error handling).
- Inline response schemas + SDK type warnings backfilled into the implementation skills; skill-writing principles documented in `CONTRIBUTING.md`.

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
