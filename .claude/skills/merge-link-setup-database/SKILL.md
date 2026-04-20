---
name: merge-link-setup-database
description: Create the linked_accounts database table required for Merge Link. Use as Step 2 of Merge Link implementation after loading context.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Setup Database: linked_accounts Table

Creates the database table that tracks linked Merge accounts — one row per active integration per organization. All Merge Link API flows read and write this table.

## Prerequisites

Context loaded via `merge-link-set-context` (tech stack and ORM identified).

## Before Proceeding

Tell the user: "I'll generate a database migration to create the `linked_accounts` table. This will modify your database schema — you'll review the migration file before running it. Ready to proceed?"

Wait for confirmation before continuing.

## Implementation Prompt

Tell your coding agent:

> Create a `linked_accounts` table (or equivalent model for our ORM) with these exact fields:
>
> | Field | Type | Notes |
> |---|---|---|
> | `id` | integer, primary key | auto-increment |
> | `organization_id` | integer, foreign key | ties integration to a user/org in your system |
> | `end_user_origin_id` | string, at least 100 chars, not null | unique identifier for this integration |
> | `category` | string, at least 50 chars, not null | Merge category: `hris`, `ats`, `crm`, etc. |
> | `integration_slug` | string, at least 100 chars, nullable | e.g. `gusto`, `workday` — set after token exchange |
> | `account_token` | string, at least 500 chars, nullable | permanent Merge API token — null until exchange completes |
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
