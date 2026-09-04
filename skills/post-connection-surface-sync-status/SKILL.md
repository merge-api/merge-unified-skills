---
name: post-connection-surface-sync-status
description: Implement sync status visibility and user-facing messaging for the initial sync timeline. Use as Step 3 of post-connection implementation to prevent user confusion while Merge syncs data in the background.
license: MIT
metadata:
  author: Merge
  version: 0.3.1
---

# Surface Sync Status to End Users

After a user connects, Merge runs an initial sync that can take minutes to hours depending on company size and the third-party's API rate limits. Without status visibility, users assume the integration is broken — this skill adds clear progress messaging and sets accurate expectations from the moment they connect.

## Prerequisites

`post-connection-build-settings-page` complete — a settings page must exist to render these banners.

## Before Proceeding

Three pieces of information are needed before generating any UI or backend code.

If invoked from `implementing-post-connection`, the first two were answered in Step 1 — use that context. Otherwise, gather them now:

- **Categories**: Which Merge categories will surface sync status? (`hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`) — needed for the per-category `/sync-status` calls.
- **Frontend framework**: React, Vue, Svelte, or vanilla? Drives the banner component pattern.
- **`linked_accounts.initial_sync_complete` column**: present or missing? Required for the in-progress vs. complete branching. If missing, add it via migration before continuing.

Also briefly scan the frontend for an existing notification or banner system (look for `Banner`, `Notification`, `Alert`, `Toast` components) — if one exists, render the sync-status messages through it rather than introducing a new banner pattern.

## Implementation

Build three sync status UI states on the settings page. Your backend should poll `GET https://api.merge.dev/api/{category}/v1/sync-status` from Merge and expose an internal endpoint.

### Merge sync-status response shape

`GET /api/{category}/v1/sync-status` returns:

| Field | Type | Notes |
|---|---|---|
| `results` | array | One entry per Common Model |
| `results[].model_name` | string | e.g. `"Employee"`, `"Contact"` |
| `results[].model_id` | string | e.g. `"hris.Employee"` |
| `results[].status` | string | `SYNCING`, `DONE`, `PARTIALLY_SYNCED`, `FAILED`, `DISABLED`, `PAUSED` |
| `results[].sync_status_reason` | string or null | Why a `SYNCING` model isn't progressing: `RATE_LIMITED` or `WAITING_ON_OTHER_MODELS`. Null when progressing normally. |
| `results[].is_initial_sync` | boolean | `true` if this is the first-ever sync for this model |
| `results[].last_sync_start` | datetime | When the most recent sync started |
| `results[].last_sync_finished` | datetime | When it finished |
| `results[].next_sync_start` | datetime | When the next automatic sync is scheduled. This is the "next sync" time to render — you don't need to compute it from a cadence. |
| `results[].last_sync_result` | string | Same six values as `status`, for the run that just completed |
| `results[].data_fresh_as_of` | datetime or null | The point in time the model's data is complete through. Null until the first sync completes. |

> **Show `data_fresh_as_of`, not `last_sync_start`.** `last_sync_start` is when Merge began the most recent attempt, which may have failed; `data_fresh_as_of` is the guarantee — "your data is current at least through this time." That's the timestamp a user can act on.

> **`PARTIALLY_SYNCED` and `PAUSED` are terminal states.** `PARTIALLY_SYNCED` means the sync completed with some fields failing; it will not become `DONE` by waiting. `PAUSED` means the Linked Account has seen no inbound API request or webhook for over 2 weeks, or has failed syncs for over 2 weeks — it needs traffic or a fix, not patience.

### Your internal endpoint shape

Expose `GET /api/integrations/:id/sync-status` returning:

```json
{
  "initial_sync_complete": false,
  "models": [
    { "model_name": "Contact", "status": "syncing", "record_count": null },
    { "model_name": "Account", "status": "done", "record_count": 42 }
  ]
}
```

Translate Merge status codes to user-friendly strings (never expose `SYNCING`, `PARTIALLY_SYNCED`, etc. to end users).

### Pattern 1: Initial sync in-progress

When `initial_sync_complete == false`, show a non-blocking progress banner:

- Message: "We're pulling in your data from [Integration Name]. This typically takes anywhere from a few minutes to several hours depending on your account size — we'll update this page automatically once it's ready. No action needed."
- Show a "Last checked" timestamp so users know the page is live, not stale.
- Poll your backend every 15–30 seconds for the first 2–3 minutes, then back off to every 1–5 minutes.
- Do not block access to the rest of the page.

### Pattern 2: Sync complete

When `initial_sync_complete == true` and all models report success, replace the banner with:

- Message: "Connected and synced." with a checkmark or success indicator.
- Show a record count or data summary if available (e.g., "542 employees synced").
- Show the next scheduled sync time from `next_sync_start`.

### Pattern 3: Partial sync or error state

If any model status maps to PARTIALLY_SYNCED, FAILED, or PAUSED:

- Show a soft warning for PARTIALLY_SYNCED — not a hard error. The next scheduled sync often picks up what failed.
- Message: "Most of your data has synced. Some fields didn't come through on the last sync and Merge will try again on the next one. If this persists past a couple of syncs, contact support."
- Do **not** describe PARTIALLY_SYNCED as "still loading." It's a finished sync with incomplete results, so a spinner that never resolves is the wrong affordance.
- PAUSED needs its own copy, because it's caused by inactivity rather than by an error: the Linked Account has had no inbound API request or webhook for over 2 weeks, or failed syncs for over 2 weeks. Resuming traffic clears it.
- Distinguish partial sync (incomplete data, retries on its own) from a broken connection (requires relinking via the reconnect flow).
- Never surface raw status codes (SYNCING, DONE, PARTIALLY_SYNCED, FAILED, PAUSED, DISABLED) to end users — translate all values to plain language.

## UX Best Practices

- Set time expectations on first display, before the user can wonder why nothing is showing.
- Clarify what data IS included (e.g., employees, time-off records) and what is NOT (e.g., payroll details, if out of scope).
- Use non-blocking UI — banners, not modals or error pages — so users can still explore the product.
- Combine polling with webhooks for reliability: the `LinkedAccount.sync_completed` webhook for immediate notification, `/sync-status` polling as a fallback.

## Testing Checklist

- [ ] Progress banner shows during initial sync (while `initial_sync_complete == false`)
- [ ] Banner auto-updates when sync completes (via polling or webhook trigger)
- [ ] "Connected and synced" state shown after completion
- [ ] Partial sync shows a soft warning, not a hard error
- [ ] No raw Merge status codes exposed to end users
- [ ] Time expectation messaging set on first display
