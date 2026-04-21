---
name: merge-post-connection-hris-employee-filtering
description: HRIS-specific — establish an employee filtering strategy (pre-storage or post-storage) before syncing employee data from Merge. Use as Step 7 of post-connection implementation when building HRIS integrations where customers control which employees are synced.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

> **HRIS integrations only.** Skip this step for non-HRIS categories.

# HRIS Employee Filtering Strategy

Customers rarely want ALL employees synced — they may want active employees in specific locations, departments, or employment types. Decide the filtering approach before a live customer forces the decision, because changing it later requires a re-sync.

## Prerequisites

- `merge-post-connection-set-context` complete
- Initial sync logic working

## Two Strategies

### Strategy 1: Pre-storage filtering (Merge API filters)

Apply filters inside your sync logic **before** writing records to your DB. Each record is evaluated at ingestion; non-matching records are discarded.

- **Pros**: smaller DB, cleaner data, fewer records to query
- **Cons**: changing filter criteria requires a full re-sync to backfill previously excluded records; more complex sync logic

Example query:

```
GET /hris/v1/employees?employment_status=ACTIVE
```

### Strategy 2: Post-storage filtering (product filters)

Store ALL employee records from Merge in a staging table or with an `included` flag. Apply filters dynamically at query time or via a separate filtering pass.

- **Pros**: filter criteria can change without re-sync; easier to iterate in UI
- **Cons**: more data stored; DB queries must always include filter predicates

## Recommendation

Start with **post-storage filtering (Strategy 2)** unless storage cost is a concern. It's easier to tighten filters later than to backfill excluded records.

**Before writing any code, confirm the strategy with the user:** "Strategy 1 (pre-storage) keeps your DB smaller but requires a full re-sync if filter criteria change later. Strategy 2 (post-storage) is more flexible but stores all records. Which would you like to proceed with?"

Wait for the user's answer before implementing.

## If Building a Filter UI for Customers

1. **Populate filter options** — internal API fetching unique departments, locations, and employment types from your stored employee data or Merge's API
2. **Store filter selections** — backend table keyed by linked account ID
3. **Save filter selections** — internal API endpoint to write selections
4. **Apply filters in sync** — either as Merge API query params (Strategy 1) or as predicates on your staging table (Strategy 2)
5. **Define filter change behavior** — when a customer updates filters: re-sync excluded records? Mark removed records as inactive? Notify downstream systems?

## Merge API Filtering Options

| Parameter           | Values                               | Notes                                      |
| ------------------- | ------------------------------------ | ------------------------------------------ |
| `employment_status` | `ACTIVE`, `INACTIVE`, `PENDING`      | Most common filter                         |
| `employment_type`   | `FULL_TIME`, `PART_TIME`, etc.       | Filter by work arrangement                 |
| `groups`            | Group UUIDs                          | Filter by department, location, subsidiary |
| `expand`            | `employment`, `locations`, `manager` | Include nested objects in response         |

## Implementation Checklist

- [ ] Internal API built to populate filter options in product UI
- [ ] Backend table stores filter selections per linked account
- [ ] Internal API saves filter selections
- [ ] Sync logic incorporates stored filters
- [ ] Filter change behavior defined (re-sync? mark inactive? notify?)
- [ ] Filtering strategy chosen (pre-storage or post-storage) and documented
