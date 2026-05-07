---
name: merge-unified-post-connection-data-scope-filtering
description: >
  Establish a data-scope filtering strategy (pre-storage or post-storage) before
  syncing data from Merge. Customers rarely want every record their connected
  system has — they want a scoped subset (active employees in HRIS, candidates
  in a specific stage in ATS, accounts of a certain type in CRM, tickets from a
  specific project in Ticketing, etc.). Use as Step 6 of post-connection
  implementation when customers need control over which records are synced.
  Triggers on: "filter synced data", "selective sync", "sync scope",
  "employee filtering", "candidate filtering", "account filtering",
  "ticket filtering", "include/exclude records", "scope of sync".
license: MIT
metadata:
  author: Merge
  version: 0.2.0
---

# Choosing a Data-Scope Filtering Strategy

Customers almost never want every record their connected system has. An HRIS customer might want only active employees in specific departments. An ATS customer might want only candidates past a certain pipeline stage. A CRM customer might want only accounts owned by their team. A ticketing customer might want only tickets from one project or above a priority threshold.

Decide the filtering approach **before** a live customer forces the decision, because changing it later usually requires a re-sync.

## Prerequisites

- Initial sync logic working (`merge-unified-sync-implement-webhooks` and/or `merge-unified-sync-implement-polling`)

## Before Proceeding

Three pieces of information are needed before writing any filter logic.

If invoked from `merge-unified-implementing-post-connection`, the first two were answered in Step 1 — use that context. Otherwise, gather them now:

- **Categories**: Which Merge categories need filtering? (`hris`, `ats`, `crm`, `accounting`, `ticketing`) — drives which filter parameters apply.
- **Existing sync logic location**: Where is the sync code (webhook handler / polling job)? Filters apply inside it. Search for files that already call `/{category}/v1/{model}` or use `modified_after`.
- **Filtering strategy preference**: pre-storage (Strategy 1) or post-storage (Strategy 2) — see the two-strategies section below. The recommendation is post-storage unless storage cost is a concern.

Ask the user before continuing:

> "Strategy 1 (pre-storage) keeps your DB smaller but requires a full re-sync if filter criteria change later. Strategy 2 (post-storage) is more flexible but stores all records. Which would you like — and which categories should I scope the filtering to?"

Wait for the answer before proceeding.

## The two strategies

The same trade-off applies regardless of category. Pick once per integration; document the choice.

### Strategy 1: Pre-storage filtering (Merge API filters)

Apply filters inside your sync logic **before** writing records to your DB. Each record is evaluated at ingestion; non-matching records are discarded.

- **Pros:** smaller DB, cleaner data, fewer records to query downstream.
- **Cons:** changing filter criteria requires a full re-sync to backfill previously excluded records; more complex sync logic; you can't show customers "what they would have synced" if they widen filters.

### Strategy 2: Post-storage filtering (product filters)

Store ALL records from Merge in a staging table (or with an `included` flag), and apply filters dynamically at query time or via a separate filtering pass.

- **Pros:** filter criteria can change without a re-sync; easier to iterate in UI; "preview what changes if I widen this filter" becomes feasible.
- **Cons:** more data stored; DB queries must always carry filter predicates.

## Recommendation

Start with **post-storage filtering (Strategy 2)** unless storage cost is a meaningful concern. It's easier to tighten filters later than to backfill excluded records.

## Filtering by category — Merge API parameters

The Merge query params differ per category. The decision framework above is the same; only the filters themselves change. Use these as starting points; consult Merge's category-specific common-model docs for the full set.

### HRIS — employee filtering

| Parameter           | Values                          | Notes                                      |
| ------------------- | ------------------------------- | ------------------------------------------ |
| `employment_status` | `ACTIVE`, `INACTIVE`, `PENDING` | Most common filter                         |
| `employment_type`   | `FULL_TIME`, `PART_TIME`, etc.  | Filter by work arrangement                 |
| `groups`            | Group UUIDs                     | Filter by department, location, subsidiary |
| `expand`            | `employment`, `locations`, `manager` | Include nested objects in response   |

Example: `GET /hris/v1/employees?employment_status=ACTIVE`

### ATS — candidate / application filtering

