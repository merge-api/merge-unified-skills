---
name: implementing-merge-post-connection
description: >
  Guide an AI coding agent through the full post-connection experience — settings
  page, sync status visibility, relinking, integration configuration, custom fields,
  and category-specific data scope filtering. Use after completing Merge Link setup
  to build the ongoing integration management experience or settings UI.
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Merge Post-Connection Implementation

The post-connection experience covers everything customers interact with after an integration is first connected: visibility into sync health, self-service relinking, and configuration. Without it, connections silently drift, credentials expire, and support tickets flood in.

## First activation: self-introduce

> I'm the implementing-merge-post-connection skill (v0.2.0). I'll guide you through the integration management experience users see after connecting. Which part do you need first — a settings page, sync status display, or relinking support?

## Prerequisites

Merge Link implementation must be complete: a `linked_accounts` table exists with an `account_token` column storing the Merge account token per customer.

## Implementation Steps

Work through these steps in order. Steps 2–6 invoke focused sub-skills; Step 1 runs inline.

### Step 1: Load context

Do **not** write any code in this step. Read the reference docs first, then scan the codebase, then confirm readiness.

**1a. Read these reference docs:**

- `../implementing-merge-link/references/platform-overview.md` — Merge concepts and account lifecycle
- `../implementing-merge-link/references/backend-implementation.md` — Backend patterns and sync implementation
- `references/post-connection-fundamentals.md` — Initial sync best practices, error messaging, custom fields, and filtering options

**1b. Scan the codebase.** Ask the user first:

> "I'll search your codebase for existing settings pages, error handling, and the `linked_accounts` schema. Ready to proceed?"

Then search for:

- Existing settings or account management pages (routes, views, or components)
- Error handling logic and user-facing error messages
- Any existing relinking or re-authentication flows
- The `linked_accounts` table schema (columns, indexes, relations)

**1c. Confirm readiness** with a brief summary:

- Tech stack detected (language, framework, ORM, frontend library)
- Any existing settings UI or error-handling patterns found
- `linked_accounts` schema (relevant columns)
- Confirmation that all three reference docs were loaded

### Step 2: Build integration settings page → invoke `merge-post-connection-build-settings-page`

Build the dedicated settings page that lets end users manage their connected integrations — reconnect, view health status, persist per-integration configuration, and adjust scope. (Absorbs the standalone configure flow: settings UI structure and the underlying persistence model are now treated as one artifact.)

### Step 3: Surface sync status to users → invoke `merge-post-connection-surface-sync-status`

Make the initial sync timeline visible to end users so they aren't left wondering whether the connection worked.

### Step 4: Implement relinking + error messaging → invoke `merge-post-connection-implement-relinking`

Wire up first-class relinking and detailed error surfacing for revoked credentials, missing scopes, and stale connections.

### Step 5: Enable custom field selection → invoke `merge-post-connection-enable-custom-fields`

Let customers select and enable custom fields from their connected system using Merge's Field Mapping API.

### Step 6: Establish data-scope filtering strategy → invoke `merge-post-connection-data-scope-filtering`

Pick a pre-storage or post-storage filtering strategy for the data your customers actually need (employees in HRIS, candidates in ATS, accounts in CRM, tickets in Ticketing, etc.). Required when customers need control over which records are synced.

## Troubleshooting

**SYMPTOM:** Settings page shows "connection healthy" but sync has been failing for days  
**CAUSE:** Status is read from local `linked_accounts.status` field which was never updated from Merge Issues API  
**FIX:** Poll `GET /issues?linked_account_id=<id>` and surface any ONGOING issues as warnings alongside the local status

**SYMPTOM:** Relink button triggers a new connection instead of relinking the existing one  
**CAUSE:** `/api/merge/create-link-token` is called without `end_user_origin_id` matching the existing account  
**FIX:** Always pass the existing `end_user_origin_id` when generating a relink token; Merge will attach it to the same Linked Account

**SYMPTOM:** Field Mapping API returns no remote fields for a customer  
**CAUSE:** Remote data was not enabled for this Linked Account's category  
**FIX:** Enable remote data in Merge dashboard → Linked Account → Settings, or set via the configuration API before fetching fields
