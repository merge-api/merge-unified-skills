---
name: merge-link-implement-frontend-marketplace
description: Implement the App Center/Marketplace UI pattern for Merge Link — a browsable integration catalog where users select and connect specific integrations. Use as Step 4b of Merge Link implementation when users should discover and connect multiple integrations.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing the App Center / Integration Marketplace

> You're implementing the **App Marketplace** pattern — a browsable catalog where users discover and connect integrations. If you'd prefer a simpler single Connect button instead, use `merge-link-implement-frontend-connect`.

Builds an integration marketplace where users browse a catalog of available integrations and click to connect specific ones. Best for products that support many integrations across multiple categories.

## Prerequisites

- `merge-link-implement-backend` complete (all 4 endpoints working)
- Merge Link SDK loaded: `<script src="https://cdn.merge.dev/initialize.js"></script>`

## Implementation

### 1. Fetch and Display the Integration Catalog

Fetch from `GET https://api.merge.dev/api/integrations/v1` — public, no auth required. Each object includes `name`, `slug`, `categories`, `image` (logo URL), `color`.

Render a grid of cards showing logo, name, and category. Optional: Add category tabs (HRIS, ATS, CRM, Accounting, Ticketing, FileStorage, Knowledge Base) so users can filter.

### 2. Per-Integration Connect Flow

Each card has its own Connect button that pre-selects that provider in the modal — users skip Merge's provider selection screen entirely.

```javascript
const connectionStatus = {}; // slug → 'connected' | 'disconnected'

function connectIntegration(category, slug, button) {
  button.disabled = true;
  button.textContent = "Connecting...";

  fetch("/api/merge/create-link-token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category, integration: slug }), // slug = single-integration mode
  })
    .then((r) => r.json())
    .then((data) => {
      if (data.success) initializeMergeLink(data.link_token, slug, button);
      else {
        alert("Failed: " + data.error);
        resetButton(button);
      }
    });
}

function initializeMergeLink(linkToken, slug, button) {
  MergeLink.initialize({
    linkToken,
    onSuccess: (publicToken) => {
      fetch("/api/merge/exchange-public-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ public_token: publicToken }),
      })
        .then((r) => r.json())
        .then((data) => {
          if (data.success) {
            connectionStatus[slug] = "connected";
            renderCard(slug);
          }
        });
    },
    onExit: () => resetButton(button),
    onError: () => resetButton(button),
    onReady: () => {
      resetButton(button);
      MergeLink.openLink();
    },
    shouldSendTokenOnSuccessfulLink: true,
  });
}
function resetButton(button) {
  button.disabled = false;
  button.textContent = "Connect";
}
```

### 3. Card States

- **Disconnected**: Connect button
- **Connected**: "Connected" badge + Manage dropdown (Reconnect / Delete). Reconnect uses the same `{ category, integration: slug }` payload. Delete calls your existing delete endpoint and sets `connectionStatus[slug] = 'disconnected'`.

### 4. Token Freshness

Generate a new link token on **every** click — never cache or reuse.

## Key Difference from Connect Button

The `integration` slug in `create-link-token` is the only Merge API change — it pre-selects the provider so users skip Merge's marketplace screen. Without it, that UX falls apart. SDK init, callbacks, and token exchange are identical to the Connect Button pattern.

|                          | Connect Button      | Marketplace                       |
| ------------------------ | ------------------- | --------------------------------- |
| `create-link-token` body | `{ category }`      | `{ category, integration: slug }` |
| Modal                    | Shows all providers | Opens to selected provider        |

## Critical Gotchas

- **Pass `slug` into `initializeMergeLink`** — the closure captures it per click, so two rapid card clicks don't race. A shared outer variable would let the second click overwrite the first before `onSuccess` fires.
- **Reset button states** on `onExit` and `onError` — stuck "Connecting..." is the most common UX bug.

## Testing Checklist

- [ ] Catalog displays with logos and names
- [ ] Category filters show correct integrations
- [ ] Each integration shows correct connected/disconnected state on load
- [ ] Clicking an integration pre-selects it in the modal (not all providers)
- [ ] Successful connection updates only that card's status
- [ ] Manage button shows Reconnect and Delete for connected integrations
- [ ] Disconnect removes integration from connected state
- [ ] Button states reset on modal close or error
