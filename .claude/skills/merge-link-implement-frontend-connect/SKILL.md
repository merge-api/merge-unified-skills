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

## Implementation

### 1. Add the SDK and button

> **CDN URL note:** Verify the script URL below in the Merge dashboard under "Merge Link" setup docs — CDN paths can change between releases.

```html
<script src="https://cdn.merge.dev/initialize.js"></script>
<button id="connectBtn">Connect HRIS Integration</button>
```

### 2. On click, generate a fresh link token and open the modal

```javascript
connectBtn.addEventListener("click", () => {
  connectBtn.disabled = true;
  connectBtn.textContent = "Initializing...";
  fetch("/api/merge/create-link-token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category: "hris" }), // Replace "hris" with your category: crm, ats, accounting, ticketing, filestorage, knowledgebase, mktg
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
      MergeLink.openLink();
    }, // must call openLink() explicitly
    onSuccess: (public_token) => {
      fetch("/api/merge/exchange-public-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ public_token }),
      })
        .then((r) => r.json())
        .then(({ success }) => {
          if (success) window.location.reload();
        });
    },
    onExit: () => resetBtn(),
    onError: () => {
      alert("An error occurred. Please try again.");
      resetBtn();
    },
  });
}
```

### 3. Relink and delete for connected integrations

```javascript
function relinkIntegration(id) {
  fetch("/api/merge/relink-integration", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ linked_account_id: id }),
  })
    .then((r) => r.json())
    .then(({ success, link_token }) => {
      if (success) openMergeLink(link_token);
    });
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
      if (success) window.location.reload();
    });
}
```

## Critical Gotchas

**Call `MergeLink.openLink()` inside `onReady`.** The modal does not open automatically — you must open it explicitly.

**New token on every click.** Reusing a token causes silent failures. **No Merge terminology in the UI.** Show "Connect HR System", not "Connect via Merge" or token/API references.

**Reset button on every outcome** (onExit, onError, fetch failure) to prevent stuck disabled state.

## Testing Checklist

- [ ] Button generates a fresh link token on every click
- [ ] Modal opens automatically on ready (not requiring a second click)
- [ ] Successful auth exchanges token; page refreshes with new integration shown
- [ ] Button re-enables on exit/error; relink works without duplicate DB records
- [ ] Delete prompts confirmation and removes from Merge and local DB
