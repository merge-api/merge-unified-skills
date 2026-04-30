---
name: merge-post-connection-enable-custom-fields
description: Build a settings UI that lets customers select and enable custom fields from their connected system using Merge's Field Mapping API. Use as Step 6 of post-connection implementation when customers need access to fields beyond Merge's common models.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Enable Custom Fields

Different customers have different custom fields in their HR/ATS/CRM systems — salary bands, department codes, custom job levels. Rather than hardcoding per-customer fields, a scalable pattern lets customers select which custom fields to enable through a settings UI.

## Prerequisites

`merge-post-connection-set-context` complete (custom fields fundamentals loaded).

## Choose Your Approach

Before implementing, ask the user: "There are two approaches for custom fields:

- **Approach A (Remote Data)**: No setup required — custom field data arrives automatically in `remote_data` alongside each record. Works on any Merge plan.
- **Approach B (Field Mapping API)**: Gives customers a UI to select and map specific fields. Requires a Merge Enterprise plan.

Which approach would you like to use — A, B, or both?"

Wait for the user's answer before continuing.

## Two Approaches

Choose based on your use case — you can also combine them.

### Approach A: Remote Data (simpler)

Merge passes raw custom field data alongside standard models in the `remote_data` field.

- No configuration needed — custom fields arrive automatically with each record
- Best for: read-only access to all custom data, no customer selection needed
- Implementation: parse `remote_data` from API responses and store/display as needed
- Limitation: field names vary by integration; no guaranteed consistency across customers

### Approach B: Field Mapping API (recommended for customer-facing selection)

**Requires Merge Enterprise plan.** Before proceeding, confirm with the user: "Approach B uses Merge's Field Mapping API, which requires an Enterprise plan. Do you have Enterprise access? If unsure, check with your Merge account team before implementing."

Gives customers a native mapping UI inside your product.

- Fetch available fields via `GET /api/{category}/v1/remote-fields` using the account token
- Display available fields in a settings UI for customers to enable and map
- Customer selects which fields to include and how to map them to your schema
- Save selections via `POST /api/{category}/v1/field-mappings`
- Merge returns mapped field values in the `field_mappings` object on subsequent API responses
- Best for: customer-controlled field selection, structured mapping to your data model

## Implementation — Approach B

1. `GET /api/{category}/v1/remote-fields` — fetch available fields for the linked account

   **Remote fields response** (each entry):

   | Field | Type | Notes |
   |---|---|---|
   | `remote_field_name` | string | Field name in the source system |
   | `remote_field_type` | string | Data type (string, number, boolean) |
   | `common_model` | string | Which Common Model this field belongs to |
   | `example_values` | array | Sample values from the source system |

2. Render a list: field name, source system, data type, sample value
3. Customer toggles which fields to enable and assigns a target name
4. `POST /api/{category}/v1/field-mappings` — save each enabled field + target mapping
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
