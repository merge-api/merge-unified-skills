# Merge Platform Overview

> **Field-name convention used in this doc.** Pseudo-code and JSON examples below show the **raw HTTP/JSON response shape** (snake_case: `is_initial_sync`, `model_name`, `last_sync_result`, `modified_at`, `remote_data`). The Merge SDKs (Node, Python typed client, Java, Go) auto-convert these to language-idiomatic names — in Node, `is_initial_sync` becomes `isInitialSync`, `modified_at` becomes `modifiedAt`, etc. Write your code in the convention your SDK uses; use snake_case only when calling the REST API directly.

## What is Merge.dev?

Merge is a unified API platform that eliminates the need to build and maintain individual integrations with different vendor APIs. Instead of handling dozens of different schemas, auth methods, versions, and edge cases, you integrate once with Merge.

## Core Benefits

- **Single Integration**: One API instead of dozens of vendor-specific integrations
- **Unified Schema**: Consistent data structure across all providers
- **Automatic Updates**: Merge handles API changes, versioning, and maintenance
- **Built-in Auth**: OAuth, API keys, and authentication handled automatically

## Key Concepts

### Categories
Merge organizes integrations by business function:
- **HRIS**: Human Resources (Workday, BambooHR, HiBob)
- **ATS**: Applicant Tracking (Greenhouse, Lever, Workable)
- **CRM**: Customer Relationship Management (Salesforce, HubSpot)
- **Accounting**: Financial systems (QuickBooks, Xero)
- **Ticketing**: Support systems (Zendesk, Intercom)
- **FileStorage**: File Management (Google Drive, Dropbox, Box)
- **Knowledge Base**: Knowledge management systems (Confluence, Notion, Guru)

### End User Origin ID
- **Purpose**: Unique identifier for each integration within a category
- **Critical Rule**: Must be stored before calling Merge API to prevent duplicate incomplete accounts
- **Lifecycle**: Permanent - never changes during relinking
- **Strategic Decision**: Format depends on your integration architecture (see End User Origin ID Strategy below)

### Account Token
- **Purpose**: Authenticates API requests to Merge for specific integration
- **Lifecycle**: Permanent - never changes during relinking
- **Usage**: Combined with API key for all data sync requests

### Link Token
- **Purpose**: Short-lived token for initializing Merge Link modal
- **Lifecycle**: Single-use - generate fresh token for every modal opening
- **Critical Rule**: Never cache or reuse link tokens

## Authentication Flow (3 Steps)

1. **Backend**: Create link_token with end_user_origin_id and category → receive link_token
2. **Frontend**: User completes Merge Link modal → receive public_token
3. **Backend**: Exchange public_token for account_token → store for API calls

**Multi-Category Architecture**: Each category (HRIS, ATS, CRM, etc.) requires its own authentication flow and maintains separate account tokens. A single organization can have multiple active integrations across different categories simultaneously.

## Key Requirements Discovered

### Fresh Tokens Always
- Generate new link_token on every button click
- Never reuse or cache link tokens between attempts
- Each modal opening requires fresh authentication

### End User Origin ID Storage
- Must be stored immediately when generating link_token
- Prevents creating multiple incomplete accounts in Merge's system
- Required for proper integration lifecycle management

### Invisible Integration
- Zero Merge terminology exposed in user interface
- Business-focused messaging only ("Connect HR System" not "Connect via Merge")
- Seamless user experience that feels native to your application

## Data Syncing Strategy

### Hybrid Approach (Recommended)
- **Webhooks**: Real-time updates with double-webhook system for reliability
- **Polling**: Backup sync (minimum every 24 hours) since webhooks can fail
- **Forced Resyncs**: Available when needed for data consistency

### Reliability Features
- Exponential backoff for failed webhook deliveries
- Multiple retry attempts for network issues
- Real-time data payload delivery to your application

## Data Syncing Concepts

### Initial Sync Lifecycle

