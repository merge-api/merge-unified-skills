---
name: post-connection-build-settings-page
description: >
  Build the dedicated integration settings page that lets end users manage their
  connected integrations — view connection health, reconnect/relink, configure
  per-integration settings (sync scope, field mappings, data filters, writeback
  behavior), and track setup completeness. Use as Step 2 of post-connection
  implementation. Use when a developer says "build settings page", "integration
  settings", "configure integration", "sync scope", "field mappings",
  "writeback configuration", or "setup completeness" for a Merge integration.
license: MIT
metadata:
  author: Merge
  version: 0.3.0
---

# Building the Integration Settings Page

This is the **single home** for everything an end user does with a connected integration after the initial Merge Link flow: see whether it's healthy, reconnect when it breaks, and configure how data syncs. Treating the UI page and its persistence model as one artifact prevents silent failure modes (credentials expire, settings drift, partial setup looks "done").

## Purpose

A dedicated settings page prevents "silent failure" — credentials expire, permissions change, customer requirements differ, and end users need a self-service way to fix and configure their integration without filing a support ticket. This page is the persistent home for integration configuration, not a one-time setup wizard.

## Prerequisites

- All four backend endpoints from `link-implement-backend` working — these are routes on **your** server (e.g., `/api/merge/create-link-token`), not Merge API endpoints
- A backend able to add either a new `integration_settings` table or a `jsonb`/JSON column on `linked_accounts`

## Before Proceeding

Three pieces of information are needed before generating any code.

If invoked from `implementing-post-connection`, these were answered in Step 1 — use that context. Otherwise, gather them now:

**Step 1 — Confirm or gather required context:**

- **Categories**: Which Merge categories does the settings page need to display? (`hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`)
- **Frontend framework**: React, Vue, Svelte, or vanilla? Drives the component pattern below.
- **`linked_accounts` schema**: which columns are already present (`status`, `error_category`, `initial_sync_complete`)?

**Step 2 — Frontend pre-scan:**

Search the frontend for an existing settings, account, admin, integrations, or preferences page (filenames or routes). If found, identify the exact file and where an "Integrations" section would be inserted.

- If an existing page is found: confirm with the user — "I found `{file}` as your existing settings/account page. I'll insert an Integrations section there. Is that correct?"
- If no existing page is found: ask — "I didn't find an existing settings or account page. Do you have design mockups? If not, I can generate a new page matching the visual style of your existing pages."

**Step 3 — Confirm approach before writing any UI code:**

- If an existing page was found: modify that file rather than creating a new one.
- If mockups were provided: implement to spec, matching the app's component library.
- If no page and no mockups: generate a new page matching the visual style of existing pages. Do not introduce new dependencies without asking.

## Page structure: four components

A single page combines health, relinking, configurable settings UI, and the settings persistence backend. Build them in this order — each builds on the previous.

### Component 1: Connection health banner

Fetch account status from `linked_accounts` in your DB, supplemented by `GET https://api.merge.dev/api/{category}/v1/account-details` (with `Authorization` and `X-Account-Token` headers) for live connection health.

**`account-details` response — key fields for the health banner:**

| Field | Type | Notes |
|---|---|---|
| `status` | string | `"COMPLETE"`, `"INCOMPLETE"`, `"RELINK_NEEDED"` |
| `integration` | string | Provider name (plain string) |
| `integration_slug` | string | Provider slug |
| `end_user_origin_id` | string | Your user ID |

⚠️ Wrap this call in error handling — `401` means the `account_token` is invalid (show "Broken" state + reconnect button). `429` means rate limited (retry with backoff).

Render one of three states:

- **Connected** (green) — auth valid, sync running normally
- **Needs Attention** (yellow) — partial sync, missing permissions, or degraded access
- **Broken** (red) — auth failure; user must relink

Always show: integration name, integration logo, and last sync time.

### Component 2: Reconnect / Relink button

