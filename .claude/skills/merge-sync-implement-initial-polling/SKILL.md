---
name: merge-sync-implement-initial-polling
description: Implement initial sync detection via polling — a scheduled job that checks Merge sync status and triggers a data fetch when the initial sync completes. Use as Step 2a of Merge sync implementation; recommended starting point before adding webhooks.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing Initial Sync Detection via Polling

Creates a background polling job that periodically checks all active linked accounts' sync status and triggers an initial data fetch when Merge signals the sync is complete. Simpler than webhooks and recommended as the first implementation.

## Prerequisites

- `merge-sync-set-context` complete (sync fundamentals understood)
- `linked_accounts` table has `initial_sync_complete boolean DEFAULT false` column
- Merge API key available as env var (e.g. `MERGE_API_KEY`)
- Background job system available (cron, Celery, Redis Queue, etc.)

## Database Addition

If `initial_sync_complete` column is not present:

```sql
ALTER TABLE linked_accounts ADD COLUMN initial_sync_complete boolean DEFAULT false;
```

## Implementation Prompt

Implement a scheduled polling job that detects initial sync completion for all active Merge linked accounts. A poll interval of every 5–15 minutes is a reasonable default — adjust based on your background job infrastructure and Merge plan tier. You can add webhooks later for real-time detection without removing this polling job; polling makes a good safety net.

### Job Logic

```
every {configured interval}:
  accounts = query linked_accounts WHERE initial_sync_complete = false AND account_token IS NOT NULL

  for each account:
    try:
      response = GET https://api.merge.dev/api/{account.category}/v1/sync-status
        headers: Authorization: Bearer {MERGE_API_KEY}
                 X-Account-Token: {account.account_token}

      all_ready = check_readiness(response.results)

      if all_ready:
        set linked_accounts.initial_sync_complete = true WHERE id = account.id
        trigger fetch_initial_data(account)

    except error:
      log error for account.id, continue to next account
```

### Readiness Check Logic

```
function check_readiness(models):
  for each model in models:
    if model.status == "DISABLED":
      continue  # skip — does not block readiness

    model_ready = (model.status == "DONE" OR model.is_initial_sync == false)

    if NOT model_ready:
      return false  # at least one enabled model not ready

  return true  # all non-DISABLED models are ready
```

### Error Handling

- Log errors per linked account but continue polling others
- Do NOT stop the polling job after initial sync completes — it will be reused for subsequent sync detection

## Critical Gotchas

- **Use OR logic**: `status == "DONE" OR is_initial_sync == false` — using AND misses cases where Merge marks old syncs as non-initial before completion
- **Skip DISABLED models**: they must not block the overall readiness check
- **Do not stop polling**: after initial sync completes, keep the job running for subsequent sync detection
- **Poll frequency**: initial sync takes minutes to hours — polling faster than every 5 minutes adds no benefit

## Testing Checklist

- [ ] Polling job runs on schedule continuously
- [ ] Detects completion using OR logic (`DONE` or `is_initial_sync == false`)
- [ ] Skips DISABLED models when checking overall readiness
- [ ] Marks `initial_sync_complete = true` once all enabled models are ready
- [ ] Continues polling after initial sync completes (does not stop)
- [ ] Handles API errors per account gracefully (logs and continues)
- [ ] Works for multiple integrations simultaneously