When a user successfully completes the Merge Link authentication flow, Merge automatically initiates an **initial sync** in the background. This is a one-time process that fetches the complete historical dataset from the connected third-party system.

**Key Characteristics**:
- **Automatic**: Begins immediately after authentication, no manual triggering required
- **Background Process**: Happens asynchronously on Merge's infrastructure
- **Duration**: Can take minutes to hours depending on dataset size
- **Scope**: Fetches all available data for enabled models (Employee, Company, TimeOff, etc.)
- **One-Time**: Only runs once per integration connection

**Initial Sync States**:
Your application should detect when the initial sync completes before attempting to fetch data. This prevents requesting data that hasn't finished syncing yet.

### Sync Status Monitoring

Merge provides the `GET /api/{category}/v1/sync-status` endpoint to monitor sync progress for each data model.

**Response Structure**:
```json
{
  "next": "https://api.merge.dev/api/hris/v1/sync-status?cursor=abc123",
  "previous": null,
  "results": [
    {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "last_sync_start": "2024-01-15T10:30:00Z",
      "next_sync_start": "2024-01-15T22:30:00Z",
      "status": "SYNCING",
      "is_initial_sync": true,
      "last_sync_result": null,
      "last_sync_finished": null
    },
    {
      "model_name": "Company",
      "model_id": "hris.Company",
      "last_sync_start": "2024-01-15T10:28:00Z",
      "next_sync_start": "2024-01-15T22:28:00Z",
      "status": "DONE",
      "is_initial_sync": false,
      "last_sync_result": "SUCCESSFUL",
      "last_sync_finished": "2024-01-15T10:29:15Z"
    },
    {
      "model_name": "TimeOff",
      "model_id": "hris.TimeOff",
      "last_sync_start": null,
      "next_sync_start": null,
      "status": "DISABLED",
      "is_initial_sync": false,
      "last_sync_result": null,
      "last_sync_finished": null
    }
  ]
}
```

**Status Values**:
- `SYNCING`: Sync currently in progress
- `DONE`: Sync completed successfully
- `FAILED`: Sync encountered errors
- `DISABLED`: Model not enabled for this integration
- `PARTIALLY_SYNCED`: Partial data retrieved
- `PAUSED`: Sync temporarily paused

**Key Fields**:
- `model_id`: Fully qualified model identifier (e.g., "hris.Employee")
- `is_initial_sync`: `true` indicates first sync still running
- `last_sync_start`: Timestamp when sync began (use for `modified_after`)
- `last_sync_finished`: Timestamp when sync completed
- `next_sync_start`: Scheduled time for next automatic sync

**Pagination**: Results are paginated. Use `next` URL to retrieve additional models.

### Detecting Data Readiness

Determining when a model's data is ready to fetch requires different logic for initial syncs versus subsequent syncs. This distinction is critical for data integrity.

#### Initial Sync Readiness

For the **first sync** after a user connects their integration, you must wait for complete data before fetching.

**Initial Sync is Ready When:**
- `status == "DONE"` **OR** `is_initial_sync == false`

**Why This Logic**:
- **DONE required**: Initial sync must fully complete to ensure complete historical dataset
- **PARTIALLY_SYNCED not acceptable**: Partial data during initial sync represents incomplete dataset
- **is_initial_sync == false**: If you check after initial sync already completed, this flag signals readiness

**Initial Sync Pattern**:
```text
for each model in sync_status.results:
    if model.status == "DISABLED":
        continue

    # Initial sync readiness check
    initial_sync_ready = (
        model.status == "DONE"
        OR
        model.is_initial_sync == false
    )

    if initial_sync_ready:
        # Safe to fetch complete historical data
        fetch_initial_data(model.model_id)
```

#### Subsequent Sync Readiness

After the initial sync completes, subsequent syncs can accept partial data since you already have the historical baseline.

**Subsequent Sync is Ready When:**
- `status == "DONE"` **OR** `status == "PARTIALLY_SYNCED"` **OR** `is_initial_sync == false`

