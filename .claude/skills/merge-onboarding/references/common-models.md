# Common Model Reference

One section per Merge category. Lists the primary Common Model and its key fields. Use this when generating code that maps Merge data to a developer's database or types.

All Common Models share these base fields:
- `id` (string, UUID) — Merge's stable ID for this record
- `remote_id` (string) — the source provider's ID for this record
- `created_at` (datetime) — when Merge first synced this record
- `modified_at` (datetime) — when this record was last updated

Fields below are in addition to the base set.

---

## HRIS — `Employee`

Source: `merge-backend/merge/categories/hris/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `employee_number` | string | Provider's employee ID |
| `company` | string (UUID) | FK to Company |
| `first_name` | string | |
| `last_name` | string | |
| `preferred_name` | string | |
| `display_full_name` | string | Pre-formatted full name |
| `username` | string | |
| `groups` | array | FKs to Group |
| `work_email` | string | |
| `personal_email` | string | |
| `mobile_phone_number` | string | |
| `employments` | array | FKs to Employment (job_title, pay_rate, pay_period) |
| `home_location` | string (UUID) | FK to Location |
| `work_location` | string (UUID) | FK to Location |
| `manager` | string (UUID) | FK to Employee |
| `team` | string (UUID) | FK to Team |

Other HRIS Common Models: `Employment`, `Team`, `Location`, `Company`, `Group`, `PayrollRun`, `Benefit`, `TimeOff`, `BankInfo`, `Tax`.

**Scopes to enable** for first sync: `Employee` (always), `Employment` (for job titles/pay), `Team`, `Location`.

---

## ATS — `Candidate`

Source: `merge-backend/merge/categories/ats/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `first_name` | string | |
| `last_name` | string | |
| `company` | string | Free-text current company |
| `title` | string | Free-text current title |
| `remote_created_at` | datetime | When created on the source provider |
| `remote_updated_at` | datetime | When updated on the source provider |
| `last_interaction_at` | datetime | Last touch from recruiter |
| `is_private` | boolean | |

Other ATS Common Models: `Application`, `Job`, `Department`, `Office`, `RejectReason`, `Tag`, `Activity`, `Attachment`, `Interview`, `Offer`, `ScoreCard`, `EEOC`.

**Scopes to enable** for recruiting workflows: `Candidate`, `Application`, `Job`, `Activity`.

---

## CRM — `Contact`

Source: `merge-backend/merge/categories/crm/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `first_name` | string | |
| `last_name` | string | |
| `account` | string (UUID) | FK to Account (company they work for) |
| `owner` | string (UUID) | FK to User (sales rep who owns) |
| `addresses` | array | Postal addresses |
| `email_addresses` | array | `{value, email_address_type}` |
| `phone_numbers` | array | `{value, phone_number_type}` |
| `last_activity_at` | datetime | |

Other CRM Common Models: `Account`, `Lead`, `Opportunity`, `Stage`, `Task`, `Note`, `Engagement`, `User`, `CustomObject`, `Association`.

**Scopes to enable** for sales pipeline: `Contact`, `Account`, `Opportunity`, `Stage`, `User`.

---

## Accounting — `Invoice`

Source: `merge-backend/merge/categories/accounting/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `type` | enum | ACCOUNTS_RECEIVABLE, ACCOUNTS_PAYABLE |
| `contact` | string (UUID) | FK to Contact |
| `number` | string | Invoice number |
| `issue_date` | datetime | |
| `due_date` | datetime | |
| `paid_on_date` | datetime | |
| `memo` | string | |
| `company` | string (UUID) | FK to Company |

Other Accounting Common Models: `Account`, `JournalEntry`, `Transaction`, `Payment`, `Expense`, `CreditNote`, `PurchaseOrder`, `Vendor`, `Item`, `TrackingCategory`.

**Scopes to enable** for financial reporting: `Invoice`, `Payment`, `Account`, `Vendor`, `Contact`.

---

## Ticketing — `Ticket`

