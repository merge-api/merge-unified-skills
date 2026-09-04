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

Other HRIS Common Models: `Employment`, `Team`, `Location`, `Company`, `Group`, `PayGroup`, `PayrollRun`, `EmployeePayrollRun`, `Benefit`, `EmployerBenefit`, `TimeOff`, `TimeOffBalance`, `TimesheetEntry`, `BankInfo`, `Dependent`.

> `Deduction`, `Earning`, and `Tax` are nested arrays on `EmployeePayrollRun` — they have no list endpoint and no scope of their own. Read them off the payroll run.

**Scopes to enable** for first sync: `Employee` (always), `Employment` (for job titles/pay), `Team`, `Location`.

---

## ATS — `Candidate`


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

Other ATS Common Models: `Application`, `Job`, `JobPosting`, `JobInterviewStage`, `Department`, `Office`, `RejectReason`, `Tag`, `Activity`, `Attachment`, `ScheduledInterview`, `Offer`, `Scorecard`, `EEOC`, `RemoteUser`, `Assessment`, `AssessmentTemplate`, `ScreeningQuestion`.

> The interview model is `ScheduledInterview` (endpoint `/interviews`) and the scorecard model is `Scorecard` (endpoint `/scorecards`). `Interview` and `ScoreCard` are not valid model names — a scope lookup or SDK path using them will not resolve.

**Scopes to enable** for recruiting workflows: `Candidate`, `Application`, `Job`, `Activity`.

---

## CRM — `Contact`


| Field | Type | Notes |
|-------|------|-------|
| `first_name` | string | |
| `last_name` | string | |
| `account` | reference object or UUID | `{id, name, ...}` when expanded, UUID string otherwise. Extract: `typeof c.account === "object" ? c.account?.name : null` |
| `owner` | string (UUID) | FK to User (sales rep who owns) |
| `addresses` | `Array<{street1, street2, city, state, postalCode, country, addressType}>` | Postal addresses — array of objects, NOT a string |
| `email_addresses` | `Array<{emailAddress, emailAddressType}>` | Extract primary: `c.emailAddresses?.[0]?.emailAddress` — NOT a string |
| `phone_numbers` | `Array<{phoneNumber, phoneNumberType}>` | Extract primary: `c.phoneNumbers?.[0]?.phoneNumber` — NOT a string |
| `last_activity_at` | datetime | |

> **Field shapes matter.** `email_addresses`, `phone_numbers`, and `addresses` are arrays of objects, not strings. `account` is either a reference object (with `.name`, `.id`) or a UUID depending on whether the `expand` parameter was used. See the extraction patterns above.

Other CRM Common Models: `Account`, `Lead`, `Opportunity`, `Stage`, `Task`, `Note`, `Engagement`, `User`, `CustomObject`, `Association`.

**Scopes to enable** for sales pipeline: `Contact`, `Account`, `Opportunity`, `Stage`, `User`.

---

## Accounting — `Invoice`


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

Other Accounting Common Models: `Account`, `Contact`, `JournalEntry`, `Transaction`, `GeneralLedgerTransaction`, `Payment`, `PaymentMethod`, `PaymentTerm`, `Expense`, `ExpenseReport`, `CreditNote`, `VendorCredit`, `PurchaseOrder`, `SalesOrder`, `Item`, `ItemFulfillment`, `TrackingCategory`, `TaxRate`, `AccountingPeriod`, `CompanyInfo`, `Project`, `Employee`, `BalanceSheet`, `IncomeStatement`, `CashFlowStatement`.

> **There is no `Vendor` Common Model.** Vendors and suppliers are `Contact` records with `is_supplier: true` (customers are `is_customer: true`; both flags can be true on one record). Filter or reconcile on `name`, `email_address`, and `tax_number`.

**Scopes to enable** for financial reporting: `Invoice`, `Payment`, `Account`, `Contact`.

---

## Ticketing — `Ticket`


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

Other Knowledge Base Common Models: `Container` (folders/spaces), `User`, `Group`, `Attachment`.

**Scopes to enable** for KB sync: `Article`, `Container`, `User`.

---

## Marketing — `Campaign`


| Field | Type | Notes |
|-------|------|-------|
| `name` | string | |
| `unique_opens` | integer | |
| `emails_sent` | integer | |
| `remote_created_at` | datetime | |

Other Marketing Common Models: `Contact`, `List`, `Template`, `Action`, `Event`, `Message`.

**Scopes to enable** for campaign sync: `Campaign`, `Contact`, `List`.

---

## Which endpoints accept writes

Two separate questions, and conflating them is the usual source of a wrong answer:

1. **Does the Merge API expose a write verb on this endpoint?** Answered by the table below.
2. **Does the connected provider support that write?** Answered per Linked Account at runtime — not from any table.

For (2), call `GET /{model}/meta/post` before a create to get the provider's `request_schema` for that account, including which fields are actually required. `GET /available-actions` returns each model's `available_operations` (`FETCH`, `CREATE`, …), `required_post_parameters`, and `supported_fields` for the connected integration. A `POST` that the API accepts can still come back with entries in `warnings` because the provider rejected fields — always read `warnings` on the response, not just the status code.

Every write returns an envelope, never the bare object:

```json
{ "model": { ... }, "warnings": [ ... ], "errors": [ ... ] }
```

The table below is the API surface as of the current schema. Verbs are shown against the collection path; `PATCH` sits on `/{path}/{id}`.

### HRIS

| Endpoint | Supported verbs |
|---|---|
| `/employees` | GET, POST |
| `/time-off` | GET, POST |
| `/timesheet-entries` | GET, POST |

