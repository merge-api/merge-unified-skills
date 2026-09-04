---
name: post-connection-data-scope-filtering
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
  version: 0.3.0
---

# Choosing a Data-Scope Filtering Strategy

Customers almost never want every record their connected system has. An HRIS customer might want only active employees in specific departments. An ATS customer might want only candidates past a certain pipeline stage. A CRM customer might want only accounts owned by their team. A ticketing customer might want only tickets from one project or above a priority threshold.

Decide the filtering approach **before** a live customer forces the decision, because changing it later usually requires a re-sync.

## Prerequisites

- Initial sync logic working (`sync-implement-webhooks` and/or `sync-implement-polling`)

## Before Proceeding

Three pieces of information are needed before writing any filter logic.

If invoked from `implementing-post-connection`, the first two were answered in Step 1 — use that context. Otherwise, gather them now:

- **Categories and endpoints**: Which Merge categories and which specific endpoints need filtering? (`hris`, `ats`, `crm`, `accounting`, `ticketing`) — filters are defined per endpoint, so `/crm/v1/accounts` and `/crm/v1/contacts` accept different sets.
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

> **Filters are per-endpoint, not per-category.** A parameter that exists on one endpoint is usually absent on its siblings — `owner_id` works on CRM accounts and opportunities but not on contacts; `account_id` works on contacts and opportunities but not on accounts. An unrecognized query param is ignored rather than rejected, so a typo returns a full unfiltered page and looks like the filter matched everything. Confirm each one against the endpoint's own API reference page before shipping.

### HRIS — `GET /hris/v1/employees`

| Parameter           | Values                          | Notes                                      |
| ------------------- | ------------------------------- | ------------------------------------------ |
| `employment_status` | `ACTIVE`, `INACTIVE`, `PENDING` | Most common filter                         |
| `employment_type`   | free-form string                | Provider's own type value, not a fixed enum |
| `groups`            | Group UUIDs                     | Filter by department, location, subsidiary |
| `manager_id`, `team_id`, `company_id` | UUID          | Filter by org placement                    |
| `home_location_id`, `work_location_id` | UUID         | Filter by location                         |
| `started_after` / `terminated_after`   | ISO date     | Filter by employment dates                 |
| `expand`            | `employments`, `groups`, `manager`, `company`, `home_location`, `work_location`, `team`, `pay_group` | Comma-separated, no spaces |

Example: `GET /hris/v1/employees?employment_status=ACTIVE&expand=employments,manager`

⚠️ `expand=employment` (singular) and `expand=locations` are not valid tokens. The relation is `employments`, and locations expand as `home_location` / `work_location`.

### ATS — `GET /ats/v1/candidates` and `GET /ats/v1/applications`

Pipeline-stage and recruiter filters live on **applications**, not candidates. A candidate has no stage of its own.

| Endpoint | Parameter | Values | Notes |
| --- | --- | --- | --- |
| `/applications` | `current_stage_id` | Stage UUID | Filter applications by pipeline stage |
| `/applications` | `credited_to_id`   | RemoteUser UUID | Filter by recruiter / hiring manager |
| `/applications` | `job_id`           | Job UUID | Filter to applications for one job |
| `/applications` | `candidate_id`, `reject_reason_id`, `source` | UUID / string | Further narrowing |
| `/candidates`   | `email_addresses`, `first_name`, `last_name`, `tags` | string | The filters candidates actually accepts |
| `/candidates`   | `expand`           | `applications`, `attachments` | Only these two |

Example: `GET /ats/v1/applications?current_stage_id={uuid}&job_id={uuid}`

⚠️ `current_stage`, `credited_to`, and `job_id` are not parameters on `/candidates`, and the application-side names end in `_id`. To scope candidates by stage, filter `/applications` first and collect `candidate` IDs, or pull `?expand=applications` and post-filter on `applications[].current_stage`.

### CRM — `GET /crm/v1/accounts`, `/contacts`, `/opportunities`

| Endpoint | Parameter | Values | Notes |
| --- | --- | --- | --- |
| `/accounts` | `owner_id` | User UUID | Filter to accounts owned by a user |
| `/accounts` | `name` | string | Exact-name lookup |
| `/accounts` | `expand` | `owner` | The only valid token here |
| `/contacts` | `account_id` | Account UUID | Filter contacts to one account |
| `/contacts` | `email_addresses`, `phone_numbers` | string | Identity lookups |
| `/opportunities` | `owner_id`, `account_id`, `stage_id`, `status` | UUID / enum | Full set of scope filters |

Example: `GET /crm/v1/opportunities?stage_id={uuid}&owner_id={uuid}`

⚠️ There is no `stage` parameter — it's `stage_id`, and only on `/opportunities`. `owner_id` is not accepted on `/contacts`; scope contacts by `account_id` and resolve ownership from the parent account.

### Ticketing — `GET /ticketing/v1/tickets`

| Parameter           | Values            | Notes                                            |
| ------------------- | ----------------- | ------------------------------------------------ |
| `collection_ids`    | Collection UUIDs  | **This is the project/board filter** — Merge models boards and projects as Collections |
| `status`            | free-form string  | The provider's status string, not a UUID and not the Common Model enum |
| `priority`          | `HIGH`, `LOW`, `NORMAL`, `URGENT` | Exact match on one value, not a threshold |
| `assignee_ids`, `creator_ids` | User UUIDs (list) | Filter by assignment or authorship |
| `account_id`, `contact_id`, `parent_ticket_id` | UUID | Filter by relationship |
| `ticket_type`, `tags`, `due_after`, `completed_after` | string / ISO date | Further narrowing |
| `expand`            | `assignees`, `assigned_teams`, `account`, `contact`, `creator`, `collections`, `attachments`, `parent_ticket`, `permissions` | Comma-separated, no spaces |

Example: `GET /ticketing/v1/tickets?collection_ids={uuid}&priority=HIGH`

⚠️ There is no `project_id` parameter on `/tickets`. Merge exposes a separate `Project` model, but tickets are scoped by `collection_ids`. And `priority=HIGH` matches only HIGH — to get "HIGH or above" you pass `priority=HIGH` and `priority=URGENT` as separate calls, or filter after the fetch.

### Accounting — `GET /accounting/v1/accounts` and `/transactions`

| Endpoint | Parameter | Values | Notes |
| --- | --- | --- | --- |
| `/accounts` | `classification` | `ASSET`, `LIABILITY`, `EQUITY`, `EXPENSE`, `REVENUE` | **This is the chart-of-accounts filter** |
| `/accounts` | `account_type` | free-form string | The provider's own type label, not the classification enum |
| `/accounts` | `account_number`, `name`, `status`, `company_id` | string / UUID | Further narrowing |
| `/transactions` | `transaction_date_after`, `transaction_date_before` | ISO date | Date-range filter |
| `/transactions` | `company_id` | Company UUID | One company in a multi-entity setup |

Example: `GET /accounting/v1/accounts?classification=ASSET`

⚠️ `account_type=ASSET` does not work. `account_type` is an untyped passthrough of the provider's label; the ASSET/LIABILITY/EQUITY/EXPENSE/REVENUE enum is `classification`. And `transaction_date_after` is a `/transactions` parameter — on `/accounts` it is silently ignored.

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
