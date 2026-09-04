---
name: integration-validator
description: |
  Validate a Merge Unified API integration end-to-end. Use when a developer says
  "validate my Merge integration", "test my Merge setup", "is my Merge connection working",
  "debug my Merge API call", "verify my Linked Account", "check my Merge scopes",
  "my Merge API returns empty", "Merge sync not working", "check my account_token",
  or after completing /merge-unified:onboarding. Runs diagnostic checks against
  the Merge API and outputs a pass/fail checklist with actionable fixes.
license: MIT
metadata:
  author: Merge
  version: 0.2.1
---

# Merge Integration Validator

Run diagnostic checks against a developer's Merge integration and output a pass/fail report. This skill chains naturally after `onboarding` — once a developer has set up their Linked Account, this skill confirms everything actually works.

## When to use this skill

Activate when:
- Developer just finished the onboarding flow and wants to confirm it works
- Developer says "validate", "test", "check", "verify", or "debug" in relation to their Merge setup
- Developer reports empty API responses, auth errors, or sync issues
- After `/merge-unified:onboarding` completes, proactively suggest this skill

Do NOT activate for:
- Initial setup (route to `onboarding`)
- Questions about Merge pricing, plans, or non-technical topics

## First activation: self-introduce

When this skill activates for the first time in a conversation, say:

> I'm the Merge Integration Validator (v0.2.0). I'll run a series of checks against your Merge API to confirm your integration is healthy. I'll need your API key, account_token, and the category you're integrating.

## Step 0: Gather inputs

Ask the developer for (skip anything already known from context):

1. **API key** — `test_xxx` or `production_xxx`
2. **Account token** — the `account_token` for the Linked Account to validate
3. **Category** — which Merge category: `hris`, `ats`, `crm`, `accounting`, `ticketing`, `filestorage`, `knowledgebase`, or `mktg`
4. **SDK language** — to generate diagnostic code in their language

Warn: "I'll generate code that makes real API calls. If you're using a production key, these are read-only (GET) calls — no data will be modified."

## Step 1: Generate and run the diagnostic script

Generate a diagnostic script in the developer's language that runs all checks from `references/diagnostic-endpoints.md`. The script should:

1. **Print each check name** as it runs
2. **Print PASS / FAIL** with a short explanation
3. **On failure, print the exact fix** (not just "check your config")
4. **Exit with code 0 if all pass, 1 if any fail**

### Python example structure

