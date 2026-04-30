---
name: merge-post-connection-implement-relinking
description: Implement relinking as a first-class in-product flow and surface detailed, actionable error messages that clarify who must act and how. Use as Step 4 of post-connection implementation to eliminate integration support tickets.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Relinking and Detailed Error Messaging

## Purpose

Credentials expire, permissions get revoked, and admins change — relinking lets end users re-authenticate without contacting support. Detailed error messaging (rather than "something went wrong") tells users exactly what failed and who needs to fix it.

## Prerequisites

- `merge-post-connection-build-settings-page` complete
- `/api/merge/relink-integration` endpoint working

---

## Before Proceeding

Tell the user: "Implementing relinking requires storing error state on the `linked_accounts` table (an `error_category` column and optionally `error_detail`). I'll generate a migration for this. Ready to proceed?"

Wait for confirmation before continuing.

## Part 1: Relinking Flow

Prompt the codebase to implement relinking with multiple entry points and clean state management:

> Implement relinking with the following requirements:
>
> **Entry points** — expose the reconnect action from at least two places:
> - Settings page: always-visible "Reconnect" button
> - Error banner CTA: "Reconnect" link surfaced when status is not active
> - Email notification link (deep-link into the settings page reconnect flow)
>
> **Flow:**
> 1. Call `POST /api/merge/relink-integration` to get a new link token
> 2. Open Merge Link modal using that token
> 3. On `onSuccess` callback: refresh integration status from DB and update UI
>
> **Success state:** Set `status = "active"` in `linked_accounts`, clear any stored error state (error category, error detail fields).
>
> **Failure handling:** Show the specific error returned; do not wipe or overwrite the existing `linked_accounts` record.

---

## Part 2: Error Messaging

Prompt the codebase to integrate with Merge's Issues API and surface human-readable messages:

> Use `GET https://api.merge.dev/api/{category}/v1/issues?linked_account_id={linked_account_id}` (Merge Issues API) to fetch structured error information for the linked account.
>
> **Issues API response** (each issue):
>
> | Field | Type | Notes |
> |---|---|---|
> | `id` | string (UUID) | Issue ID |
> | `status` | string | `ONGOING`, `RESOLVED` |
> | `error_description` | string | Human-readable error summary |
> | `error_detail` | string | Specific detail (e.g., missing permission name) |
> | `first_incident_time` | datetime | When the issue first appeared |
> | `last_incident_time` | datetime | Most recent occurrence |
> | `linked_account` | string (UUID) | Linked Account ID |
>
> For each issue, surface a message that answers: what is broken, who needs to fix it, and what action to take.
>
> Map error categories to the following message patterns:
>
> | Category | Message | Actor |
> |---|---|---|
> | Auth failure / expired credentials | "Your [Integration] credentials have expired. Click Reconnect to re-authenticate." | End user |
> | Missing permissions | "Your [Integration] account is missing required permissions. Have your [Integration] admin grant [specific permission]." | Admin |
> | Billing / plan restriction | "Access to [Integration] is blocked due to a plan restriction. Contact [Integration] support or your account admin." | Admin or support |
> | Integration outage | "[Integration] is currently experiencing an outage. No action needed — we'll retry automatically." | None |
>
> Replace `[Integration]` with the integration name from the linked account record. Replace `[specific permission]` with the `error_detail` field from the Issues API response when available.
>
> Store the latest error category on the `linked_accounts` record so the UI can render the correct banner without re-fetching issues on every page load.

---

## "Live" Checklist

- [ ] Relinking accessible from at least 2 entry points (settings page, error banner)
- [ ] Reconnect flow works end-to-end without contacting support
- [ ] Error messages state the specific error category (not generic "something went wrong")
- [ ] Each error message clarifies who must act (end user / admin / support)
- [ ] Successful relink resets `status = "active"` in `linked_accounts` and clears error state
- [ ] Relink failure does not delete or overwrite the existing account record
