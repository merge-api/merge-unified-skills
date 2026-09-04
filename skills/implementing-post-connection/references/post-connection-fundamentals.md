# Merge Post-Connection Fundamentals

Reference documentation for implementing the post-connection experience with Merge.

---

## Initial Sync Overview and Best Practices

> Source: https://help.merge.dev/articles/2988671375-initial-sync-overview-and-best-practices

### Overview

Your customer just integrated their account into your product with [Merge Link](https://docs.merge.dev/merge-unified/merge-link/magic-link), what happens next? This article explains the **initial sync** - how it works, what to expect, and how to monitor it, so you can design a smooth product and user experience.

### What happens right after a Linked Account is connected?

Right after a Linked Account is successfully connected, Merge begins the **initial sync**. During the initial sync, Merge retrieves and normalizes all data that exists in the third-party that adheres to your configured [common model scopes](https://help.merge.dev/articles/5950052-what-are-common-model-scopes) and [selective sync](https://help.merge.dev/articles/9113654-selective-sync) filters.

Merge stores data as soon as we get it from the third-party - meaning you'll start to see data returned from Merge's endpoints while the initial sync is still running.

### How long does the initial sync take?

This initial sync can take anywhere from a few minutes to hours, depending on:

- amount of data to be synced (eg. 100 employees v/s 10K employees in HRIS)
- the third-party's API rate limits (some 3P have harsh rate limits like 60 queries per min)
- the integration connected (3P API performance and response formats)

For typical accounts, you can usually expect the initial sync to complete in few hours, but large accounts could take over 24 hours.

_Because of the significant variability, Merge can't commit to specific initial sync completion times with customers._

### How do I know when the initial sync is complete?

There are three ways to monitor initial sync progress:

- Poll `GET /sync-status` for overall and per-common model sync progress
- Subscribe to the `Linked account synced` webhook to be notified when the initial sync completes
- Subscribe to the `Common model synced` webhook to be notified when the initial sync completes for a common model. This is useful if your product depends on a specific common model.

#### The /sync-status endpoint

Sample response from [GET /sync-status](https://docs.merge.dev/merge-unified/hris/data-management/sync-status/list) during the initial sync:

```json
{
  "results": [
    {
      "model_name": "Employee",
      "model_id": "hris.Employee",
      "last_sync_start": "2025-11-27T10:39:49.905833Z",
      "next_sync_start": null,
      "last_sync_result": null,
      "last_sync_finished": null,
      "status": "SYNCING",
      "is_initial_sync": true
    }
  ]
}
```

**Note:**

- `is_initial_sync = true` identifies initial sync
- `status` reflects current progress per common model (Employee model in above sample).
- `status = DONE` would mean sync is complete. [Sync status definitions](https://help.merge.dev/articles/8184193-what-are-merge-s-sync-statuses#sync-status-definitions-0)

**Recommended polling cadence:**

- Start at every 15-30 seconds for the first 2-3 minutes.
- Back off to every 1-5 minutes
- Stop polling once `status = DONE` is reported.

#### Linked account synced webhook

The **Linked account synced** webhook can notify when the initial sync completes. You can configure this webhook on the [Webhooks](https://app.merge.dev/configuration/webhooks) management console in your Merge dashboard. [Learn more](https://docs.merge.dev/merge-unified/reading-data/webhooks/merge-webhooks)

What it does:

- Fires once per Linked Account when the sync is complete across common models.
- Payload includes `is_initial_sync = true` so you can distinguish this event from subsequent routine syncs.

Sample **Linked account synced** webhook payload for a ticketing category linked account:

```json
{
  "hook": {
    "id": "2fa2b314-33c6-48d5-9eb8-683dc5754429",
    "event": "LinkedAccount.sync_completed",
    "target": "https://yourapp.com/webhooks/merge"
  },
  "linked_account": {
    "id": "7841ee0a-5a1a-44db-bc7e-2912d8c17515",
    "integration": "Azure DevOps",
    "integration_slug": "azure-devops",
    "category": "ticketing",
    "end_user_origin_id": "TEST_AUM6QPMP",
    "end_user_organization_name": "Acme Corp",
    "end_user_email_address": "customer@example.com",
    "status": "COMPLETE",
    "webhook_listener_url": "https://api.merge.dev/api/integrations/webhook-listener/7hT4V5bFJBeu1fYD5Hy79rT_VCL6qBF7r1mJHGm5BRrNiJlwOEs6dg",
    "is_duplicate": null,
    "account_type": "TEST",
    "completed_at": "2025-11-26T23:54:25.835905Z"
  },
  "data": {
    "is_initial_sync": true,
    "sync_status": {
      "ticketing.TicketingAttachment": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:16:19Z"
      },
      "ticketing.Ticket": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:16:19Z"
      },
      "ticketing.Collection": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:48:01Z"
      },
      "ticketing.Role": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:22:49Z"
      },
      "ticketing.User": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:22:49Z"
      },
      "ticketing.TicketingTeam": {
        "last_sync_result": "DONE",
        "last_sync_finished": "2025-11-27T00:22:49Z"
      }
    }
  }
}
```

**Note:**

- `is_initial_sync = true` identifies initial sync.
- `status = COMPLETE` reflects all the common models in the Linked account have been synced.

**Recommendation:**

- Do not rely solely on the webhook. If you miss it, `/sync-status` polling will still show completion.
- For maximum reliability, combine both approaches: listen for the webhook for immediate updates, but poll `/sync-status` periodically as a safety net.

#### Common model synced webhook

In most scenarios, your product wouldn't need the entire data to be synced but require certain common models to start letting your users to use the integration. For example - if there is a configuration step after the initial connection that only requires data from `Groups` common model, you wouldn't want to wait for all the common models to sync. `Common model synced` webhook would be useful in this case which can notify with sync status of each common model.

Sample **Common model synced** webhook payload for Candidates common model in ATS category:

```json
{
  "hook": {
    "id": "e8affe31-8ae0-4b37-8c50-d86303094dc4",
    "event": "Candidate.synced",
    "target": "https://yoururl.com"
  },
  "linked_account": {
    "id": "a3602c03-aba7-4d9d-a349-dbc338504092",
    "integration": "Ashby",
    "integration_slug": "ashby",
    "category": "ats",
    "end_user_origin_id": "",
    "end_user_organization_name": "Test",
    "end_user_email_address": "customer@example.com",
    "status": "COMPLETE",
    "webhook_listener_url": "https://api.merge.dev/api/integrations/webhook-listener/IDS",
    "is_duplicate": null,
    "account_type": "PRODUCTION"
  },
  "data": {
    "integration_name": "Ashby",
    "integration_id": "ashby",
    "synced_fields": ["first_name", "last_name"],
    "sync_status": {
      "model_name": "Candidate",
      "model_id": "ats.Candidate",
      "last_sync_start": "2023-09-27T20:50:47.490402Z",
      "next_sync_start": "2023-09-11T23:24:52.242660Z",
      "status": "DONE",
      "last_sync_result": "DONE",
      "last_sync_finished": "2023-09-27T20:53:47.490402Z",
      "data_fresh_as_of": "2023-09-27T20:50:47.490402Z",
      "sync_status_reason": null,
      "is_initial_sync": true
    }
  }
}
```

**Note:**

- `is_initial_sync = TRUE` identifies initial sync.
- `model_name` identifies the common model
- `status = DONE` reflects all data in the particular common model has been synced. The model-level status values are `SYNCING`, `DONE`, `PARTIALLY_SYNCED`, `FAILED`, `DISABLED`, and `PAUSED` — `COMPLETE` belongs to the **Linked Account**, not to a model, so comparing a model status against `"COMPLETE"` never matches.

**Recommendation:**

- Do not rely solely on the webhook. If you miss it, `/sync-status` polling will still show completion.
- For maximum reliability, combine both approaches: listen for the webhook for immediate updates, but poll `/sync-status` periodically as a safety net.

### Make your product "ready" based on sync status

A tight integration between your product and the sync status is necessary to ensure a smooth user experience for your customer. No one would like to keep clicking on "_Show Employees_" to not find anyone or see an incomplete list. The following are some ideas on how you can use the initial sync status in your product to design a smooth experience for your users:

- Show a "Syncing your data" banner until initial sync complete
- Gate features that require all/some common models to be synced
- Surface high-level error with [GET /issues](https://docs.merge.dev/merge-unified/hris/linked-account/issues) endpoint or [issues webhook](https://help.merge.dev/articles/6906816-issues-webhooks) and provide "Retry" or "Contact support" guidance wherever necessary.

### Common issues and fixes

#### status = Partially Synced

You could see the status for some common models is "Partially Synced" which would mean that one or more fields for the specific Common Model failed to sync. Learn how you can [investigate the Partially synced status](https://help.merge.dev/articles/8184193-what-are-merge-s-sync-statuses#guidance-on-partially-synced-accounts-2).

#### Sync failures

A sync could fail due to various reasons - issue with the 3rd party or with Merge servers. But in any case, Merge has a robust retry mechanism built which will automatically restart the sync.

---

## Detailed Error Messaging

> Source: https://help.merge.dev/articles/7131146-detailed-error-messaging

Merge provides **detailed error messaging to provide guidance to you and your end-users on resolving any errors** during authentication and beyond.

### Merge Link

During end-user authentication via Merge Link, the system validates credentials and checks API permission scopes. When access is missing, users receive explicit remediation guidance. The example shown illustrates an account with valid credentials for Employee, Employment, Location, Team, and Group endpoints, but lacking Time-Off access — with clear instructions for resolution.

### Issues Dashboard / API

Post-linking API changes are addressed through two channels:

- **Issues Dashboard**: Contains remediation steps under "Description"
- **Issues API**: Provides detailed error messaging under "Error Details"

This allows customer success teams to **surface detailed remediation steps back to your customers** directly.

### Feature Availability

The feature rolls out per integration. Users are encouraged to report unsupported integrations for future development support.

---

## Handling Custom Fields

> Source: https://help.merge.dev/articles/6290701373-handling-custom-fields

Many third-party systems include custom fields and data points that fall outside of Merge's standard Common Models. To help you access, unify, and operationalize these fields, Merge offers several flexible mechanisms through its Supplemental Data features: [Remote Data](https://docs.merge.dev/merge-unified/supplemental-data/remote-data) and [Field Mapping](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/overview).

This guide outlines suggestions when **implementing** custom fields. It briefly outlines the options you have to **populate** Field Mappings, but for more information, refer to official documentation:

- [Mapping across an integration](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-across-an-integration)
- [Mapping for a Linked Account](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-for-a-linked-account)

### Understanding supplemental data

Before selecting an approach, it helps to understand the mechanisms Merge provides to handle custom fields:

#### Remote Data

- Remote Data lets you access the latest data from third-party integrations in its original format, even if it's not included in our Common Model
- Best for viewing extra fields where our common data model does not offer specific fields that you are interested in.
- Structure and naming depend entirely on the integration
- Remote Data will only be updated in a sync if there's a change to Common Model field. If you need updates to other non Common Model related fields found in Remote Data, you should create Field Mappings for those fields as Field Mappings are considered Common Model fields.

#### Field Mapping

- Predefine fields to extend the Merge Common Model, pre-populate these fields with your mappings, and optionally allows your customers to map their custom fields into your application's fields.
- Remote Data must be enabled to create target fields and mappings on a Common Model
- Once a Field Mapping is applied, the next scheduled sync will be a full resync and will populate the mapping(s) that you created.
- Supports:
  - Field Mapping setup in your Merge Dashboard.
  - Self-serve Field Mapping during Merge Link linking flow.
  - Programmatic Field Mapping management via the API.
- Best for reading fields from the third-party by mapping them to extend the Merge Common Model

### Approaches to reading custom fields

**Field Mappings are the primary and recommended method** for handling custom fields across integrations in Merge. They provide normalization, consistency, and flexibility by letting you define the internal schema your product requires while allowing customers to map their own custom fields to it.

Below is a breakdown of the two suggested approaches of implementing Field Mappings.

You can combine approaches! For example, you can configure a few, default fields across integrations, while also allowing your customers to create their own custom fields.

#### Approach 1: Configure pre-defined custom fields (most common)

In this approach, your team predefines **Org-wide target fields**, making sure the names of the custom fields are static. In this approach, you can even pre-populate fields with integration-specific mappings!

**When to use this approach:**

- You want full control over the custom fields your product supports.
  - For example, your data model has a field called `t_shirt_size` (or `custom_field_01`) and you want your customers to be able to define where that field comes from in their HRIS

**How it works:**

- You define the [target field names](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/target-fields) (e.g., `t_shirt_size` or `custom_field_01`) on your target Common Models.
- The target fields are either mapped [across an integration](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-across-an-integration) or [for a specific Linked Account](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-for-a-linked-account).
- Merge stores and applies the mappings.
- You ingest these mappings' values in your normal syncs from Merge to you via the [field_mappings](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/access-mapped-data) field.

#### Approach 2: Allow end-users to define their custom field names

This approach allows your customers to define their own custom field names through **Linked Account-specific target fields**.

**When to use this approach:**

- Your product allows customers to define their own custom fields.
- Every customer may have a different name for their custom fields.

**How it works:**

- Target Field Mappings are defined on a Linked Account by Linked Account basis, all with different names.
- Your syncing logic is set up to read all fields defined for a specific Linked Account - [see Handling linked account-defined targets for full details](https://help.merge.dev/articles/6290701373-handling-custom-fields?lang=en#handling-linked-account-defined-targets)

### How custom fields can be populated

There are a few different ways you or your customers can populate custom fields.

#### Across an integration, without per-Linked Account work

If a third party platform supports a field out of the box, you map the field across all Linked Accounts. This will only work with **Approach 1** outlined above.

For example, if your product has a field for an Employee's "Preferred Language". While Merge doesn't support a preferred language field in the Employee common model, some HRIS applications capture this by default. With this approach, you can extend Merge's common model with a `language` field across various integrations!

#### Per Linked Account, by you, in the Merge Dashboard

Your Support team, Implementation team, or Customer Success team can provide white glove support to your customers by populating Field Mappings within the Merge Dashboard. This will work with both **Approach 1** and **Approach 2** outlined above. See official documentation for the full process:

- [Populating Field Mappings for a Linked Account](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-for-a-linked-account)

#### Per Linked Account, by your customer, in Merge Link

Your customers can self-serve the population of Field Mappings directly in Merge Link. This will work with both **Approach 1** and **Approach 2** outlined above. See official documentation for the full process:

- [Populating Field Mappings for a Linked Account](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/mapping-for-a-linked-account)

#### Per Linked Account, through a custom mapping UI in your product

This approach relies on Field Mappings via API. This feature is only available to Merge customers on the **Enterprise plan**.

This approach gives customers end-to-end control over field mappings **inside your own product**, powered by Merge's Field Mapping APIs. This will only work with **Approach 1** outlined above.

**When to use this approach:**

- You want a native mapping experience deeply integrated into your product's workflow.
- You want a more advanced mapping user experience than Merge Link

**How it works:**

- Fetch current Field Mappings with `GET /field-mappings`.
- Display fields available for Field Mapping with [`GET /remote-fields`](https://docs.merge.dev/merge-unified/hris/linked-account/field-mapping/remote-fields-retrieve).
- Your UI collects user mapping selections.
- You create these mappings with [`POST /field-mappings`](https://docs.merge.dev/merge-unified/hris/linked-account/field-mapping/field-mappings-create) or update them with [`PATCH /field-mappings/{field_mapping_id}`](https://docs.merge.dev/merge-unified/hris/linked-account/field-mapping/field-mappings-partial-update). `DELETE /field-mappings/{field_mapping_id}` removes one.

> The path is `/field-mappings` (plural) on every verb, and the update and delete verbs take the mapping ID in the path. Reading current mappings is a `GET`, not a `POST`. Configuring Field Mappings through the API requires an Enterprise plan.
- Merge applies and stores the mapping(s).
- You ingest these mappings' values in your normal syncs from Merge to you via the [field_mappings](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/access-mapped-data) field.

### Incorporating Field Mappings in your syncing logic

After Field Mappings are created, they appear as additional properties on the corresponding Merge Common Model. Organization-wide targets are separated from Linked Account-specific targets so you can easily distinguish between the two. An example is provided below, but check out [official Field Mapping documentation](https://docs.merge.dev/merge-unified/supplemental-data/field-mapping/access-mapped-data) for more detail.

```json
{
    "id": "92e8a369-fffe-430d-b93a-f7e8a16563f1",
    "remote_id": "98796",
    "candidate": "2872ba14-4084-492b-be96-e5eee6fc33ef",
    "job": "52bf9b5e-0beb-4f6f-8a72-cd4dca7ca633",
    "applied_at": "2021-10-15T00:00:00Z",
    "rejected_at": "2021-11-15T00:00:00Z",
    "source": "Campus recruiting event",
    "credited_to": "58166795-8d68-4b30-9bfb-bfd402479484",
    "current_stage": "d578dfdc-7b0a-4ab6-a2b0-4b40f20eb9ea",
    "reject_reason": "59b25f2b-da02-40f5-9656-9fa0db555784",
    "remote_was_deleted": false,
    "field_mappings": {
        "organization_defined_targets": {
            "technical_assessment_score": {
                "value": 4
            },
            "max_degree": {
                "value": "Master's"
            }
        },
        "linked_account_defined_targets": {
            "previous_role": {
                "value": "Management Consultant"
            }
        }
    }
}
```

#### Handling organization-defined targets (Approach 1)

You've most likely already incorporated organization-defined targets into your syncing logic, since they are common properties across your customer base. One important detail to keep in mind is that if an organization-defined target is not mapped for a given integration or Linked Account, it will be omitted from the response.

For example, if the `max_degree` field in the example above were only mapped for the Greenhouse integration, then linking an Ashby account would result in the following response:

```json
{
    ...
    "field_mappings": {
        "organization_defined_targets": {
            "technical_assessment_score": {
                "value": 4
            }
        },
        "linked_account_defined_targets": {
            "previous_role": {
                "value": "Management Consultant"
            }
        }
    }
}
```

#### Handling linked account-defined targets (Approach 2)

Linked Account-defined targets will vary end-user by end-user, so your syncing logic should be able to account for differing values. The most common way to handle this is to iterate over the keys of the `linked_account_defined_targets` object, extracting the key, value pair. Sample code snippet below:

```javascript
const laTargets = data.field_mappings.linked_account_defined_targets || {};
const extracted = Object.entries(laTargets).map(([key, obj]) => ({
  key,
  value: obj.value
}));
```

### Frequently asked questions (FAQ)

#### Can I rely solely on remote data to access custom fields?

Partially - Remote Data always contains all fields returned from the upstream system, including custom ones. However, this approach places the burden on your engineering team to interpret each integration's raw field names and structure. If your product needs consistent field names across customers or requires capturing updates to these fields, Field Mapping is a better choice.

#### Do I need to enable Field Mapping for every integration?

No. Field Mapping is optional and configurable per category and per model. You can enable it only for object types where you expect customers will need to map custom fields (e.g., CRM Contacts or HRIS Employees).

#### Where do my end-users map fields?

Your users can map fields either:

1. **Inside Merge Link**, during account connection or later when updating their configuration, or
2. **Inside your own product**, if you choose to use Merge's Field Mapping APIs and build your own mapping UI.

#### Can Field Mappings change over time?

Yes. Customers may update remote fields in their systems or modify mapping choices. Your application should be prepared to refresh mappings periodically or fetch the latest mappings when syncing data.

---

## Data Filtering Options

> Source: https://help.merge.dev/articles/4376048505-understanding-data-filtering-options-with-merge

### Overview

The data from third party systems can be filtered in many different ways before it resides in Merge database and then further into your database or product. This guide explains different filtering approaches and help you choose the right one for your use case.

### Why Filter Your Data?

There are three primary reasons why you should consider filtering data:

1. **To store the relevant data in your database**

   You don't want to store data that won't be used in your product or isn't useful for your customers. For example, many customers using HRIS integrations filter employees by department or employment status to store only a relevant subset in their database. You can configure this as a default filter across all customer accounts, or allow admins to customize it during integration setup.

2. **To build dynamic product workflows**

   Filtering enables you to build product features where users can view and interact with specific subsets of data. For example, in HRIS integrations, allowing managers to filter their team, department within their product UI.

3. **Security and compliance**

   Controlling data access at various system levels.

### Data Flow Diagram with Filters

Data passes through multiple filter stages originating from 3rd party systems to showing up on your product UI. The diagram below illustrates how data flows through each filtering stage:

**Data flow diagram legend:**

- **Third party systems**: Could be any supported integrations of Merge, eg. BambooHR, Google Drive, etc
- **API Permissions**: End-user configuring API key/token with filter settings if available
- **Selective Sync filter**: Source-side filters applied to a third party API before data is fetched into Merge.
- **Merge database**: Merge's common model database
- **Merge API filters**: Filters supported as query params in Merge API
- **Your database**: Your product's database
- **Product filters**: Any filters you apply before showing data on your application
- **Your product/application**: The UI that your customer sees with filtered data

### Filter Options Overview

| Filter | Location | Use case | Example |
|--------|----------|----------|---------|
| API permissions | 3rd party system (configured by end-user) | End user (typically Admin) control data access and scope at source | Grant access to employees in the Sales department, US division |
| Selective Sync filter | Merge (configured by you/end-user) | Use this to avoid data explosion, and historical cut-offs | Tickets modified in last 6 months, Candidates applied in last 1 year |
| Merge API filters | Your codebase (before syncing from Merge into your database) | Let admins choose what data syncs to your product | Filter employees with Employment status = Active |
| Product filters | Your codebase (when querying your database) | Enable dynamic user-facing filters | Filter "My Team" to show up data of only our team. |

### Filter Options Before Merge Stores Data

The most effective filtering happens at the source, before data is fetched from 3rd party systems into Merge. Source-side filtering reduces sync time, lowers storage costs, and ensures unnecessary data never enters your system. There are two types of filters that can be applied at the source:

1. Filtering with API permissions
2. Selective sync filters

#### API Permissions/Credentials

While API permissions and credentials are primarily used to set scopes (what functionalities and fields are accessible) and access levels (read/write), some HRIS systems also allow filtering at the API credential level. For example, BambooHR lets you filter by employee type (eg. full-time only), location and many other fields when configuring API access.

In the example above, when this BambooHR account is connected to Merge, only the 242 filtered employees will be accessible through BambooHR's API.

> **Note:** This filtering option is available in only some HRIS systems. This includes common apps like BambooHR, HiBob, and SAP SuccessFactors. Contact us to check if this is supported for specific integrations.

**Pros:**

- No work is required on you (Merge customer) as your user would set up the filter
- Suitable for security-conscious customers as this fully prevents access to filtered data/fields

**Cons:**

- Only supported by a limited number of HRIS systems
- Less visibility for you into what data is actually being filtered

#### Selective Sync Filters

The selective sync filters in Merge allows you to configure filters that can be applied at the source, i.e. on the 3rd party APIs before fetching and storing data into Merge database. These filters can be configured by you on Merge dashboard and has options to let your users adjust these filters during the integration. It's recommended to set these filters, especially time based filters, to filter out historical data that won't be used in your product.

Most common use cases for the selective sync filter include:

- ATS: Candidates applied in the last 1 year
- File storage: Files/Folders from a specific Drive

**Pros:**

- Avoids data explosion, resulting in faster syncs and better application performance
- Can be configured by you or optionally customized by end-users during connection

**Cons:**

- Limited filtering options - depends on what's available in the 3rd party and what Merge has built
- Must be configured during integration setup; not suitable for frequently changing filters

> **Note:** Changing Selective Sync filters after a linked account is connected will only filter data in future syncs, unless a full resync is triggered.

### Filter Options After Merge Stores Data

Once data is in Merge's database, you control how it flows to your product through two filtering layers:

1. **Merge API filters** - Control what you fetch from Merge and store in your database
2. **Product filters** - Control what users see in your application

#### Merge API Filters

After passing through API permissions and Selective Sync filters, data is stored in Merge's database. You can now fetch data from Merge and store it in your database, which connects to your application. If you don't want to sync all the data, you don't have to! You can:

- Only sync and store the data that your application needs
- Allow end-users to choose which data syncs to your product

Depending on the filters your end-users setup along with data needs of your product, you pass those as query params while fetching data from Merge. We provide extensive filtering options for each of the GET endpoints. For example, GET /employees endpoint can be filtered with:

- `started_after`/`started_before`: Filter employees based on their start dates
- `employment_status`: Filter for Active/Inactive employees

You can find the entire list of supported filters on our API reference under **Query & path parameters** section.

> Use the `modified_after` API filter to sync only changed/modified data avoiding large data syncs.

**Pros:**

- Enables admin-configurable integration settings (let users choose what syncs)
- Reduces data stored in your database, lowering storage costs

**Cons:**

- Doesn't reduce data stored in Merge (only what you fetch from Merge)
- Limited to filter parameters supported by Merge API for each endpoint
- Leads to more complex syncing logic

#### Product Filters

Product filters result in the same functionality as Merge API filters - the only difference is where the filters are applied. Instead of applying filters directly on your queries to Merge, you set up a "staging" table with all employees, unfiltered. Your product then uses the filters that have been set up in your app to pull only relevant data.

**Pros:**

- Enables admin-configurable integration settings (let users choose what syncs)
- Users can change filters dynamically without any data re-syncing
- Does not complicate syncing logic

**Cons:**

- Requires more database design and indexing for performance
- Does not reduce the amount of data you store

### Example: Employee Filtering in an HRIS Integration

A common use case among Merge customers using HRIS integrations is letting end-users (typically admins) configure which employees sync to their product. This is usually implemented as part of an integration settings page in your application.

#### Using Merge API Filters

If this example used Merge API filters (pre-storage) approach, the query to the `/employees` endpoint would be:

```text
GET {base_url}/employees?employment_type=FULL_TIME&groups={group uuid 1},{group uuid 2}
```

- `employment_type=FULL_TIME` filters for full-time employees only
- `groups` parameter uses group UUIDs from the Groups common model (e.g., US Subsidiary, EU Subsidiary)

This filtered data is then stored in your database for use in your application.

#### Using Product Filters

If this example used the Product filters (post-storage) approach, the queries to Merge would not be updated. Your product would filter employee data stored in your staging table to enable dynamic, real-time filtering within your application UI.

### Considerations: Changing Filters

Some of the filters mentioned in the guide above are supposed to be persistent and shouldn't ideally change often. However, there may be scenarios where these filters need to be modified after the integration is live. The table below suggests approaches you can take when filters are changed:

| Filter being changed | Typical reason | Recommended action |
|---------------------|----------------|-------------------|
| API permissions | More employees need to be added, such as another location or department | Data for these newly included employees won't automatically sync to Merge unless a full resync is performed. Contact us to request a full resync. |
| API permissions | Some employees need to be removed from the filter, eg. US division | Data for these employees will continue to exist in the Merge database. To fully remove them, create a new linked account with the updated permissions and delete the existing one. |
| Selective Sync | You add a historical cut-off date of 2024 onwards, based on your data retention policy | Data before 2024 will continue to exist in Merge as Selective sync filters aren't retroactive |
| Merge API filters | The admin modifies the filter on the integration settings page, adding or removing some employee filters | Adjust the query parameters accordingly when fetching data from the Merge API. If you want your database to reflect the new rules for historical data, you may need to re-run your data pipeline or perform a backfill. |
| Product filters | The admin modifies the filter on the integration settings page, adding or removing some employee filters | Modify the query against your Employee staging table. |
