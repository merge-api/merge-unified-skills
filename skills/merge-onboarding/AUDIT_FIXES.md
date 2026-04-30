# merge-onboarding skill audit — fix checklist

Generated 2026-04-29 from end-to-end customer build (CRM/Salesforce, Node.js + Postgres, real Linked Account, 16k contacts, real webhooks via cloudflared). All items below are Merge-skill-specific; machine-/dev-env-specific issues were filtered out.

Check each box as you ship the fix. Each item references the section/step in `SKILL.md` where the change lands.

---

## Original 9 (from initial customer simulation, 2026-04-29 first pass)

### Blockers

- [ ] **#1 — AccountToken response missing `end_user_origin_id`** (Step 5)
  Step 5 doesn't show the AccountToken response schema or how to match it back to the pending DB record. Inline the schema and show passing `end_user_origin_id` from frontend `onSuccess` alongside `publicToken`.

- [ ] **#2 — `result.integration` is a pydantic / SDK model, not a dict** (Step 5)
  Examples imply it's JSON-serializable. Show `result.integration?.name` for the string, and explain `model_dump()` (Python) / spread (Node) for full serialization.

- [ ] **#3 — Vanilla JS `openLink()` called without `onReady`** (Step 4)
  Timing race causes invisible iframe. Always wrap `openLink()` inside the `onReady` callback in vanilla JS examples.

### Moderate

- [ ] **#4 — Test account limit error (400) not in troubleshooting** (Step 8 / Troubleshooting)
  Add entry: "Organization has already reached their maximum number of test accounts."

- [ ] **#5 — No prominent guidance on testing without real credentials** (Step 4)
  Test integration is buried in a sub-section. Promote to primary recommended first run for first-time builders.

### Minor / Structural

- [ ] **#6 — Examples hardcoded to File Storage, not user's category** (entire skill)
  Inject the user's chosen category throughout examples (`hris`, `crm`, etc.) instead of defaulting to `filestorage`.

- [ ] **#7 — Step 5 Python example is a fragment** (Step 5)
  Show a complete `/api/merge/exchange` handler, not a code snippet ending mid-flow.

- [ ] **#8 — Critical response schema lives in references/auth-flow.md** (Step 5)
  Inline the schema at Step 5; customers don't always navigate to references.

- [ ] **#9 — Wrong URL for Common Model scope config** (Step 8 + Troubleshooting)
  Skill says `/configuration/common-model-scopes`. Actual path is `/common-models/<category>` (e.g. `/common-models/crm`). Update both occurrences.

---

## Authentication / API key (Steps 1-2)

- [ ] **#10 — Test vs production key impact under-stated** (Step 1)
  Add explicit warning: production keys create real Linked Accounts, billed and counted against quota. Verify your key prefix (`test_xxx` vs `production_xxx`) before clicking Connect.

- [ ] **#11 — No mapping between key type and dashboard view** (Step 1)
  Document: "Production Linked Accounts" page only shows production-key accounts; "Test Linked Accounts" is a separate view. Customers using the wrong key look in the wrong place.

- [ ] **#12 — Free-tier production Linked Account caps not mentioned** (Step 1)
  Note: free tier caps production Linked Accounts (currently 3). Hitting this mid-build is jarring; flag it upfront.

---

## link_token (Step 3)

- [ ] **#13 — `endUserOriginId` stability semantic missing** (Step 3)
  Document: must be stable across re-link sessions for the same end-user. If it changes, Merge creates a new Linked Account instead of updating the existing one. Critical for relink UX.

- [ ] **#14 — Pending-row-before-Merge-call pattern is in callout, not code** (Step 3)
  Move the pattern into the actual Step 3 example: `INSERT pending row` first, then call Merge. Customers reading top-to-bottom miss the callout.

- [ ] **#15 — Multiple-pending-rows duplication unaddressed** (Step 3 + Step 5)
  If user opens Link, abandons, opens again → two pending rows → exchange handler matches both → two `active` rows for one Linked Account. Show explicit dedup pattern (UNIQUE partial index on `(origin_id) WHERE status='pending'`, or delete prior pending before insert).