Read-only (GET): `/bank-info`, `/benefits`, `/companies`, `/dependents`, `/employee-payroll-runs`, `/employer-benefits`, `/employments`, `/groups`, `/locations`, `/pay-groups`, `/payroll-runs`, `/teams`, `/time-off-balances`

### ATS

| Endpoint | Supported verbs |
|---|---|
| `/activities` | GET, POST |
| `/applications` | GET, POST |
| `/assessment-templates` | GET, POST |
| `/assessments` | GET, POST, PATCH |
| `/attachments` | GET, POST |
| `/candidates` | GET, POST, PATCH |
| `/interviews` | GET, POST |

Read-only (GET): `/departments`, `/eeocs`, `/job-interview-stages`, `/job-postings`, `/jobs`, `/offers`, `/offices`, `/reject-reasons`, `/scorecards`, `/tags`, `/users`

### CRM

| Endpoint | Supported verbs |
|---|---|
| `/accounts` | GET, POST, PATCH |
| `/contacts` | GET, POST, PATCH |
| `/engagements` | GET, POST, PATCH |
| `/leads` | GET, POST |
| `/notes` | GET, POST |
| `/opportunities` | GET, POST, PATCH |
| `/tasks` | GET, POST, PATCH |

Read-only (GET): `/custom-object-classes`, `/engagement-types`, `/stages`, `/users`

### Accounting

| Endpoint | Supported verbs |
|---|---|
| `/accounts` | GET, POST |
| `/attachments` | GET, POST |
| `/bank-feed-accounts` | GET, POST |
| `/bank-feed-transactions` | GET, POST |
| `/contacts` | GET, POST, PATCH |
| `/credit-notes` | GET, POST, PATCH |
| `/expense-reports` | GET, POST |
| `/expenses` | GET, POST |
| `/invoices` | GET, POST, PATCH |
| `/item-fulfillments` | GET, POST |
| `/items` | GET, POST, PATCH |
| `/journal-entries` | GET, POST |
| `/payments` | GET, POST, PATCH |
| `/purchase-orders` | GET, POST |
| `/sales-orders` | GET, POST |
| `/vendor-credits` | GET, POST, PATCH |

Read-only (GET): `/accounting-periods`, `/balance-sheets`, `/cash-flow-statements`, `/company-info`, `/employees`, `/general-ledger-transactions`, `/income-statements`, `/payment-methods`, `/payment-terms`, `/projects`, `/tax-rates`, `/tracking-categories`, `/transactions`

### Ticketing

| Endpoint | Supported verbs |
|---|---|
| `/attachments` | GET, POST |
| `/comments` | GET, POST |
| `/contacts` | GET, POST |
| `/tickets` | GET, POST, PATCH |

Read-only (GET): `/accounts`, `/collections`, `/projects`, `/roles`, `/tags`, `/teams`, `/users`

### File Storage

| Endpoint | Supported verbs |
|---|---|
| `/files` | GET, POST |
| `/folders` | GET, POST |

Read-only (GET): `/drives`, `/groups`, `/users`

### Knowledge Base

Every endpoint in this category is read-only (GET): `/articles`, `/attachments`, `/containers`, `/groups`, `/users`

### Marketing

| Endpoint | Supported verbs |
|---|---|
| `/actions` | GET, POST |
| `/automations` | GET, POST |
| `/campaigns` | GET, POST |
| `/contacts` | GET, POST |
| `/lists` | GET, POST |
| `/templates` | GET, POST |

Read-only (GET): `/emails`, `/events`, `/messages`, `/users`

⚠️ **Marketing Automation has no public API reference and no SDK namespace.** The `mktg` endpoints above exist and `mktg` is a valid `categories` value on a link_token, but there is no docs page for the category and no client exposes `merge.mktg.*`. Build against the raw REST endpoints and verify each one against a live Linked Account before promising it to a customer.

⚠️ **`DELETE` is not part of the Common Model surface.** `DELETE /field-mappings/{field_mapping_id}` is the only `DELETE` verb in the whole Unified API. Removing a Linked Account is `POST /delete-account`, not an HTTP `DELETE`. To remove a record on the provider, use Passthrough.

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

## Two list parameters that change what rows come back

Every list endpoint in every category accepts these, and both default to off. If your row counts don't match what the customer sees in the provider, check these before anything else.

| Parameter | What it adds |
|---|---|
| `include_deleted_data` | Records deleted in the third-party platform, so you can propagate the deletion instead of inferring it from a row's absence. Coverage varies by integration — native deletion detection is free with limited coverage, full coverage is a paid add-on. |
| `include_shell_data` | Shell records: rows that exist but are empty. They may carry some metadata, and every other field is `null`. |

⚠️ **Shell records will trip mapping code that assumes fields are populated.** If you pass `include_shell_data=true`, every field you read has to tolerate `null`. Leave it off unless you specifically need the placeholder rows.

## Remote Data

Each Common Model record can include a `remote_data` field with the raw provider response. Useful when you need a provider-specific field that isn't on the Common Model.

Enable Remote Data per model in the dashboard: **Configuration → Scopes → toggle Remote Data**, then pass `include_remote_data=true` on the request. Remote Data is only available on Professional and Enterprise plans — on Launch the toggle isn't there and the field comes back null.

```python
# After enabling Remote Data
employee = merge.hris.employees.retrieve(id="...", include_remote_data=True)
print(employee.remote_data)  # raw provider payload
```

## Field Mappings

When a customer asks "where's my Salesforce custom field X?", the answer is Field Mappings. Map a provider-specific remote field to a named field on the Common Model, then it appears in every API response alongside the standard fields.

This is how you get custom fields beyond what the Common Model provides — critical for production integrations where customers have provider-specific data.

Configure at: `https://app.merge.dev/configuration/field-mappings`

See `/merge-unified:post-connection-enable-custom-fields` for the full implementation guide.