**Why This Logic**:
- **PARTIALLY_SYNCED acceptable**: You already have baseline data, partial updates are safe
- **More frequent updates**: Allows fetching incremental changes even if sync still in progress
- **is_initial_sync == false**: Indicates initial sync completed previously

**Subsequent Sync Pattern**:
```text
for each model in sync_status.results:
    if model.status == "DISABLED":
        continue

    # Check if initial sync ever completed
    if model.is_initial_sync == false:
        # Subsequent sync - can accept partial data
        subsequent_sync_ready = (
            model.status in ["DONE", "PARTIALLY_SYNCED"]
            OR
            model.is_initial_sync == false
        )

        if subsequent_sync_ready:
            # Fetch incremental updates
            fetch_incremental_data(model.model_id, last_sync_timestamp)
```

#### Combined Implementation Pattern

```text
for each model in sync_status.results:
    if model.status == "DISABLED":
        continue

    # Determine if this is initial or subsequent sync
    is_first_sync = model.is_initial_sync == true

    if is_first_sync:
        # Initial sync - require DONE status
        model_ready = (model.status == "DONE")
    else:
        # Subsequent sync - accept DONE or PARTIALLY_SYNCED
        model_ready = (
            model.status in ["DONE", "PARTIALLY_SYNCED"]
        )

    if model_ready:
        fetch_data_for_model(model.model_id)
```

**Common Mistakes**:
- ❌ Accepting `PARTIALLY_SYNCED` during initial sync leads to incomplete historical data
- ❌ Only checking `status == "DONE"` will miss models ready from previous syncs
- ❌ Not distinguishing between initial and subsequent sync logic

✅ Use stricter logic for initial sync, more permissive logic for subsequent syncs

**Edge Cases**:
- **DISABLED models**: Always skip - integration doesn't support this model
- **FAILED status with is_initial_sync=false**: Data from previous successful sync may still be available
- **SYNCING status with is_initial_sync=false**: Previous sync data is available, new sync in progress for updates

### Trigger Detection Methods

Your application needs a mechanism to detect when new data becomes available from Merge. There are two approaches: webhooks (real-time) and polling (periodic checks). Both provide the same `last_sync_finished` timestamp needed for incremental fetching.

#### Webhooks (Real-Time)

Merge sends HTTP POST requests to your application's webhook endpoint when syncs complete. Webhooks provide the `last_sync_finished` timestamp immediately, eliminating the need to poll `/sync-status`.

##### Webhook Types

Merge offers two webhook types for sync detection, each suited for different use cases:

**1. Linked Account Synced Webhook** (`LinkedAccount.sync_completed`)

Best for detecting initial sync completion and account-level sync events.

**When to Use**:
- Detecting initial sync completion (payload includes `is_initial_sync` flag)
- Getting sync status for all models in one notification
- Simpler setup - one webhook subscription per linked account

**Sample Payload**:
```json
{
  "hook": {
    "id": "e8affe31-8ae0-4b37-8c50-d86303094dc4",
    "event": "LinkedAccount.sync_completed",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "id": "4ac10f37-c656-4e9a-89a1-1b04f9e9a343",
    "integration": "BambooHR",
    "integration_slug": "bamboohr",
    "category": "hris",
    "end_user_origin_id": "org_123_hris",
    "status": "COMPLETE"
  },
  "data": {
    "is_initial_sync": true,
    "integration_name": "BambooHR",
    "integration_id": "bamboohr",
    "sync_status": {
      "hris.Employee": {
        "last_sync_finished": "2024-01-15T10:29:15Z",
        "last_sync_result": "DONE"
      },
      "hris.Company": {
        "last_sync_finished": "2024-01-15T10:28:30Z",
        "last_sync_result": "DONE"
      },
      "hris.TimeOff": {
        "last_sync_finished": "2024-01-15T10:30:45Z",
        "last_sync_result": "PARTIALLY_SYNCED"
      }
    }
  }
}
```