- [ ] **#16 — Hardcoded placeholders ("alice@acme.com", "Acme Corp", "user_123")** (Step 3)
  Add inline comments showing where each value comes from in a real app (auth context, customer record, your user ID).

---

## Merge Link / frontend (Step 4)

- [ ] **#17 — `isReady` field on `useMergeLink` not explained** (Step 4)
  Document what it means, when it becomes true, and why to gate the button on it.

- [ ] **#18 — Test integration as primary first-run path is buried** (Step 4)
  Promote the Test integration recommendation. First-time builders should reach for it before wrestling with real provider sandboxes.

- [ ] **#19 — `linkToken: linkToken ?? ""` empty-string fallback is sketchy** (Step 4)
  `useMergeLink` accepts an empty token then errors silently. Show either: don't render until token loads, or pass `null` and skip the hook initialization.

- [ ] **#20 — public_token TTL "~10 min" is approximate** (Step 5 / Troubleshooting)
  Replace with the precise documented value.

---

## Exchange (Step 5)

- [ ] **#21 — Store `result.id` (Merge UUID for Linked Account)** (Step 5)
  This UUID is the join key for webhook payloads (`event.linked_account.id`) → DB row. Without storing it, customers can't process webhooks correctly. Add a `merge_account_id` column in the example schema.

- [ ] **#22 — `result.integration?.name` defensive deref pattern not shown** (Step 5)
  `integration` can be null. Show `?.` consistently across language examples.

---

## First API call (Step 6)

- [ ] **#23 — Pagination handling absent** (Step 6)
  Show the `cursor` loop. Customers with anything past page 1 silently lose data.

- [ ] **#24 — Common Model field array shapes misleading** (Step 6 + references/common-models.md)
  - `email_addresses` is `Array<{emailAddress, emailAddressType}>` — not a string
  - `phone_numbers` same shape
  - `account` is a nested reference object, not a name
  Update inline examples to show the extraction pattern (`c.emailAddresses?.[0]?.emailAddress`).

- [ ] **#25 — `modifiedAt` field for incremental sync not introduced** (Step 6)
  Bridge to the `modified_after` query parameter and the `merge-sync` skill. Critical for production but currently disconnected.

---

## Webhooks (Step 7) — biggest concentration of issues

- [ ] **#26 — "Send test" button is a connectivity ping, not a real event payload** (Step 7) ⚠ HIGH PRIORITY
  Sends `{"response": "Success! This URL will be notified."}`. Customers see `event_type=undefined` in their handler and assume their code is broken. **This was the single biggest surprise of the session.** Add explicit warning: connectivity test only. To exercise real event handling, reconnect via Merge Link with the Test integration.

- [ ] **#27 — No webhook payload schema per event type** (Step 7)
  `Linked Account synced`, `Common Model synced`, `Linked Account changed` have different shapes. Document each so customers can write defensive handlers.

- [ ] **#28 — Verify `/configuration/webhooks` URL is current** (Step 7)
  Given Common Model scope URL was wrong, this one should be re-verified against the current dashboard.

- [ ] **#29 — Async-processing pattern not shown** (Step 7)
  Skill's example is synchronous (insert → respond). Merge retries on >30s response; contact resync on a 16k-account takes longer than that. Show `setImmediate` or queue pattern, framed as "Merge's webhook timeout is X seconds."

- [ ] **#30 — Padding-strip on signature: explain WHY** (Step 7)
  Code does `replace(/=+$/, '')` correctly but doesn't explain that base64url signatures arrive with or without `=` padding depending on client. Strip both sides before comparing.

- [ ] **#31 — express.raw middleware ordering trap not shown** (Step 7)
  If `express.json()` runs before the webhook route, the body is already parsed and signature verification fails. Show middleware ordering explicitly: webhook route mounted BEFORE `express.json()`.

- [ ] **#32 — HMAC-SHA256 base64url (NOT standard base64)** (Step 7)
  Easy to miss. Customers using `base64` instead of `base64url` get a different output and can't debug. Bold this in the algorithm spec.

- [ ] **#33 — Webhook secret rotation strategy not mentioned** (Step 7)
  Document Merge's behavior during rotation — what happens to in-flight webhooks during the changeover.

