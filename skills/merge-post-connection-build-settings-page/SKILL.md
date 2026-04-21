---
name: merge-post-connection-build-settings-page
description: Build a dedicated integration settings page that lets end users manage their connected integrations — reconnect, view health status, and adjust configuration. Use as Step 2 of post-connection implementation after completing Merge Link setup.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Building a Dedicated Integration Settings Page

## Purpose

A dedicated settings page prevents "silent failure" — credentials expire, permissions change, and customers need a self-service way to fix their integration without filing a support ticket. This page is the persistent home for integration configuration, not a one-time setup wizard.

## Prerequisites

- `merge-post-connection-set-context` complete
- All 4 backend endpoints from `merge-link-implement-backend` working — these are routes on your server (e.g. `/api/merge/create-link-token`), not Merge API endpoints

## Implementation Prompt

Build a settings page with three core components:

### Component 1: Connection Health Banner

Fetch account status from `linked_accounts` in your DB, supplemented by `GET https://api.merge.dev/api/{category}/v1/account-details` (with `Authorization` and `X-Account-Token` headers) for live connection health. Render one of three states:

- **Connected** (green) — auth valid, sync running normally
- **Needs Attention** (yellow) — partial sync, missing permissions, or degraded access
- **Broken** (red) — auth failure; user must relink

Always show: integration name, integration logo, and last sync time.

### Component 2: Reconnect / Relink Button

- **Strongly recommended:** keep this button always visible, not only shown when the connection is broken — users lose trust if they can't find reconnect until something breaks
- On click: call `POST /api/merge/relink-integration` to get a fresh link token, then open the Merge Link modal
- On successful relink: refresh the health banner without a full page reload
- Button label: "Reconnect [Integration Name]" — not "Reconnect via Merge"

### Component 3: Configurable Settings Panel

- Render integration-specific settings (sync scope, field mappings, account selection, etc.) as editable form fields stored in your DB
- Settings must be editable after initial setup — not a one-time wizard
- Show a visible "Setup incomplete" indicator when required settings are missing

## UX Requirements

- Reconnect CTA is recommended to always be available, even when the connection is healthy
- Error states are actionable: show what's wrong, who must fix it (end user / admin / support), and what to do next — never generic "something went wrong"
- This page is the "home" for configuration — users return here to update settings, not just during initial setup

## Testing Checklist

- [ ] Settings page loads with current connection status
- [ ] Reconnect button is visible at all times (recommended — not just on error)
- [ ] Relink flow opens Merge Link modal and updates health banner on success
- [ ] Health banner shows actionable state (not generic "error")
- [ ] Settings panel shows "Setup incomplete" when required config is missing
- [ ] All settings are editable after initial setup
