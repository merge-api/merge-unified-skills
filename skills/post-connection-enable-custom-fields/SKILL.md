---
name: post-connection-enable-custom-fields
description: Build a settings UI that lets customers select and enable custom fields from their connected system using Merge's Field Mapping API. Use as Step 5 of post-connection implementation when customers need access to fields beyond Merge's common models.
license: MIT
metadata:
  author: Merge
  version: 0.4.0
---

# Enable Custom Fields

Different customers have different custom fields in their HR/ATS/CRM systems — salary bands, department codes, custom job levels. Rather than hardcoding per-customer fields, a scalable pattern lets customers select which custom fields to enable through a settings UI.

## Prerequisites

Custom fields fundamentals loaded (`../implementing-post-connection/references/post-connection-fundamentals.md`).

## Before Proceeding

Three pieces of information are needed before generating any code.

If invoked from `implementing-post-connection`, the first two were answered in Step 1 — use that context. Otherwise, gather them now:

- **Categories**: Which Merge categories need custom fields? (`hris`, `ats`, `crm`, `accounting`, `ticketing`)
- **Backend Merge SDK installed?** Search for the language-appropriate package: `@mergeapi/merge-node-client`, `MergePythonClient`, `dev.merge:merge-java-client`, `merge-go-client`, `merge_ruby_client`, or `Merge.Client`. Drives whether examples below use the SDK or raw HTTP.
- **Existing field-mapping or settings UI?** If a settings page already exists (see `post-connection-build-settings-page`), the field selector inserts there rather than creating a new page.

Then choose the approach (Approach A vs B below) before writing any code — see "Choose Your Approach" immediately after.

## Choose Your Approach

Before implementing, ask the user: "There are two approaches for custom fields:

- **Approach A (Remote Data)**: raw custom field data arrives in `remote_data` alongside each record. Requires a Professional or Enterprise plan, enabling Remote Data per model in Scopes, and passing `include_remote_data=true` on each request.
- **Approach B (Field Mapping API)**: Gives customers a UI to select and map specific fields. Configuring Field Mappings via API requires a Merge Enterprise plan.

Which approach would you like to use — A, B, or both?"

Wait for the user's answer before continuing.

## Two Approaches

Choose based on your use case — you can also combine them.

### Approach A: Remote Data (simpler)

Merge passes raw custom field data alongside standard models in the `remote_data` field.

- **Requires a Professional or Enterprise plan.** On Launch the Scopes toggle isn't available and `remote_data` comes back null.
- Two steps to turn on: enable Remote Data for the model in **Configuration → Scopes**, then pass `include_remote_data=true` on the request. Neither alone is enough — with the scope off, the query param returns null; without the param, the field is omitted even when the scope is on.
- Best for: read-only access to all custom data, no customer selection needed
- Implementation: parse `remote_data` from API responses and store/display as needed
- Limitation: field names vary by integration; no guaranteed consistency across customers. Address values by their API path rather than by array index — provider ordering is not stable across syncs.

### Approach B: Field Mapping API (recommended for customer-facing selection)

**Requires Merge Enterprise plan.** Before proceeding, confirm with the user: "Approach B uses Merge's Field Mapping API, which requires an Enterprise plan. Do you have Enterprise access? If unsure, check with your Merge account team before implementing."

Gives customers a native mapping UI inside your product.

- Fetch available fields via `GET /api/{category}/v1/remote-fields` using the account token (add `include_example_values=true` for sample values)
- Display available fields in a settings UI for customers to enable and map
- Customer selects which fields to include and how to map them to your schema
- Save selections via `POST /api/{category}/v1/field-mappings`
- Merge returns mapped field values in the `field_mappings` object on subsequent API responses
- Best for: customer-controlled field selection, structured mapping to your data model

## Implementation — Approach B

1. `GET /api/{category}/v1/remote-fields?include_example_values=true` — fetch available fields for the linked account

   **The response is an object keyed by Common Model name**, not a flat list. Each value is an array of remote fields for that model:

   ```json
   {
     "Employee": [
       {
         "remote_key_name": "customFieldTShirtSize",
         "schema": { "type": "string" },
         "remote_endpoint_info": {
           "method": "GET",
           "url_path": "/v1/employees",
           "field_traversal_path": ["customFieldTShirtSize"]
         },
         "example_values": ["Large"],
         "advanced_metadata": null,
         "coverage": 0.33
       }
     ],
     "Employment": []
   }
   ```

   | Field | Type | Notes |
   |---|---|---|
   | `remote_key_name` | string | Field name in the source system |
   | `schema` | object | JSON-schema fragment, e.g. `{"type": "string"}` — the type lives here, there is no `remote_field_type` |
   | `remote_endpoint_info` | object | `{method, url_path, field_traversal_path}` — you pass all three back on create |
   | `example_values` | array or null | Only populated when `include_example_values=true` |
   | `coverage` | number or null | Fraction of records where the field has a value |

   ⚠️ **`example_values` is empty unless you pass `include_example_values=true`.** Without it, step 2's "sample value" column renders blank. Narrow the response with `common_models=Employee,Employment` when you only need specific models.

   ⚠️ **There is no `remote_field_name`, `remote_field_type`, or `common_model` field on an entry.** The Common Model comes from the key the entry sits under.

2. Render a list: field name (`remote_key_name`), which Common Model it came from (the response key), data type (`schema.type`), sample value (`example_values[0]`)
3. Customer toggles which fields to enable and assigns a target name
4. `POST /api/{category}/v1/field-mappings` — save each enabled field + target mapping

   **Required body fields:** `common_model_name`, `remote_field_traversal_path`, `remote_method`, `remote_url_path` — the last three come straight off the `remote_endpoint_info` object you got in step 1. Then either `target_field_name` + `target_field_description` to create a new Linked Account-specific target, or `organization_wide_target_field` to attach to an existing organization-wide target.

   ```json
   {
     "common_model_name": "Employee",
     "target_field_name": "t_shirt_size",
     "target_field_description": "Employee t-shirt size for swag",
     "remote_field_traversal_path": ["customFieldTShirtSize"],
     "remote_method": "GET",
     "remote_url_path": "/v1/employees"
   }
   ```

   Optional: `advanced_mapping_expression` (a JSONata expression to transform the value) and `is_integration_wide` (applies the mapping to every Linked Account on that integration — requires `organization_wide_target_field`). The `jmes_path` field is deprecated; use `advanced_mapping_expression`.
5. In sync logic: read `field_mappings.linked_account_defined_targets` and store mapped values alongside standard records

```javascript
// Reading linked account-defined targets during sync
const laTargets = record.field_mappings.linked_account_defined_targets || {};
const customFields = Object.entries(laTargets).map(([key, obj]) => ({
  key,
  value: obj.value
}));
```

## Critical Gotcha

Custom fields vary per linked account — never hardcode field names. Always fetch available fields dynamically from Merge's API for the specific account.

## Testing Checklist

- [ ] Available custom fields fetched and displayed in settings UI
- [ ] Customer can enable/disable individual fields
- [ ] Field selections persist per linked account (not globally)
- [ ] Enabled fields appear in subsequent sync data
- [ ] Field list refreshes when integration is relinked