- [ ] **#34 — 24-hour default sync cadence not stated** (Step 7)
  Add explicit answer: "Production tier syncs once per 24 hours by default; configurable per Linked Account."

---

## Production checklist (Step 8)

- [ ] **#35 — Items too vague to act on** (Step 8)
  "Handle API errors gracefully" → expand to per-status-code guidance:
  - 401: bad API key — ops alert, not customer-facing
  - 403: scope not enabled — log link to `/common-models/<category>`
  - 429: rate limit — exponential backoff
  - 5xx: retry with backoff, then alert

- [ ] **#36 — "Re-connect flow" needs code/UX example** (Step 8)
  What does the button look like? When does it appear? How does the user know to click it? Add minimal UI snippet.

- [ ] **#37 — Add missing checklist items:**
  - [ ] Encrypt `account_token` at rest (KMS / pgcrypto). Security implication unusually high — token authenticates against customer's production CRM.
  - [ ] Background queue for webhook processing (BullMQ / pg-boss). Frame against Merge's webhook retry policy.
  - [ ] Multi-category Linked Account UX (one user with CRM + ATS connected).
  - [ ] Field Mapping API for custom fields beyond Common Model.
  - [ ] Selective Sync for filtering at the source (huge production concern at scale — 16k contacts in this build was small).

---

## Common Model reference

- [ ] **#38 — `Contact` schema in main table doesn't show array shapes** (references/common-models.md)
  Reads like fields are strings; they're nested objects. Update the schema table.

- [ ] **#39 — `remote_data` field only in troubleshooting** (Step 6 + references/common-models.md)
  Customers asking "where's my Salesforce custom field X?" need this surfaced in the main flow.

- [ ] **#40 — Field Mappings API not mentioned at all** (Step 6 / new section)
  Separate concept customers will absolutely need. Even a brief callout with link helps.

---

## Troubleshooting

- [ ] **#41 — "Empty results array" merges three different causes** (Troubleshooting)
  Split into three entries with diagnostic flow:
  - Scope not enabled (action: enable in dashboard)
  - Initial sync still running (action: wait, check sync status endpoint)
  - Initial sync failed (action: check Linked Account logs for source-side errors)

---

## Cross-cutting

- [ ] **#42 — Magic Link variant not surfaced in main flow** (Step 4)
  Many B2B integrations have no customer frontend. Magic Link lives in references/auth-flow.md but should get a callout in main skill: "If you don't have a frontend, see Magic Link variant."

- [ ] **#43 — Pending → active state machine is implicit** (Step 5 / new section)
  Add explicit table:
  - `pending` = link_token issued, exchange not yet completed
  - `active` = exchange completed, account_token stored
  - `relink_needed` = end-user revoked or credentials expired
  - `incomplete` = something wrong on Merge's side

- [ ] **#44 — `isInitialSync: true` flag on sync-status response not explained** (Troubleshooting)
  Customers debugging "why is my sync not done" don't know to check this. Distinguishes "first run, give it 30 min" from "ongoing sync."

- [ ] **#45 — `last_sync_result: FAILED` semantics confusing** (Troubleshooting)
  When `last_sync_finished: null` AND `status: SYNCING`, the FAILED is from a previous attempt; current run might still succeed. Easy to misread as "your sync failed."

---

## Process / structural skill issues

- [ ] **#46 — References require fetching** (skill structure)
  Critical pieces (Contact schema, full pagination example, Magic Link) live in references customers may not navigate to. Inline more aggressively.

- [ ] **#47 — No linkage to other Merge skills** (end of skill)
  When in onboarding, `merge-validate`, `implementing-merge-link`, `implementing-merge-sync`, `implementing-merge-post-connection` aren't surfaced. End the skill with explicit next-skill suggestions.

---

## Theme

The skill optimizes for "show how the API works" but not "build a production integration." Code examples are SDK-call fragments, not complete handlers. State machines are implicit. Production patterns (dedup, encryption, async webhook processing, pagination, incremental sync) are checklist items rather than working code.

When fixing, prefer:
- Inlining schemas at the step where they're used (not in references)
- Complete handler patterns (not fragments)
- Explicit SDK object types (pydantic models, nested objects, array shapes)
- Visible state machine
- Bridging to other Merge skills at the end