```python
import os
import requests

API_KEY = os.environ.get("MERGE_API_KEY", "YOUR_API_KEY")
ACCOUNT_TOKEN = os.environ.get("MERGE_ACCOUNT_TOKEN", "YOUR_ACCOUNT_TOKEN")
CATEGORY = "hris"  # replace with actual category
BASE = "https://api.merge.dev/api"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "X-Account-Token": ACCOUNT_TOKEN,
}

results = []

# Check 1: API key + account_token valid (combined auth check)
def check_auth():
    r = requests.get(f"{BASE}/{CATEGORY}/v1/account-details", headers=headers)
    if r.status_code == 200:
        data = r.json()
        return "PASS", f"Auth valid — integration: {data.get('integration_name', 'unknown')}, status: {data.get('status', 'unknown')}"
    elif r.status_code == 401:
        # Try without account_token to isolate which credential is wrong
        r2 = requests.get(f"{BASE}/{CATEGORY}/v1/account-details", headers={"Authorization": f"Bearer {API_KEY}"})
        if r2.status_code == 401:
            return "FAIL", "API key rejected (401). Verify at https://app.merge.dev/keys. Check env: test_ vs production_"
        else:
            return "FAIL", "API key is valid but account_token is rejected. Exchange a fresh public_token or check the stored token."
    else:
        return "FAIL", f"Unexpected status {r.status_code}: {r.text[:200]}"

# Check 3: Sync status
def check_sync_status():
    r = requests.get(f"{BASE}/{CATEGORY}/v1/sync-status", headers=headers)
    if r.status_code == 200:
        data = r.json()
        models = data.get("results", [])
        # PARTIALLY_SYNCED and PAUSED are terminal, not in-progress — only SYNCING is live.
        synced = [m for m in models if m.get("status") == "DONE"]
        syncing = [m for m in models if m.get("status") == "SYNCING"]
        partial = [m for m in models if m.get("status") == "PARTIALLY_SYNCED"]
        failed = [m for m in models if m.get("status") == "FAILED"]
        paused = [m for m in models if m.get("status") == "PAUSED"]
        disabled = [m for m in models if m.get("status") == "DISABLED"]

        def names(ms):
            return ", ".join(m.get("model_name", "?") for m in ms)

        if failed:
            return "FAIL", f"Sync failed for: {names(failed)}. Check Linked Account page in dashboard."
        elif paused:
            return "FAIL", (f"Paused: {names(paused)}. No inbound API request or webhook for 2+ weeks, "
                            "or failed syncs for 2+ weeks. Resume traffic to this Linked Account.")
        elif partial:
            return "WARN", (f"Partially synced: {names(partial)}. This is terminal, not in progress — "
                            "some fields failed while others succeeded. Data is queryable but incomplete.")
        elif syncing:
            stalled = [m for m in syncing if m.get("sync_status_reason")]
            if stalled:
                reasons = ", ".join(f"{m.get('model_name','?')}={m['sync_status_reason']}" for m in stalled)
                return "WARN", f"Syncing, held up on: {reasons}. Wait and re-run."
            return "WARN", f"Still syncing: {names(syncing)}. Wait and re-run."
        elif not synced:
            return "WARN", (f"No model is synced. Disabled scopes: {names(disabled) or 'none'}. "
                            "Enable at /configuration/common-model-scopes.")
        else:
            msg = f"{len(synced)} models synced successfully"
            if disabled:
                msg += f" ({len(disabled)} disabled by scope: {names(disabled)})"
            return "PASS", msg
    else:
        return "FAIL", f"Could not fetch sync status: {r.status_code}"

# Check 4: Data exists (primary model)
def check_data_exists():
    primary_models = {
        "hris": "employees", "ats": "candidates", "crm": "contacts",
        "accounting": "invoices", "ticketing": "tickets",
        "filestorage": "files", "knowledgebase": "articles", "mktg": "campaigns",
    }
    model = primary_models.get(CATEGORY, "")
    r = requests.get(f"{BASE}/{CATEGORY}/v1/{model}?page_size=1", headers=headers)
    if r.status_code == 200:
        data = r.json()
        count = len(data.get("results", []))
        if count > 0:
            return "PASS", f"Data found — {model} endpoint returned results"
        else:
            return "WARN", "Empty results. Check: (1) scopes enabled at /configuration/common-model-scopes, (2) initial sync completed, (3) source provider has data for this model"
    else:
        return "FAIL", f"{model} endpoint returned {r.status_code}: {r.text[:200]}"

# Check 5: Pagination works
def check_pagination():
    primary_models = {
        "hris": "employees", "ats": "candidates", "crm": "contacts",
        "accounting": "invoices", "ticketing": "tickets",
        "filestorage": "files", "knowledgebase": "articles", "mktg": "campaigns",
    }
    model = primary_models.get(CATEGORY, "")
    r = requests.get(f"{BASE}/{CATEGORY}/v1/{model}?page_size=1", headers=headers)
    if r.status_code != 200:
        return "SKIP", "Skipped (primary model check failed)"
    data = r.json()
    cursor = data.get("next")
    if cursor is None:
        return "PASS", "Only one page of data (or empty) — pagination not needed yet"
    r2 = requests.get(f"{BASE}/{CATEGORY}/v1/{model}?page_size=1&cursor={cursor}", headers=headers)
    if r2.status_code == 200:
        return "PASS", "Pagination works — fetched page 2 successfully"
    else:
        return "FAIL", f"Page 2 failed: {r2.status_code}"

# Run all checks
checks = [
    ("Auth (API key + account_token)", check_auth),
    ("Sync Status", check_sync_status),
    ("Data Exists", check_data_exists),
    ("Pagination", check_pagination),
]

print("=" * 50)
print("Merge Integration Validator")
print("=" * 50)

all_pass = True
for name, fn in checks:
    status, msg = fn()
    icon = {"PASS": "✅", "FAIL": "❌", "WARN": "⚠️", "SKIP": "⏭️"}.get(status, "?")
    print(f"\n{icon} {status}: {name}")
    print(f"   {msg}")
    if status == "FAIL":
        all_pass = False

print("\n" + "=" * 50)
if all_pass:
    print("All checks passed. Your Merge integration is healthy.")
else:
    print("Some checks failed. Fix the issues above and re-run.")
exit(0 if all_pass else 1)
```

## Step 2: Interpret results

After the script runs, explain each result:

- **PASS** — no action needed, confirm what it means
- **FAIL** — explain the fix step-by-step, with links to the relevant dashboard page
- **WARN** — explain what to watch for and when to re-check
- **SKIP** — explain why it was skipped (usually a dependency failed)

## Step 3: Optional deep checks

If all basic checks pass, offer these additional validations:

1. **Webhook verification** — if they have a webhook URL configured, generate a test payload and verify their signature check works
2. **Field mapping check** — list which Common Model fields have data vs null for a sample record
3. **Rate limit headroom** — hit the API a few times rapidly to confirm they're not near the 429 threshold

## Troubleshooting

**SYMPTOM:** All checks fail with 401.
**CAUSE:** API key environment mismatch (test key against production data or vice versa).
**FIX:** Verify key at https://app.merge.dev/keys. Test keys start with `test_`, production with `production_`.

---

**SYMPTOM:** API key passes but account_token fails.
**CAUSE:** Token was for a different key environment, or the Linked Account was deleted.
**FIX:** Check the Linked Account in the dashboard. If it's gone, re-trigger the onboarding flow.

---

**SYMPTOM:** Sync status shows DONE but data is empty.
**CAUSE:** Common Model scopes not enabled for this model.
**FIX:** Go to https://app.merge.dev/configuration/common-model-scopes and enable the relevant model.

---

**SYMPTOM:** Pagination cursor returns 400.
**CAUSE:** Cursor expired or malformed.
**FIX:** Cursors are ephemeral. Always fetch a fresh first page, then paginate from there.

## Reference docs

- Diagnostic endpoint details and expected responses: `references/diagnostic-endpoints.md`