**Key Fields**:
- `data.is_initial_sync`: Boolean indicating if this is the first sync
- `data.sync_status`: Object with all models and their sync results
- Each model includes `last_sync_finished` and `last_sync_result`

**Use Case**: Process webhook, extract `last_sync_finished` for each model, trigger data fetching

---

**2. Common Model Synced Webhook** (`{common_model}.synced`)

Best for granular, model-specific sync notifications during subsequent syncs.

**When to Use**:
- High-volume data scenarios ("best if you have a lot of data to keep in sync")
- Want immediate notification when specific models complete syncing
- Need fine-grained control over which models trigger fetching

**Sample Payload**:
```json
{
  "hook": {
    "id": "e8affe31-8ae0-4b37-8c50-d86303094dc4",
    "event": "Employee.synced",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "id": "a3602c03-aba7-4d9d-a349-dbc338504092",
    "integration": "BambooHR",
    "integration_slug": "bamboohr",
    "category": "hris",
    "end_user_origin_id": "org_123_hris",
    "status": "COMPLETE"
  },
  "data": {
    "integration_name": "BambooHR",
    "integration_id": "bamboohr",
    "synced_fields": ["first_name", "last_name", "work_email"],
    "sync_status": {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "last_sync_start": "2024-01-15T10:25:00Z",
      "next_sync_start": "2024-01-15T22:25:00Z",
      "status": "DONE",
      "last_sync_result": "DONE",
      "last_sync_finished": "2024-01-15T10:29:15Z",
      "is_initial_sync": false
    }
  }
}
```

**Key Fields**:
- `data.sync_status.last_sync_finished`: Timestamp for incremental fetching
- `data.sync_status.last_sync_result`: Sync outcome (DONE, PARTIALLY_SYNCED, FAILED)
- `data.synced_fields`: List of fields that were updated (useful for optimization)

**Use Case**: Subscribe to `Employee.synced`, `Company.synced`, etc. individually, trigger fetching for only that model

---

##### Webhook Implementation Strategy

**For Initial Sync Detection**:
- Use `LinkedAccount.sync_completed` webhook
- Check `data.is_initial_sync == true`
- Process all models in `data.sync_status`
- Extract `last_sync_finished` for each model
- Trigger data fetching for models with `last_sync_result == "DONE"`

**For Subsequent Sync Detection**:
- **Option A**: Continue using `LinkedAccount.sync_completed` for simplicity
- **Option B**: Use `{CommonModel}.synced` webhooks for granular, per-model notifications
- Compare webhook's `last_sync_finished` with your stored value
- If newer, trigger incremental data fetch

**Webhook Processing Pattern**:
```text
1. Receive webhook with sync_status data
2. Extract last_sync_finished timestamp
3. Compare with your stored last_sync_finished
4. If newer:
   - Record your last_synced_at (current time)
   - Fetch: GET /model?modified_after={your_last_synced_at}&modified_before={webhook_last_sync_finished}
   - Store both timestamps
```

**Advantages**:
- Real-time updates (typically within seconds)
- No unnecessary API calls to `/sync-status`
- Efficient for frequently changing data
- Webhook provides same `last_sync_finished` data that polling would detect

**Considerations**:
- Requires publicly accessible HTTPS endpoint
- Must implement webhook signature verification for security
- Webhooks can occasionally fail (network issues, downtime)
- Should not be sole sync mechanism (use polling as backup)

**Webhook Timeout and Retry Behavior**:
- **Process asynchronously**: Webhook processing must be asynchronous to ensure prompt responses
- **30-second timeout**: If your endpoint doesn't respond within 30 seconds, Merge considers the delivery failed
- **Automatic retries**: Merge will retry failed webhooks up to 2 additional times (3 total attempts)
- **Best practice**: Return 200 OK immediately upon receipt, then process webhook payload asynchronously in background job

#### Polling (Periodic Checks)

Your application periodically calls the `/sync-status` endpoint to check if new syncs have completed.

