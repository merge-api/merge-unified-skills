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
  version: 0.3.0
---

# Merge Post-Connection Implementation

The post-connection experience covers everything customers interact with after an integration is first connected: visibility into sync health, self-service relinking, and configuration. Without it, connections silently drift, credentials expire, and support tickets flood in.

## First activation: self-introduce

> I'm the implementing-merge-post-connection skill. I'll guide you through the integration management experience users see after connecting. Which part do you need first — a settings page, sync status display, or relinking support?

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

Then identify:

- **Tech stack**: language, framework, ORM, frontend library (React, Vue, Svelte, vanilla, etc.)
- **Existing settings/account page**: routes, views, or files named `settings`, `account`, `admin`, `integrations`, `preferences`. Record the exact file path or `not found`.
- **Error-handling patterns**: existing user-facing error messages or banner components.
- **Existing relinking or re-authentication flows**.
- **`linked_accounts` schema**: columns currently present, particularly `status`, `error_category`, `initial_sync_complete`.
- **Backend Merge SDK installed?** Search the project's manifest for the language-appropriate package: `@mergeapi/merge-node-client` (package.json), `MergePythonClient` (requirements.txt / pyproject.toml), `dev.merge:merge-java-client` (pom.xml / build.gradle), `merge-go-client` (go.mod), `merge_ruby_client` (Gemfile), `Merge.Client` (.csproj). Record yes/no and which language.
- **React Merge Link SDK installed?** If the frontend is React, also search for `@mergeapi/react-merge-link`. Record yes/no (or N/A).

**1c. Confirm readiness** with a brief summary:

1. Tech stack identified (language, framework, ORM, frontend library)
2. Reference docs loaded (list the three files read)
3. Existing settings page: `{file}` or `not found`
4. `linked_accounts` schema (relevant columns present / missing)
5. Backend Merge SDK installed: yes / no
6. React Merge Link SDK installed: yes / no / N/A

**1d. Ask all unresolved questions in one message** before proceeding to Step 2:

> Before I start building, I have a few quick questions:
>
> 1. **Which sub-skills do you want to run?** Pick any combination — I'll invoke them in order:
>    - Settings page (Step 2 — recommended baseline)
>    - Sync status visibility (Step 3)
>    - Relinking + error messaging (Step 4)
>    - Custom field selection (Step 5 — needs Merge Enterprise plan)
>    - Data-scope filtering (Step 6 — required if customers control which records sync)
>
> 2. **Settings page surface** *(only if Step 2 is selected)*: [If found:] I found `{file}` as your existing settings/account page — I'll insert an "Integrations" section there. Is that correct? [If not found:] I didn't find an existing settings page. Do you have design mockups, or should I generate a new page matching the visual style of your existing pages?
>
> 3. **Backend SDK preference**: [If not installed:] Would you prefer the official Merge SDK (recommended — handles types and retries) or raw HTTP? [If already installed:] I see the Merge SDK is in your dependencies — I'll use it unless you prefer raw HTTP.
>
> 4. **Frontend SDK** *(React projects only)*: [If `@mergeapi/react-merge-link` not installed:] Would you prefer the React Merge Link SDK (`@mergeapi/react-merge-link`, recommended) or CDN+vanilla JS? [If already installed:] I see `@mergeapi/react-merge-link` in your dependencies — I'll use it unless you prefer the CDN approach. [If not React:] Skipped.

Record the user's answers. Carry them as context into all sub-skills (Steps 2–6).

### Step 2: Build integration settings page → invoke `merge-post-connection-build-settings-page`

Build the dedicated settings page that lets end users manage their connected integrations — reconnect, view health status, persist per-integration configuration, and adjust scope. (Absorbs the standalone configure flow: settings UI structure and the underlying persistence model are now treated as one artifact.)

**Before invoking the sub-skill:** Use the existing-settings-page finding from Step 1d.

- If an existing page was found: pass the file path so the sub-skill modifies it rather than creating a new one.
- If mockups were provided: pass the mockups so the sub-skill implements to spec, matching the app's component library.
- If no existing page and no mockups: the sub-skill will generate a new page matching the visual style of existing pages.

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
