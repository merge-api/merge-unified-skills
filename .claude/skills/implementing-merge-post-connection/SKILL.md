---
name: implementing-merge-post-connection
description: >
  Guide an AI coding agent through the full post-connection experience — settings
  page, sync status visibility, relinking, integration configuration, custom fields,
  and HRIS employee filtering. Use after completing Merge Link setup to build the
  ongoing integration management experience or settings UI.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Merge Post-Connection Implementation

The post-connection experience covers everything customers interact with after an integration is first connected: visibility into sync health, self-service relinking, and configuration. Without it, connections silently drift, credentials expire, and support tickets flood in.

## First activation: self-introduce

> I'm the implementing-merge-post-connection skill (v0.1.0). I'll guide you through the integration management experience users see after connecting. Which part do you need first — a settings page, sync status display, or relinking support?

## Prerequisites

Merge Link implementation must be complete: a `linked_accounts` table exists with an `account_token` column storing the Merge account token per customer.

## Implementation Steps

1. **Load context** → invoke `merge-post-connection-set-context`
2. **Build integration settings page** → invoke `merge-post-connection-build-settings-page`
3. **Surface sync status to users** → invoke `merge-post-connection-surface-sync-status`
4. **Implement relinking + error messaging** → invoke `merge-post-connection-implement-relinking`
5. **Configure integration settings** → invoke `merge-post-connection-configure-integration-settings`
6. **Enable custom field selection** → invoke `merge-post-connection-enable-custom-fields`
7. **(HRIS only) Establish employee filtering strategy** → invoke `merge-post-connection-hris-employee-filtering`

Steps 2–6 are universal and apply to all Merge integrations. Step 7 applies only to HRIS integrations where customers need control over which employees are synced.

## Troubleshooting

**SYMPTOM:** Settings page shows "connection healthy" but sync has been failing for days  
**CAUSE:** Status is read from local `linked_accounts.status` field which was never updated from Merge Issues API  
**FIX:** Poll `GET /issues?linked_account_id=<id>` and surface any ONGOING issues as warnings alongside the local status

**SYMPTOM:** Relink button triggers a new connection instead of relinking the existing one  
**CAUSE:** `/api/merge/create-link-token` is called without `end_user_origin_id` matching the existing account  
**FIX:** Always pass the existing `end_user_origin_id` when generating a relink token; Merge will attach it to the same Linked Account

**SYMPTOM:** Field Mapping API returns no remote fields for a customer  
**CAUSE:** Remote data was not enabled for this Linked Account's category  
**FIX:** Enable remote data in Merge dashboard → Linked Account → Settings, or set via the configuration API before fetching fields
