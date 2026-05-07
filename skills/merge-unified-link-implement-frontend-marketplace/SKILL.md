---
name: merge-unified-link-implement-frontend-marketplace
description: Implement the App Center/Marketplace UI pattern for Merge Link — a browsable integration catalog where users select and connect specific integrations. Use as Step 4b of Merge Link implementation when users should discover and connect multiple integrations.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implementing the App Center / Integration Marketplace

> You're implementing the **App Marketplace** pattern — a browsable catalog where users discover and connect integrations. If you'd prefer a simpler single Connect button instead, use `merge-unified-link-implement-frontend-connect`.

Builds an integration marketplace where users browse a catalog of available integrations and click to connect specific ones. Best for products that support many integrations across multiple categories.

## Prerequisites

- `merge-unified-link-implement-backend` complete (all 4 endpoints working)
- **React**: `npm install @mergeapi/react-merge-link`
- **Vanilla JS**: `<script src="https://cdn.merge.dev/initialize.js"></script>` in `<head>`

## Before Proceeding

**Step 1 — Confirm or gather required context:**

- **Categories**: Which Merge categories should the marketplace display? (`hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`)
- **Frontend SDK** *(React only)*: React SDK (`@mergeapi/react-merge-link`) or CDN+vanilla JS?

If invoked from `merge-unified-implementing-link`, both were answered in Step 1d — use that context. Otherwise, ask the user now.

**Step 2 — Frontend pre-scan:**

If invoked from `merge-unified-implementing-link`, the pre-scan was already done in Step 4 — use those findings (existing page location, or the user's answer about mockups). Otherwise, do the scan now:

- Search the frontend for an existing integrations page, marketplace, or app catalog (filenames or routes like `marketplace`, `integrations`, `app-center`, `catalog`).
- If found: identify the exact file and location where the catalog would be inserted. Tell the user.
- If not found: ask — "I didn't find an existing marketplace page. Do you have design mockups? If not, I can generate a marketplace UI that matches your app's existing component style."

**Step 3 — Confirm approach before writing any UI code:**

- If an existing page was found: modify that file rather than creating a new one.
- If mockups were provided: implement according to the mockups, matching the app's component library.
- If no page and no mockups: generate a new page matching the visual style of existing pages. Do not introduce new dependencies without asking.

## Implementation

### 1. Add a Backend Endpoint for the Integration Catalog

**Never call the Merge integrations API directly from the frontend** — the API key must stay server-side.

Add a new backend endpoint that proxies the catalog to your frontend:

```text
GET /api/merge/integrations
→ calls GET https://api.merge.dev/api/organizations/integrations
  with Authorization: Bearer {MERGE_API_KEY}
→ returns the list to your frontend
```

This endpoint returns only the integrations enabled for your Merge organization — not the full public catalog. Each object includes `name`, `slug`, `categories`, `image` (logo URL), `color`.

Then fetch the catalog from your frontend via:

```javascript
fetch('/api/merge/integrations')
  .then(r => r.json())
  .then(({ integrations }) => renderCatalog(integrations));
```

Render a grid of cards showing logo, name, and category. Optional: Add category tabs (HRIS, ATS, CRM, Accounting, Ticketing, FileStorage, Knowledge Base) so users can filter.

### 2. Per-Integration Connect Flow

Each card has its own Connect button that pre-selects that provider in the modal — users skip Merge's provider selection screen entirely.

#### React SDK (`@mergeapi/react-merge-link`)

Each card is its own component owning a `useMergeLink` instance. This isolates hook state per card — two simultaneous card clicks cannot race.

```jsx
import { useState, useEffect } from 'react';
import { useMergeLink } from '@mergeapi/react-merge-link';

function IntegrationCard({ integration, onConnected }) {
  const [linkToken, setLinkToken] = useState(null);

  const { open, isReady } = useMergeLink({
    linkToken,
    shouldSendTokenOnSuccessfulLink: true,
    onSuccess: async (publicToken) => {
      const res = await fetch('/api/merge/exchange-public-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ public_token: publicToken }),
      });
      const { success, integration_name } = await res.json();
      if (success) onConnected(integration.slug, integration_name);
      setLinkToken(null); // reset for next click
    },
    onExit: () => setLinkToken(null),
  });

  useEffect(() => {
    if (isReady && linkToken) open();
  }, [isReady, linkToken, open]);

  const handleConnect = async () => {
    const res = await fetch('/api/merge/create-link-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: integration.category, integration: integration.slug }),
    });
    const { link_token } = await res.json();
    setLinkToken(link_token);
  };

  return <button onClick={handleConnect}>Connect</button>;
}

// Parent manages connection state, passes onConnected down
function IntegrationMarketplace({ integrations }) {
  const [connectionStatus, setConnectionStatus] = useState({});

  const handleConnected = (slug, integrationName) => {
    setConnectionStatus(prev => ({
      ...prev,
      [slug]: { connected: true, integrationName },
    }));
  };

  return integrations.map(integration => (
    <IntegrationCard
      key={integration.slug}
      integration={integration}
      onConnected={handleConnected}
    />
  ));
}
```

#### Vanilla JS (CDN)

```javascript
const connectionStatus = {}; // slug → { connected, integrationName }

function connectIntegration(category, slug, button) {
  button.disabled = true;
  button.textContent = "Connecting...";

  fetch("/api/merge/create-link-token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category, integration: slug }),
  })
    .then((r) => r.json())
    .then((data) => {
      if (data.success) initializeMergeLink(data.link_token, slug, button);
      else { alert("Failed: " + data.error); resetButton(button); }
    });
}

function initializeMergeLink(linkToken, slug, button) {
  MergeLink.initialize({
    linkToken,
    shouldSendTokenOnSuccessfulLink: true,
    onSuccess: (publicToken) => {
      fetch("/api/merge/exchange-public-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ public_token: publicToken }),
      })
        .then((r) => r.json())
        .then((data) => {
          if (data.success) {
            connectionStatus[slug] = {
              connected: true,
              integrationName: data.integration_name || slug,
            };
            renderCard(slug); // re-render card to show connected badge + Manage button
          }
        });
    },
    onExit: () => resetButton(button),
    onError: () => resetButton(button),
    onReady: () => { resetButton(button); MergeLink.openLink(); },
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

**Vanilla JS:** Pass `slug` into `initializeMergeLink` as a closure — a shared outer variable lets two rapid card clicks race and overwrite each other before `onSuccess` fires. Reset button states on `onExit` and `onError` to prevent stuck "Connecting..." state.

**React:** Each card must be its own component with its own `useMergeLink` instance — do not share a single hook across cards. Reset `linkToken` to `null` after `onSuccess` and `onExit`.

## Testing Checklist

- [ ] Catalog fetched via `/api/merge/integrations` (backend proxy) — no direct call to Merge from the frontend
- [ ] No Merge API key exposed to the frontend
- [ ] Catalog shows only enabled integrations (not the full public Merge catalog)
- [ ] Catalog displays with logos and names
- [ ] Category filters show correct integrations
- [ ] Each integration shows correct connected/disconnected state on load
- [ ] Clicking an integration pre-selects it in the modal (not all providers)
- [ ] After connection, the specific card updates to connected state showing the integration name
- [ ] Connected state is derived from the exchange response, not re-fetched
- [ ] Manage button shows Reconnect and Delete for connected integrations
- [ ] Disconnect removes integration from connected state
- [ ] Button states reset on modal close or error
- [ ] (React) Each card is its own component with its own `useMergeLink` instance — no shared hook state across cards
- [ ] (React) `linkToken` reset to `null` after `onSuccess` and `onExit`