- **Strongly recommended:** keep this button always visible, not only when the connection is broken. Users lose trust if they can't find reconnect until something breaks.
- On click: call `POST /api/merge/relink-integration` to get a fresh link token, then open the Merge Link modal.
- On successful relink: refresh the health banner without a full page reload.
- Button label: "Reconnect [Integration Name]" — not "Reconnect via Merge".

### Component 3: Configurable settings panel (UI)

Render integration-specific settings as editable form fields. The panel surfaces what's stored in your settings table (Component 4); this component is the UI on top.

UI requirements:

- Settings must be editable **after** initial setup — not a one-time wizard.
- Show a visible **"Setup incomplete"** badge when required settings are missing.
- Save **immediately on change** (not only on form submit) so partial configurations are captured.
- For each setting: show the current value, allow editing, and indicate which settings are required vs. optional.

Common setting categories to surface (pick the ones relevant to your use case):

- **Sync scope / selective sync** — Which objects to include. Prompt: "Which data should we sync?" with checkboxes (e.g., Basic Info, Employment Details, Time Off, Payroll for HRIS; Contacts, Accounts, Opportunities for CRM).
- **Field mappings** — Map Merge common model fields to your internal fields. Example: `Employee.work_email` → `users.email`.
- **Data filters** — Rules for which records to include (e.g., active records only, specific departments, deal stages).
- **Writeback behavior** — If your product writes data back, configure which fields, direction (read-only / one-way / two-way), and validation rules.
- **Default objects** — For accounting integrations: chart of accounts, fiscal year, currency selection.

### Component 4: Settings persistence & API (backend)

Track per-account settings and a `setup_complete` state so partially configured integrations don't silently misbehave.

**Setup completeness state** — per linked account:

- **Values:** `incomplete` / `in_progress` / `complete` (or a boolean if your needs are simpler).
- Show a "Setup incomplete" badge in the UI when required settings are missing.
- Block or warn before data syncs until required settings are configured.
- Recalculate the state whenever any setting changes.

**Database schema.** Pick one of two shapes; ask the user before generating the migration:

> "I'll add an `integration_settings` table (or a `jsonb` column on `linked_accounts`) to store per-account settings. Which would you prefer — a separate table or a JSON column?"

Separate table (recommended for queryable settings):

| Column | Type |
|---|---|
| `linked_account_id` | FK to `linked_accounts(id)` |
| `setting_key` | string |
| `setting_value` | `jsonb` |
| `updated_at` | timestamp |

JSON column on `linked_accounts` (recommended for opaque blobs):

```sql
ALTER TABLE linked_accounts ADD COLUMN settings jsonb DEFAULT '{}'::jsonb;
ALTER TABLE linked_accounts ADD COLUMN setup_complete text DEFAULT 'incomplete';
```

**API endpoints** (add these to **your** server — they are not Merge API endpoints):

- `GET /api/merge/settings?linked_account_id={id}` — return current settings and `setup_complete` state for the linked account.
- `PATCH /api/merge/settings` — update one or more settings; recalculate `setup_complete` after each change.

After every `PATCH`, re-evaluate which required settings are present and update `setup_complete` accordingly.

## UX requirements

- Reconnect CTA is recommended to always be available, even when the connection is healthy.
- Error states are actionable: show what's wrong, who must fix it (end user / admin / support), and what to do next — never generic "something went wrong".
- This page is the **home** for configuration — users return here to update settings, not just during initial setup.
- Required-vs-optional is visually clear; required missing settings drive the "Setup incomplete" indicator.

## Testing checklist

- [ ] Settings page loads with current connection status from both your DB and `account-details`
- [ ] Reconnect button is visible at all times (not only on error)
- [ ] Relink flow opens Merge Link modal and updates health banner on success
- [ ] Health banner shows actionable state (not generic "error")
- [ ] Settings panel shows "Setup incomplete" when required config is missing
- [ ] All settings are editable after initial setup
- [ ] Settings save immediately on change (not only on form submit)
- [ ] `setup_complete` state updates correctly when all required settings are filled
- [ ] Settings persist across sessions
- [ ] `GET /api/merge/settings` and `PATCH /api/merge/settings` both work