Source: `merge-backend/merge/categories/ticketing/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Ticket title |
| `assignees` | array | FKs to User |
| `assigned_teams` | array | FKs to Team |
| `creator` | string (UUID) | FK to User |
| `due_date` | datetime | |
| `status` | enum | OPEN, CLOSED, IN_PROGRESS, ON_HOLD |
| `description` | string | |
| `collections` | array | FKs to Collection (boards/projects) |

Other Ticketing Common Models: `Comment`, `Project`, `Collection`, `User`, `Team`, `Account`, `Contact`, `Tag`, `Attachment`.

**Scopes to enable** for support sync: `Ticket`, `Comment`, `User`, `Team`.

---

## File Storage — `File`

Source: `merge-backend/merge/categories/filestorage/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Filename |
| `file_url` | string | Direct download URL |
| `file_thumbnail_url` | string | Thumbnail (if available) |
| `size` | integer | Bytes |
| `mime_type` | string | |
| `description` | string | |
| `folder` | string (UUID) | FK to Folder |
| `checksum` | string | |

Other File Storage Common Models: `Folder`, `Drive`, `User`, `Group`, `Permission`.

**For RAG/AI use cases:** Enable `File`, `Folder`, `Permission`. Use the `file_url` to download contents and the `permissions` to enforce ACL in your retrieval layer.

**Scopes to enable** for document sync: `File`, `Folder`.

---

## Knowledge Base — `Article`

Source: `merge-backend/merge/categories/knowledgebase/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `title` | string | |
| `description` | string | Article body or summary |
| `author` | string (UUID) | FK to User |
| `last_edited_by` | string (UUID) | FK to User |
| `visibility` | enum | PUBLIC, PRIVATE, INTERNAL |
| `article_content_download_url` | string | Full content URL |
| `checksum` | string | |
| `article_url` | string | Direct link in source provider |

Other Knowledge Base Common Models: `Container` (folders/spaces), `User`, `Attachment`, `Tag`.

**Scopes to enable** for KB sync: `Article`, `Container`, `User`.

---

## Marketing — `Campaign`

Source: `merge-backend/merge/categories/mktg/tests/schema_snapshot.json`

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | |
| `unique_opens` | integer | |
| `emails_sent` | integer | |
| `remote_created_at` | datetime | |

Other Marketing Common Models: `Contact`, `List`, `Template`, `Action`, `Event`, `Message`.

**Scopes to enable** for campaign sync: `Campaign`, `Contact`, `List`.

---

## Pagination

All `.list()` endpoints return paginated results:

```json
{
  "next": "cursor_string_or_null",
  "previous": "cursor_string_or_null",
  "results": [...]
}
```

Default `page_size`: 30. Max: 100. Pass `cursor=NEXT_CURSOR` to fetch the next page.

```python
# Python pagination
next_cursor = None
while True:
    page = merge.hris.employees.list(cursor=next_cursor)
    for emp in page.results:
        process(emp)
    next_cursor = page.next
    if not next_cursor:
        break
```

## Filtering by date

Most list endpoints accept `modified_after` for incremental sync:

```python
# Get only records changed in the last 24 hours
import datetime
yesterday = datetime.datetime.utcnow() - datetime.timedelta(days=1)
page = merge.hris.employees.list(modified_after=yesterday.isoformat())
```

Use `modified_after` in your sync logic to avoid re-pulling unchanged data.

## Remote Data

Each Common Model record can include a `remote_data` field with the raw provider response. Useful when you need a provider-specific field that isn't on the Common Model.

Enable Remote Data per model in the dashboard: **Configuration → Scopes → toggle Remote Data**.

```python
# After enabling Remote Data
employee = merge.hris.employees.retrieve(id="...", include_remote_data=True)
print(employee.remote_data)  # raw provider payload
```

## Field Mappings

For provider-specific fields you want surfaced as first-class fields on the Common Model, use Field Mappings. Map a remote field to a custom field on the Common Model, then it appears in every API response.

Configure at: `https://app.merge.dev/configuration/field-mappings`
