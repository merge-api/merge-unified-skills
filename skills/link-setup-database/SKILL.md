---
name: link-setup-database
description: Create the linked_accounts database table required for Merge Link. Use as Step 2 of Merge Link implementation after loading context.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Setup Database: linked_accounts Table

Creates the database table that tracks linked Merge accounts — one row per active integration per organization. All Merge Link API flows read and write this table.

## Prerequisites

Tech stack and ORM identified (either from Step 1 of `implementing-link`, or by scanning the codebase now).

## Before Proceeding

**Step 1 — Confirm or gather required context:**

Two pieces of information are needed before showing the schema:

- **Organization/tenant table**: The table or model in your app that represents a customer org or tenant (e.g. `organizations`, `companies`, `tenants`). Needed to wire the `organization_id` FK.
- **Linked Account strategy**: Strategy 1 (1 Linked Account per category per org) or Strategy 2 (multiple per category)? Needed to annotate `end_user_origin_id`.

If invoked from `implementing-link`, both were answered in Steps 1b and 1d — use that context. Otherwise, ask the user now:

> 1. What is the table/model that represents a customer organization or tenant in your system? What is its primary key column?
> 2. Do you want 1 Linked Account per category per org, or multiple Linked Accounts per category?

**Step 2 — Show the schema and wait for confirmation:**

> Here is the `linked_accounts` table I'll create:
>
> | Column | Type | Constraints | Notes |
> |--------|------|-------------|-------|
> | `id` | integer | PRIMARY KEY, auto-increment | |
> | `organization_id` | integer | NOT NULL, FK → `{org_table}.{pk}` | Ties to your org/tenant table |
> | `end_user_origin_id` | varchar(200) | NOT NULL | Stable per-org GUID (Strategy 1) or per-connection GUID (Strategy 2) |
> | `category` | varchar(50) | NOT NULL | e.g. `hris`, `ats`, `crm` |
> | `integration_slug` | varchar(100) | nullable | Populated after token exchange |
> | `account_token` | TEXT | nullable | Must be TEXT — tokens exceed 100 chars and a fixed VARCHAR truncates silently |
> | `status` | varchar(20) | NOT NULL, default `'pending'` | `pending`, `active`, `error`, `disabled` |
> | `initial_sync_complete` | boolean | NOT NULL, default `false` | |
> | `created_at` | timestamp | NOT NULL, default now | |
> | `updated_at` | timestamp | NOT NULL, default now, auto-update | |
>
> **Unique constraint**: `(organization_id, end_user_origin_id)`
>
> **FK for `organization_id`**: I'll reference `{org_table}.{pk}`. [If no org table was identified: I'll create `organization_id` as a plain integer — you can add the `REFERENCES` constraint manually.]
>
> Does this look right? Any columns to add, rename, or change before I generate the migration?

Wait for confirmation before continuing.

## Implementation Prompt

Tell your coding agent:

> Create a `linked_accounts` table (or equivalent model for our ORM) with these exact fields:
>
> For `organization_id`, emit a proper FK constraint referencing the org/tenant table identified in Step 1:
> ```sql
> organization_id INTEGER NOT NULL REFERENCES {org_table}({pk_col})
> ```
> If the org table was not identified in Step 1, emit `organization_id INTEGER NOT NULL` and add a `-- TODO: add REFERENCES constraint` comment. Do NOT invent a table name.
>
> | Field | Type | Notes |
> |---|---|---|
> | `id` | integer, primary key | auto-increment |
> | `organization_id` | integer, foreign key | ties integration to your org/tenant table (see FK instruction above) |
> | `end_user_origin_id` | varchar(200), not null | stable per-org GUID (Strategy 1) or per-connection GUID (Strategy 2) |
> | `category` | string, at least 50 chars, not null | Merge category: `hris`, `ats`, `crm`, etc. |
> | `integration_slug` | string, at least 100 chars, nullable | e.g. `gusto`, `workday` — set after token exchange |
> | `account_token` | TEXT (or string with no fixed cap), nullable | permanent Merge API token — null until exchange completes. Use `TEXT` rather than a fixed `VARCHAR(64/128)`; account tokens can exceed 100 chars and a too-tight column truncates silently in some drivers |
> | `status` | string, at least 20 chars, default `pending` | `pending`, `active`, `error`, `disabled` |
> | `initial_sync_complete` | boolean, default false | flipped true after first full sync |
> | `created_at` | timestamp | default now |
> | `updated_at` | timestamp | default now, auto-update |
>
> Add a **unique constraint on `(organization_id, end_user_origin_id)`**.
>
> Use the project's existing migration/ORM system (e.g. Alembic, Django migrations, ActiveRecord, Prisma). Generate the migration file and show it to the user for review before running it.

## Critical Gotchas

**`end_user_origin_id` MUST be written to the database BEFORE calling the Merge API.**
The record is created during link token generation — not after. If the Merge API call fails mid-flow, the local record prevents duplicate incomplete accounts on retry.

**`account_token` is nullable by design.**
It does not exist until the public token exchange completes (Step 4). Any non-null constraint here will break the flow.

**The unique constraint on `(organization_id, end_user_origin_id)` prevents duplicate integrations.**
This is the deduplication guard. Without it, users can create multiple conflicting records for the same integration.

## Testing Checklist

- [ ] Table created with all required columns
- [ ] Unique constraint on `(organization_id, end_user_origin_id)` exists
- [ ] `account_token` column is nullable
- [ ] `initial_sync_complete` defaults to false
- [ ] Migration runs cleanly with no errors (or equivalent ORM check)
