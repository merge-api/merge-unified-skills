# Apideck → Merge Concept Mapping

## Core concepts

| Apideck concept | Merge equivalent | Notes |
|---|---|---|
| API Key | API Key | Both use a single API key. Merge keys start with `test_` or `production_`. Apideck keys have no prefix convention. |
| App ID (`x-apideck-app-id`) | _(not needed)_ | Merge API keys are already scoped to one app. No separate App ID. |
| Consumer ID (`x-apideck-consumer-id`) | `end_user_origin_id` | Both represent your internal user/account ID. In Merge, this is set once when creating a `link_token`, then embedded in the resulting `account_token`. |
| Service ID (`x-apideck-service-id`) | _(baked into account_token)_ | Apideck requires a service_id per API call to select the provider. Merge's `account_token` is already scoped to one provider — no need to specify. |
| Connection | Linked Account | Both represent one end-user's authenticated connection to one provider. |
| Vault | Merge Link | Both are the UI component that lets end-users authorize access to their provider. |
| Vault Session | `link_token` | Server-generated, short-lived token that authorizes one connection flow. |
| _(implicit on connection)_ | `public_token` → `account_token` exchange | Merge requires an explicit token exchange after the user completes Link. Apideck does not — the connection is created directly. |
| Unified API | Unified API | Same concept. Both normalize provider-specific data into a common schema. |
| Common Schema fields | Common Model fields | Same concept, different field names. See "Field name mapping" below. |

## Authentication header mapping

| Apideck header | Merge header | Notes |
|---|---|---|
| `Authorization: Bearer {API_KEY}` | `Authorization: Bearer {API_KEY}` | Same pattern. |
| `x-apideck-app-id: {APP_ID}` | _(not needed)_ | |
| `x-apideck-consumer-id: {CONSUMER_ID}` | `X-Account-Token: {ACCOUNT_TOKEN}` | Different concept: Apideck scopes by consumer, Merge scopes by Linked Account. |
| `x-apideck-service-id: {SERVICE_ID}` | _(not needed)_ | Baked into the account_token. |

## URL structure

| Apideck | Merge |
|---|---|
| `https://unify.apideck.com/hris/employees` | `https://api.merge.dev/api/hris/v1/employees` |
| `https://unify.apideck.com/crm/contacts` | `https://api.merge.dev/api/crm/v1/contacts` |
| `https://unify.apideck.com/ats/applicants` | `https://api.merge.dev/api/ats/v1/candidates` |
| `https://unify.apideck.com/accounting/invoices` | `https://api.merge.dev/api/accounting/v1/invoices` |
| `https://unify.apideck.com/file-storage/files` | `https://api.merge.dev/api/filestorage/v1/files` |
| `https://unify.apideck.com/issue-tracking/tickets` | `https://api.merge.dev/api/ticketing/v1/tickets` |

Key differences:
- Merge adds `/api/` prefix and `/v1/` version
- Category names differ: Apideck `file-storage` → Merge `filestorage`, Apideck `issue-tracking` → Merge `ticketing`
- Model names differ: Apideck `applicants` → Merge `candidates`

## SDK package mapping

| Language | Apideck package | Merge package |
|---|---|---|
| Python | `apideck-unify` (new) / `apideck` (legacy) | `MergePythonClient` |
| Node/TS | `@apideck/unify` (new) / `@apideck/node` (legacy) | `@mergeapi/merge-node-client` |
| Java | `apideck-libraries/sdk-java` | `dev.merge:merge-java-client` |
| Go | `apideck-libraries/sdk-go` | `github.com/merge-api/merge-go-client/v2` |
| Ruby | _(no official gem)_ | `merge_ruby_client` |
| C# | `apideck-libraries/sdk-csharp` | `Merge.Client` |

## Pagination mapping

**Apideck:**
```json
{
  "status_code": 200,
  "data": [ ... ],
  "meta": {
    "items_on_page": 20,
    "cursors": {
      "previous": "cursor_prev",
      "current": "cursor_current",
      "next": "cursor_next"
    }
  }
}
```

**Merge:**
```json
{
  "next": "cursor_next_or_null",
  "previous": "cursor_prev_or_null",
  "results": [ ... ]
}
```

Migration: `response.data` → `response.results`, `response.meta.cursors.next` → `response.next`.

## Common field name differences (HRIS — Employee)

| Apideck field | Merge field | Notes |
|---|---|---|
| `id` | `id` | Same — both use their own internal UUID |
| `first_name` | `first_name` | Same |
| `last_name` | `last_name` | Same |
| `display_name` | `display_full_name` | Different field name |
| `emails[].email` | `work_email`, `personal_email` | Apideck uses array, Merge uses flat fields |
| `phone_numbers[].number` | `mobile_phone_number` | Similar flattening |
| `employment_status` | via `Employment` model | Merge normalizes employment into a separate model |
| `department` | `team` (FK to Team) | Merge uses `Team` model, Apideck uses string |
| `manager.id` | `manager` (FK UUID) | Same concept, slightly different shape |
| `jobs[].title` | via `Employment.job_title` | Merge separates into Employment model |

Note: This table covers the most common fields. For a complete field mapping, compare the Apideck and Merge API references for your specific category.