**How It Works**:
1. Set up scheduled job (cron, task queue, etc.)
2. Periodically call `/sync-status` (frequency depends on sync cadence)
3. Compare current `last_sync_finished` with stored value
4. If newer, trigger data fetching

**Advantages**:
- Simple to implement
- No infrastructure requirements (no public endpoint needed)
- Reliable and predictable
- Works even if webhooks fail

**Considerations**:
- Delayed updates (depends on polling frequency)
- Regular API calls consume rate limits
- Trade-off between freshness and API usage

**Polling provides same data as webhooks**: The `/sync-status` response includes the same `last_sync_finished` timestamps that webhooks deliver. The only difference is timing - webhooks push immediately, polling pulls periodically.

#### Hybrid Approach (Recommended)

Use webhooks as primary mechanism with polling as backup:
- **Webhooks**: Handle most updates in real-time via `LinkedAccount.sync_completed` or `{CommonModel}.synced`
- **Polling**: Run periodically (e.g., every 1-6 hours) to catch missed webhooks
- **Result**: Guaranteed data freshness with real-time benefits

**Implementation**:
- Subscribe to webhooks for real-time notifications
- Implement polling job as safety net
- Both use same timestamp comparison logic
- Deduplication happens naturally (compare `last_sync_finished` before fetching)

### Incremental Syncing with Timestamp Parameters

After the initial sync, use `modified_after` and `modified_before` query parameters to fetch only records that changed within specific time windows.

**Pattern**:
```text
GET /api/{category}/v1/{model}?modified_after=2024-01-15T10:30:00Z&modified_before=2024-01-15T22:46:41Z
```

**Timestamp Strategy**:

You need to track TWO timestamps per model:

