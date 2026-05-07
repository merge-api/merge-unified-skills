---
name: merge-link-implement-frontend-connect
description: Add a single "Connect" button that opens the Merge Link modal. Use as Step 4a of Merge Link implementation after backend endpoints are complete.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Implement Frontend: Connect Button

Adds a single button that opens the Merge Link modal, exchanges the resulting token, and displays connected integrations with relink and delete actions. Step 4a of Merge Link.

## Prerequisites

- `merge-link-implement-backend` complete (all four API endpoints available)
- **React**: `npm install @mergeapi/react-merge-link`
- **Vanilla JS**: `<script src="https://cdn.merge.dev/initialize.js"></script>` in `<head>`

## Before Proceeding

Confirm or gather the following before writing any code:

- **Category**: Which Merge category is this connect button for? (e.g. `hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`)
- **Frontend SDK** *(React only)*: React SDK (`@mergeapi/react-merge-link`) or CDN+vanilla JS?

If invoked from `implementing-merge-link`, both were answered in Step 1d — use that context. Otherwise, ask the user now.

## Implementation

### React SDK (`@mergeapi/react-merge-link`)

Use this path for React applications.

```jsx
import { useState, useEffect } from 'react';
import { useMergeLink } from '@mergeapi/react-merge-link';

function ConnectButton({ category, onConnected }) {
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
      const { success, integration_name, integration_slug } = await res.json();
      if (success) onConnected({ integration_name, integration_slug });
      setLinkToken(null); // reset so next click fetches a fresh token
    },
    onExit: () => setLinkToken(null),
  });

  // Open modal once the hook is ready after token is set
  useEffect(() => {
    if (isReady && linkToken) open();
  }, [isReady, linkToken, open]);

  const handleConnect = async () => {
    const res = await fetch('/api/merge/create-link-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category }),
    });
    const { link_token } = await res.json();
    setLinkToken(link_token);
  };

  return <button onClick={handleConnect}>Connect</button>;
}
```

`onConnected` receives `{ integration_name, integration_slug }` — use it to update parent state and swap the button for a connected/manage indicator. For relink and delete, pass `linked_account_id` down to child handlers that call `/api/merge/relink-integration` and `/api/merge/delete-integration` respectively, then call `open()` / update state on response.

### Vanilla JS (CDN)

Use this path for non-React frontends.

> **CDN URL note:** Verify the script URL below in the Merge dashboard under "Merge Link" setup docs — CDN paths can change between releases.

```html
<script src="https://cdn.merge.dev/initialize.js"></script>
<button id="connectBtn">Connect Integration</button>
```

```javascript
connectBtn.addEventListener("click", () => {
  connectBtn.disabled = true;
  connectBtn.textContent = "Initializing...";
  fetch("/api/merge/create-link-token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category: "{category}" }),
  })
    .then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); })
    .then(({ success, link_token, error }) =>
      success ? openMergeLink(link_token) : (alert(error || "Failed to generate link token"), resetBtn()),
    )
    .catch((err) => { alert("Network error: " + err.message); resetBtn(); });
});

function openMergeLink(linkToken) {
  MergeLink.initialize({
    linkToken,
    shouldSendTokenOnSuccessfulLink: true,
    onReady: () => {
      resetBtn();
      MergeLink.openLink(); // must call explicitly — modal does not open automatically
    },
    onSuccess: (public_token) => {
      fetch("/api/merge/exchange-public-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ public_token }),
      })
        .then((r) => r.json())
        .then(({ success, integration_name, integration_slug }) => {
          if (success) {
            // Update the UI to show connected state — swap the Connect button for a
            // connected/manage indicator using integration_name. Use DOM mutation or
            // whatever state management pattern the app already uses.
          }
        });
    },
    onExit: () => resetBtn(),
    onError: () => { alert("An error occurred. Please try again."); resetBtn(); },
  });
}

function relinkIntegration(id) {
  fetch("/api/merge/relink-integration", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ linked_account_id: id }),
  })
    .then((r) => r.json())
    .then(({ success, link_token }) => { if (success) openMergeLink(link_token); });
}

function deleteIntegration(id) {
  if (!confirm("Remove this integration? This action is permanent.")) return;
  fetch("/api/merge/delete-integration", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ linked_account_id: id }),
  })
    .then((r) => r.json())
    .then(({ success }) => {
      if (success) {
        // Restore the Connect button and remove the connected indicator.
      }
    });
}

function resetBtn() { connectBtn.disabled = false; connectBtn.textContent = "Connect Integration"; }
```

## Critical Gotchas

**New token on every click** — reusing a token causes silent failures.

**No Merge terminology in the UI** — show "Connect HR System", not "Connect via Merge".

**React only:** Do not call `open()` directly in the click handler — set `linkToken` in state and let the `useEffect` call `open()` once `isReady` is true. Reset `linkToken` to `null` after `onSuccess` and `onExit`.

**Vanilla JS only:** Call `MergeLink.openLink()` inside `onReady` — the modal does not open automatically. Reset button on every outcome (onExit, onError, fetch failure).

## Testing Checklist

- [ ] Button generates a fresh link token on every click
- [ ] Modal opens automatically on ready (not requiring a second click)
- [ ] Successful auth exchanges token; UI updates to show connected state with the integration name
- [ ] Connected state is derived from the exchange response, not re-fetched
- [ ] Button re-enables on exit/error; relink works without duplicate DB records
- [ ] Delete prompts confirmation, removes from Merge and local DB, and UI returns to disconnected state
- [ ] (React) `useMergeLink` hook used — no `MergeLink.initialize` in React components
- [ ] (React) `linkToken` reset to `null` after `onSuccess` and `onExit`
