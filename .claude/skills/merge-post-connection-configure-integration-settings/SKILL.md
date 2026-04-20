---
name: merge-post-connection-configure-integration-settings
description: Implement a post-linking configuration flow that prompts customers to finalize settings required for their use case — sync scope, data mappings, writeback behavior. Use as Step 5 of post-connection implementation.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Configure Integration Settings

Every customer has different needs — which data to sync, how to map fields, whether to write data back. A post-linking settings flow captures these decisions and tracks setup completeness so partially configured integrations don't silently misbehave.

## Prerequisites

`merge-post-connection-build-settings-page` complete — settings page exists as the home for these settings.

## Core concept: Setup completeness

Track a `setup_complete` state per linked account:

- **Values**: `incomplete` / `in_progress` / `complete` (or a boolean)
- Show a "Setup incomplete" badge when required settings are missing
- Block or warn before data syncs until required settings are configured
- Settings must remain editable after initial setup — not a one-time wizard

## Implementation prompt — common settings categories

Implement a configuration step for each setting relevant to your use case. For each setting: show current value, allow editing, and save immediately on change (not only on form submit).

**Sync scope / selective sync**
Which objects to include. Prompt: "Which data should we sync? (select all that apply: Basic Info, Employment Details, Time Off, Payroll)"

**Field mappings**
Map Merge common model fields to your internal fields. Example: `Employee.work_email` → `users.email`

**Data filters**
Rules for which records to include (e.g., active employees only, specific departments).

**Writeback behavior**
If your product writes data back, configure which fields, direction, and validation rules.

**Default objects**
For accounting integrations: chart of accounts, fiscal year, currency selection.

## Before Proceeding

Tell the user: "I'll add an `integration_settings` table (or a JSON column on `linked_accounts`) to store per-account settings. This requires a database change. Would you prefer a separate table or a JSON column on `linked_accounts`?"

Wait for the user's answer before generating the migration.

## Backend requirements

`integration_settings` table (or JSON column on `linked_accounts`):

| Column | Type |
|---|---|
| `linked_account_id` | FK |
| `setting_key` | string |
| `setting_value` | jsonb |
| `updated_at` | timestamp |

API endpoints (add these to your server — they are not Merge API endpoints):
- `GET /api/merge/settings` — return current settings for the linked account
- `PATCH /api/merge/settings` — update one or more settings; recalculate `setup_complete`

Recalculate `setup_complete` whenever settings change.

## Testing checklist

- [ ] "Setup incomplete" state shown when required settings are missing
- [ ] All settings editable after initial setup
- [ ] Settings saved immediately on change (not only on form submit)
- [ ] `setup_complete` state updates correctly when all required settings are filled
- [ ] Settings persist across sessions