1. **`last_synced_at`** (Your timestamp): When YOUR backend started fetching data from Merge
2. **`last_sync_finished`** (Merge's timestamp): When Merge completed syncing from the third-party system

**How It Works**:

**Detecting New Data**:
1. Poll `/sync-status` to get Merge's current `last_sync_finished` timestamp
2. Compare with your stored `last_sync_finished` from previous fetch
3. If newer → new data available from Merge

**Fetching New Data**:
1. Record current time as `last_synced_at` (when you start fetching)
2. Fetch data: `GET /employees?modified_after={your_last_synced_at}&modified_before={merge_last_sync_finished}`
3. Store both timestamps for next fetch:
   - Store your `last_synced_at` for next `modified_after` parameter
   - Store Merge's `last_sync_finished` for detecting future syncs

**Why This Pattern**:
- `modified_after` = YOUR last fetch start time (prevents duplicate fetches)
- `modified_before` = Merge's sync finish time (creates bounded window)
- Creates precise time window capturing only new data since your last fetch
- Prevents missing records modified during sync process

**Example Flow**:

```text
# Initial state: No previous fetch
Poll /sync-status → last_sync_finished = 2024-01-15T10:30:00Z
Detect: New data available (first fetch)

# Start fetching
last_synced_at = current_time() = 2024-01-15T10:35:00Z
Fetch: GET /employees?modified_before=2024-01-15T10:30:00Z
Store: last_synced_at = 2024-01-15T10:35:00Z, last_sync_finished = 2024-01-15T10:30:00Z

# Next poll
Poll /sync-status → last_sync_finished = 2024-01-15T22:46:41Z
Detect: New data (timestamp changed from 10:30 to 22:46)

# Fetch incremental update
last_synced_at = current_time() = 2024-01-15T22:50:00Z
Fetch: GET /employees?modified_after=2024-01-15T10:35:00Z&modified_before=2024-01-15T22:46:41Z
Store: last_synced_at = 2024-01-15T22:50:00Z, last_sync_finished = 2024-01-15T22:46:41Z
```

**Benefits**:
- Reduced API response sizes (only fetch changes)
- Faster data processing
- Lower bandwidth usage
- Prevents duplicate data fetches
- More efficient rate limit usage
- Precise time windows for data consistency

**Applies To**:
All standard models (Employee, Company, TimeOff, Team, Location, etc.)

### On-Demand Resyncs

Beyond automatic syncing, Merge allows manual sync triggers when you need immediate data refresh.

**Use Cases**:
- User requests data refresh
- Debugging data inconsistencies
- Initial data population for new features
- Recovery after extended downtime

**API Endpoint**:
```text
POST /api/{category}/v1/sync-status/resync
```

**Sync Modes**:

**Full Resync**:
```json
{
  "sync_type": "FULL"
}
```
- Fetches complete dataset (like initial sync)
- Resets sync state for all models
- Use sparingly (resource intensive)

**Incremental Resync**:
```json
{
  "target": "hris.Employee",
  "sync_type": "INCREMENTAL"
}
```
- Fetches only changes since last sync
- Targets specific model
- Lighter weight, faster completion

**Granular Control**:
- Specify individual models to resync
- Avoid unnecessary full syncs
- Balance freshness needs with API efficiency

**Response**:
Returns sync status showing updated sync states for affected models.

### Sync Timing Considerations

#### Automatic Sync Frequency

Merge's sync frequency varies significantly based on the customer's plan tier, specific integration, and category.

**Frequency by Plan Tier**:
- **Default/Standard Plan**: ~24 hours between syncs
- **Higher-Tier Plans**: As frequent as every 5 minutes (varies by integration and category)
- Frequency is determined by Merge and cannot be manually configured
- Check `next_sync_start` field in `/sync-status` to see when next sync is scheduled

**Why This Matters for Implementation**:

The sync frequency directly impacts your polling and data fetching strategy:

**For 24-Hour Sync Frequency (Standard Plan)**:
- Polling every 10 minutes is inefficient - wastes API rate limits
- Consider polling once per hour or relying primarily on webhooks
- `PARTIALLY_SYNCED` status less common since syncs are infrequent
- Data freshness naturally limited to 24-hour windows

**For High-Frequency Syncs (5-15 minutes)**:
- More frequent polling (every 5-10 minutes) becomes valuable
- Accepting `PARTIALLY_SYNCED` status provides near-real-time updates
- Higher data freshness expectations from users
- Webhooks become more critical for real-time responsiveness

**Dynamic Polling Strategy**:

Consider adapting your polling interval based on the integration's sync frequency:

```text
if next_sync_start - last_sync_start < 1 hour:
    # High-frequency integration
    poll_interval = 5-10 minutes
    accept_partial_synced = true
else:
    # Standard frequency integration
    poll_interval = 30-60 minutes
    accept_partial_synced = false (unless initial sync complete)
```

**Key Takeaway**: Use the `next_sync_start` field to understand each integration's sync cadence and adjust your polling strategy accordingly. One-size-fits-all polling may be inefficient for 24-hour syncs or too slow for 5-minute syncs.

#### Rate Limits

- Respect Merge's rate limits when polling or fetching data
- Webhook processing happens outside your rate limit
- On-demand resyncs count toward limits
- Frequent polling for high-frequency syncs consumes more rate limit quota

#### Data Freshness Trade-offs

- **Real-time**: Webhooks (seconds to minutes) - best for high-frequency syncs
- **Near real-time**: Frequent polling (5-15 minutes) - matches high-frequency sync cadence
- **Hourly**: Moderate polling (30-60 minutes) - appropriate for standard 24-hour syncs
- **Batch**: Daily polling (24-hour lag) - minimum viable for standard plan integrations
- Choose based on integration's sync frequency, business requirements, and API budget

## Common Gotchas

### MergeLink Initialization
- `MergeLink.initialize()` prepares the modal but doesn't show it
- Must explicitly call `MergeLink.openLink()` to display modal
- This is the most common integration mistake

### Relinking Process
- Same end_user_origin_id and account_token preserved
- Only refreshes credentials/permissions on Merge's side
- No database changes needed on your side during relinking

### Delete Account API
- Uses POST method, not DELETE: `POST /api/{category}/v1/delete-account`
- Requires both Authorization header and X-Account-Token header
- Should clean up both Merge account and local database records

## End User Origin ID Strategy

The `end_user_origin_id` format is a foundational architectural decision that affects your entire integration system. Choose your strategy early - it impacts database design, UX patterns, and migration complexity.

### Strategy 1: One Integration per Category
**Best for: Standard applications with straightforward integration needs**

**Format**: `{organization_id}_{category}`
- Example: `"org_123_hris"`, `"org_123_ats"`, `"org_123_crm"`

**What it means**:
- Each organization can connect one HR system, one ATS, one CRM, etc.
- One integration per category
- If they want to switch from BambooHR to Workday, they replace the existing integration

**Database Pattern:**
```sql
-- Unique constraint per category
UNIQUE(organization_id, category)
```

**Pros**:
- Simple to implement and maintain
- Clear, predictable structure
- Easy to understand and debug

**Cons**:
- Cannot connect multiple systems in the same category
- Less flexible for complex organizational needs

---

### Strategy 2: Multiple Integrations per Category
**Best for: Applications requiring flexibility and data aggregation**

**Format**: `{organization_id}_{category}_{unique_id}`
- Example: `"org_123_hris_550e8400-e29b-41d4-a716-446655440000"`

**What it means**:
- Organizations can connect unlimited integrations per category
- Multiple HR systems, multiple ATS platforms, etc. can coexist
- Each connection gets a unique identifier
- Good for companies with multiple subsidiaries, regions, or environments

**Database Pattern:**
```sql
-- No constraint on integration_slug - multiple connections allowed per category
-- Only constraint is on end_user_origin_id uniqueness
UNIQUE(end_user_origin_id)
```

**ID Generation**:
```python
import uuid

def generate_end_user_origin_id(organization_id, category):
    """Strategy 2: Multiple integrations per category"""
    unique_id = str(uuid.uuid4())  # Full UUID for guaranteed uniqueness
    return f"{organization_id}_{category}_{unique_id}"
```

**Key Implementation Details**:
- Integration details (name, slug) are populated **after** the user completes linking
- User selects the integration through Merge's interface (not predetermined)
- Optional: Add `display_name` field for user-facing organization (e.g., "Production", "US Region")
- **⚠️ CRITICAL**: Must implement incomplete attempt handling (see merge_backend_implementation.md)
  - Save `end_user_origin_id` BEFORE user opens Merge Link
  - Reuse same ID for retry attempts to avoid duplicate incomplete accounts in Merge dashboard

**Pros**:
- Unlimited flexibility - connect as many integrations as needed
- Works with simple "Connect" button (no custom UI required)
- Supports complex organizational structures
- More secure (doesn't expose predictable patterns)
- Guaranteed uniqueness (UUID collision is virtually impossible)

**Cons**:
- Slightly more complex implementation
- Need to handle potential data conflicts across multiple sources
- Longer ID strings (but this doesn't impact functionality)

---

## Decision Guide

**Choose Strategy 1 if**:
- Users will only need one integration per category
- You want the simplest possible implementation
- Your application has standardized, single-platform workflows
- Target market: Small to medium businesses with straightforward needs

**Choose Strategy 2 if**:
- Users might need multiple integrations per category
- You want flexibility without complex UI requirements
- You need to support subsidiaries, regions, or multiple environments
- You might not know all use cases upfront
- Target market: Growing companies, mid-market, or enterprise customers

---

## Migration Warning

⚠️ **Choose carefully** - migrating from Strategy 1 to Strategy 2 later is complex because:
- The `end_user_origin_id` is permanent in Merge's system and cannot be changed
- Existing connections would need to be deleted and recreated with new ID format
- This causes disruption for users and potential data loss

**Recommendation**: If unsure, **choose Strategy 2 from the start**. The additional complexity is minimal, and it provides flexibility for future growth without requiring migration.