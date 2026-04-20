---
name: merge-post-connection-surface-sync-status
description: Implement sync status visibility and user-facing messaging for the initial sync timeline. Use as Step 3 of post-connection implementation to prevent user confusion while Merge syncs data in the background.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Surface Sync Status to End Users

After a user connects, Merge runs an initial sync that can take minutes to hours depending on company size and the third-party's API rate limits. Without status visibility, users assume the integration is broken — this skill adds clear progress messaging and sets accurate expectations from the moment they connect.

## Prerequisites

`merge-post-connection-build-settings-page` complete — a settings page must exist to render these banners.

## Implementation

Build three sync status UI states on the settings page. Your backend should poll `GET https://api.merge.dev/api/{category}/v1/sync-status` from Merge and expose an internal endpoint (e.g. `GET /api/integrations/:id/sync-status`) that returns `initial_sync_complete` plus per-model status.

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
- Show next scheduled sync time if exposed by your backend.

### Pattern 3: Partial sync or error state

If any model status maps to PARTIALLY_SYNCED or FAILED:

- Show a soft warning — not a hard error. Most partial syncs resolve automatically.
- Message: "Most of your data has synced. Some records may still be loading — Merge will retry automatically. If this persists after 24 hours, contact support."
- Distinguish partial sync (temporary, self-healing) from a broken connection (requires relinking via the reconnect flow).
- Never surface raw status codes (SYNCING, DONE, PARTIALLY_SYNCED, FAILED) to end users — translate all values to plain language.

## UX Best Practices

- Set time expectations on first display, before the user can wonder why nothing is showing.
- Clarify what data IS included (e.g., employees, time-off records) and what is NOT (e.g., payroll details, if out of scope).
- Use non-blocking UI — banners, not modals or error pages — so users can still explore the product.
- Combine polling with webhooks for reliability: `Linked account synced` webhook for immediate notification, `/sync-status` polling as a fallback.

## Testing Checklist

- [ ] Progress banner shows during initial sync (while `initial_sync_complete == false`)
- [ ] Banner auto-updates when sync completes (via polling or webhook trigger)
- [ ] "Connected and synced" state shown after completion
- [ ] Partial sync shows a soft warning, not a hard error
- [ ] No raw Merge status codes exposed to end users
- [ ] Time expectation messaging set on first display