| Parameter           | Values                                        | Notes                                       |
| ------------------- | --------------------------------------------- | ------------------------------------------- |
| `current_stage`     | Stage UUIDs                                   | Filter applications by pipeline stage       |
| `credited_to`       | User UUID                                     | Filter by recruiter / hiring manager        |
| `job_id`            | Job UUID                                      | Filter to candidates for one job            |
| `expand`            | `applications`, `jobs`, `current_stage`, etc. | Include nested objects                      |

Example: `GET /ats/v1/candidates?expand=applications`, then post-filter by `applications[].current_stage` if pre-storage by stage.

### CRM — account / contact / opportunity filtering

| Parameter           | Values                | Notes                                       |
| ------------------- | --------------------- | ------------------------------------------- |
| `owner_id`          | User UUID             | Filter to records owned by a specific user  |
| `account_id`        | Account UUID          | Filter contacts/opportunities to one account |
| `stage`             | Stage UUID            | Filter opportunities by sales stage         |
| `expand`            | `account`, `owner`    | Include nested objects                      |

Example: `GET /crm/v1/accounts?owner_id={uuid}`

### Ticketing — ticket / project filtering

| Parameter           | Values            | Notes                                            |
| ------------------- | ----------------- | ------------------------------------------------ |
| `project_id`        | Project UUID      | Filter tickets to a specific project             |
| `status`            | Status UUID       | Filter by ticket status                          |
| `priority`          | Priority value    | Filter by priority threshold                     |
| `assignee_ids`      | User UUIDs (list) | Filter to tickets assigned to specific users     |
| `expand`            | `assignees`, `account`, `collections` | Include nested objects     |

Example: `GET /ticketing/v1/tickets?project_id={uuid}&priority=HIGH`

### Accounting — record filtering

| Parameter           | Values                | Notes                                         |
| ------------------- | --------------------- | --------------------------------------------- |
| `account_type`      | `ASSET`, `LIABILITY`, etc. | Filter chart-of-accounts entries        |
| `transaction_date_after` | ISO date         | Filter transactions by date range             |
| `company_id`        | Company UUID          | Filter to one company in a multi-entity setup |

Example: `GET /accounting/v1/accounts?account_type=ASSET`

## If you're building a filter UI for customers

The skeleton is identical regardless of category — substitute "employees", "candidates", "accounts", "tickets", or "transactions" as appropriate.

1. **Populate filter options** — internal API fetching the available filter values (unique departments, stages, owners, projects, statuses, etc.) from your stored data or Merge's API.
2. **Store filter selections** — backend table keyed by linked account ID.
3. **Save filter selections** — internal API endpoint to write selections.
4. **Apply filters in sync** — either as Merge API query params (Strategy 1) or as predicates on your staging table (Strategy 2).
5. **Define filter-change behavior** — when a customer updates filters:
   - Re-sync newly included records? (Required if Strategy 1.)
   - Mark previously synced but newly excluded records as inactive / hidden?
   - Notify downstream systems of scope change?

## Implementation checklist

- [ ] Filtering strategy chosen (pre-storage or post-storage) and documented per integration
- [ ] Internal API built to populate filter options in product UI
- [ ] Backend table stores filter selections per linked account
- [ ] Internal API saves filter selections
- [ ] Sync logic incorporates stored filters (in webhook handler and/or polling job)
- [ ] Filter-change behavior defined (re-sync? mark inactive? notify?)
- [ ] Category-appropriate Merge API filters identified and tested

## Troubleshooting

**SYMPTOM:** Customer changed filter criteria; old records that should now be included are missing
**CAUSE:** Pre-storage filtering was used; previously excluded records were never written to your DB.
**FIX:** Trigger a re-sync that uses the updated filter criteria. Or migrate to post-storage filtering so future filter changes don't require re-syncs.

**SYMPTOM:** DB queries are slow because every query has filter predicates
**CAUSE:** Post-storage filtering is in use without supporting indexes.
**FIX:** Index the columns used in filter predicates (e.g., `employment_status`, `current_stage`, `owner_id`). For high-cardinality filters, consider materialized views.

**SYMPTOM:** "Active employees" filter syncs employees that the customer's HRIS shows as terminated
**CAUSE:** Merge's `employment_status` reflects the provider's status field at sync time; some providers update statuses on a delay or have intermediate states (e.g., `PENDING_TERMINATION`).
**FIX:** Cross-check Merge's `employment_status` with `termination_date` (if present) or a provider-specific custom field, then re-evaluate the filter rule.
