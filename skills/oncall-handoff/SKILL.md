---
name: oncall-handoff
description: >
  Generate an on-call handoff document by pulling PagerDuty incidents and writing them to a Notion page or local markdown file.
  Use this skill whenever the user mentions on-call handoff, midweek handoff, on-call check-in, Thursday on-call doc,
  Monday handoff, on-call handoff doc, midweek incident review, or wants to generate/prepare for their on-call meeting.
  Also trigger when the user asks to pull PagerDuty incidents into Notion for an on-call review,
  or says something like "prep for on-call sync", "generate handoff notes", "get my oncall incidents into Notion",
  "prep for Monday handoff", or "update the handoff doc".
license: MIT
metadata:
  author: Merge
  version: 0.3.0
---

# On-Call Handoff Doc Generator

This skill generates an on-call handoff document by pulling incidents from PagerDuty, summarizing them, and writing the result to Notion or a local markdown file. The output mirrors the team's standard "@Today" handoff template.

## Output modes

- **Notion mode** (default): Creates or updates a page in the "On-call Handoff Meetings" Notion database.
- **Local file mode**: Writes a markdown file to disk when Notion MCP is unavailable or when the user explicitly requests it.

## Timing modes

- **Midweek (Thursday or any non-Monday)**: Creates a **new** Notion page for the midweek check-in. Window is auto-calculated as most recent Monday 2 PM ET → now.
- **Monday (handoff day)**: Searches for an **existing** handoff page for the current week and **updates** it. If none exists, creates a new one. On Monday, ask the engineer what window to cover.

## When to use this skill

Activate when the user mentions:
- "on-call handoff", "midweek handoff", "on-call check-in"
- "Thursday on-call doc", "Monday handoff", "on-call handoff doc"
- "midweek incident review", "prep for on-call sync"
- "generate handoff notes", "get my oncall incidents into Notion"
- "prep for Monday handoff", "update the handoff doc"

Do NOT activate for: general PagerDuty queries unrelated to handoff docs, general Notion queries, or active incident response.

## First activation: self-introduce

> I'm the On-Call Handoff Doc Generator (v0.3.0). I'll pull PagerDuty incidents and create a handoff doc.
> What day is it — are we doing a midweek check-in or a Monday handoff? And do you want output to Notion or a local markdown file?
> Has a handoff doc already been generated for this week? If yes, I'll merge new incident data into it without overwriting your filled-in columns.

## Service allowlist

Only incidents from these four services are included in the doc and summary stats. Everything else is dropped silently.

| Service | Bucket | Owning escalation policy |
|---------|--------|--------------------------|
| `Platform-Owned Merge Backend` | Platform-Owned | Platform On-Call Escalation Policy |
| `Growth-Owned Merge Backend` | Growth-Owned | Growth On-Call Escalation Policy |
| `Merge Backend` | Shared (Platform + Growth) | Merge On-Call Escalation Policy |
| `Merge Backend - OAI` | Shared (Platform + Growth) | OpenAI On-Call Escalation Policy |

Anything else (`Amazon GuardDuty`, `Agent Handler Backend`, `Gateway`, support services, etc.) is dropped silently.

## Step-by-step instructions

### Step 1: Determine the time window

**If today is Monday (handoff day):** Ask the engineer what window to cover (e.g., "last Monday 2 PM through now").

**If today is any other day:** Auto-calculate. Start = most recent Monday at 2:00 PM ET. End = now. (If today is Monday before 2 PM, use the previous Monday.)

Convert to ISO 8601 / UTC for PagerDuty API calls. Keep ET versions for display.

### Step 2: Determine output mode and locate target

If the user explicitly requested local file output ("save to a file", "output as markdown", "write locally"), use **local file mode** and skip to Step 3.

Otherwise, attempt **Notion mode**: search for the "On-call Handoff Meetings" database with `Notion:notion-search` (`content_search_mode: "workspace_search"`). Capture the database ID.

- **Notion MCP unavailable**: Inform the user, switch to local file mode.
- **Database not found**: Ask if the user wants to provide a different name or fall back to local file.
- **Database found and today is Monday**: Search inside it for an existing handoff page for this week. If found, plan to update; otherwise plan to create.
- **Database found and today is not Monday**: Always create a new page.

### Step 2.5: Check for an existing handoff doc to merge

This step exists to **prevent overwriting work the team has already filled in** — Description / Actions taken / Future action items columns inside the P0 tables, plus Meeting Notes, Action Items, P1 Non-Paging, and P2 Sentry entries.

Always ask the user, even if Step 2 didn't find anything:

> Has a handoff doc already been generated for this on-call week (e.g., from a midweek check-in)? If yes, I'll read it and merge any filled-in content into the new doc. If no, I'll generate a fresh doc.

**If the user says no** (or there is no prior doc): set `prior_doc = None` and continue to Step 3 with no merge.

**If the user says yes**:

1. Ask: "What's the path to the existing file?" (local file mode) or "What's the URL of the existing Notion page?" (Notion mode). Accept relative paths, absolute paths, or `~/`-style paths.
2. Read the prior doc:
   - **Local file mode**: use the Read tool on the path provided.
   - **Notion mode**: fetch the page via `Notion:notion-fetch-page` (or equivalent).
3. Parse and store the merge-relevant content as `prior_doc`:
   - **P0 PagerDuty pages tables** (one per bucket — Platform-Owned, Growth-Owned, Shared). For each row, capture the tuple `(Incident, Description, Actions taken, Future action items and/or POMO link)`. The Incident column is the merge key. The `# of pages` and `# of nighttime pages` columns are NOT preserved — they get refreshed from the new PagerDuty pull.
   - **# Meeting Notes section** (the entire `### Notes` and `### Action Items` content, including bullets the team added below "- …").
   - **## [P1] Non-Paging Incidents table** (all non-placeholder rows; the placeholder row is `n-a`).
   - **## [P2] Sentry alerts table** (all non-empty rows).
4. Pass `prior_doc` to Step 6, where the merge actually happens.

If parsing fails (file missing, malformed, can't extract tables): tell the user clearly and ask whether to (a) generate fresh anyway (and lose prior work), (b) provide a different path, or (c) abort. Do NOT silently fall back to fresh generation.

### Step 3: Pull PagerDuty incidents

Make two `PagerDuty:list_incidents` calls — one for paging (high), one for non-paging (low). The list API does not return `urgency`, so filtering at query time is the only way to classify.

**Paging:**
```
since: <window start in UTC, ISO 8601>
until: <window end in UTC, ISO 8601>
status: ["triggered", "acknowledged", "resolved"]
urgencies: ["high"]
sort_by: ["created_at:desc"]
limit: 100
```

**Non-paging:** identical except `urgencies: ["low"]`.

If either query returns 100 results (the limit), warn the user that results may be incomplete.

For each incident, capture:
- `title` (strip leading/trailing whitespace and the `[FIRING]` prefix)
- `status`
- `service.summary`
- `created_at` (UTC)
- `resolved_at` (UTC, may be null)

### Step 4: Filter, classify, and deduplicate

**Filter** by the service allowlist. Drop everything else.

**Classify** survivors by service:
- `Platform-Owned Merge Backend` → Platform-Owned bucket
- `Growth-Owned Merge Backend` → Growth-Owned bucket
- `Merge Backend`, `Merge Backend - OAI` → Shared (Platform + Growth) bucket

Six total buckets: `{paging, non-paging} × {Platform, Growth, Shared}`.

**Deduplicate** within each bucket: group by `(cleaned_title, service.summary)`. For each group, compute:
- **# of pages**: number of incidents in the group.
- **# of nighttime pages**: number of incidents in the group whose `created_at` (after converting to America/New_York) falls in the nighttime window (hour ≥ 22 OR hour < 8).

Sort rows by `# of pages` desc, then most recent `created_at` desc.

For the **Shared (Platform + Growth)** bucket only, append the service name in parentheses to the incident title — e.g., `Sent from: #directmessage (Merge Backend)`. The Platform and Growth buckets are single-service, so don't append there.

### Step 5: Compute totals

Use raw incident counts (post-allowlist), not deduplicated rows.

- **Total pages**: count of paging incidents after filter.
- **Total nighttime pages**: paging incidents whose `created_at` (in ET) is in nighttime window.

Nighttime check:
1. Parse `created_at` as UTC.
2. Convert to America/New_York (handles DST).
3. Nighttime if hour ≥ 22 OR hour < 8.

### Step 6: Write the handoff document

**Title**: `On-Call Handoff — [Month Day, Year]`

**Filename (local file mode)**: `oncall-handoff-YYYY-MM-DD.md` in the current working directory (or path the user specifies).

The document must follow the team template structure exactly — see the **Document template** section below.

#### Merge logic (when `prior_doc` is set from Step 2.5)

Apply this merge before writing the new doc. The goal: refresh the auto-generated data (counts, summary stats, list of incidents) while preserving every cell the team filled in.

**For each P0 PagerDuty pages table row in the new doc:**
- Look up the row in `prior_doc` by the **Incident** column (exact-string match).
- If found in prior_doc: copy `Description`, `Actions taken`, and `Future action items and/or POMO link` from the prior row into the new row. `# of pages` and `# of nighttime pages` come from the fresh PagerDuty pull.
- If not found in prior_doc: the row is a new alert. Leave Description / Actions / Future blank.

**For each row in `prior_doc` that has no matching row in the new tables** (alert that fired earlier in the week but is now out of the dedup window for some reason — should be rare since the window only expands):
- Append the row to the appropriate bucket table with a `(no longer in window)` suffix on the Incident name. Keep the team's Description / Actions / Future filled in.
- Set `# of pages = 0` and `# of nighttime pages = 0` for these stale rows.

**For sections outside the P0 tables**, copy `prior_doc` content verbatim:
- `# Meeting Notes` (Notes bullets and Action Items bullets)
- `## [P1] Non-Paging Incidents` table — replace the new doc's placeholder `n-a` row with the prior doc's rows.
- `## [P2] Sentry alerts` table — replace the new doc's empty rows with the prior doc's rows.
- Static boilerplate (Agenda, links, Handoff checklist) is identical in every run, so no merge needed.

**Before writing**, summarize the merge for the user (one line each):
- "Preserved N filled-in rows in the P0 tables."
- "Added M new alert rows (since prior run)."
- "Carried over Meeting Notes / Action Items / P1 / P2 content from prior doc."
- (If any) "Marked K rows as `(no longer in window)`."

#### Local file mode write

If `prior_doc` came from a local file, **back up the prior file first**: copy it to `oncall-handoff-YYYY-MM-DD.backup-<HHMMSS>.md` in the same directory. Tell the user the backup path.

Then write the merged doc to `oncall-handoff-YYYY-MM-DD.md` (current week's date).

#### Notion mode mechanics

- **Updating an existing page**: use `Notion:notion-update-page` with the merged content. The merge step above already preserved everything the team filled in — no separate "preserve below the auto-generated sections" logic needed.
- **Creating a new page**: use `Notion:notion-create-pages` with the database ID as parent.

### Step 7: Confirm and share

- **Local file mode (fresh)**: "Generated handoff doc at `./oncall-handoff-YYYY-MM-DD.md` with X total pages (Y nighttime). Z still open. Copy into Notion or share directly."
- **Local file mode (merged)**: "Merged into `./oncall-handoff-YYYY-MM-DD.md`: preserved N filled-in rows, added M new alert rows. Backup saved to `./oncall-handoff-YYYY-MM-DD.backup-<HHMMSS>.md`. X total pages (Y nighttime). Z still open."
- **Notion mode (new)**: "Created the handoff doc. X total pages (Y nighttime). Z still open. [URL]"
- **Notion mode (merged)**: "Updated the existing handoff doc: preserved N filled-in rows, added M new alert rows. X total pages (Y nighttime). Z still open. [URL]"

## Document template

The output document must mirror this structure exactly. Lines marked `[FILL]` are filled by the skill; the rest is static boilerplate the team relies on.

````markdown
# On-Call Handoff — [Month Day, Year]    [FILL: today's date]

Created time: [Month Day, Year] [HH:MM AM/PM] ET    [FILL: now]

On-call window: [start] ET → [end] ET    [FILL: window]

# Agenda

Review [PagerDuty alerts](https://merge-api.pagerduty.com/incidents?status=acknowledged%2Ctriggered%2Cresolved) + incidents. Complete the below table **before** the meeting.

- Everyone on the on call team will go to their handoff meeting.
- TPM & previous on call will run the meeting each week.
- All others are encouraged to ask questions on things like available runbooks, alerting thresholds and root causes.

## [P0] PagerDuty pages

Goal: Review all paging alerts & actions taken. Determine if there are unactionable pages occurring over many weeks

Total pages: **[FILL: N]**

Total nighttime pages: **[FILL: N]**

### Platform-Owned

| Incident | # of pages | # of nighttime pages | Description | Actions taken | Future action items and/or POMO link |
|----------|------------|----------------------|-------------|---------------|---------------------------------------|
| [FILL rows: Description, Actions taken, Future action items columns LEFT BLANK for the team] |

### Growth-Owned

| Incident | # of pages | # of nighttime pages | Description | Actions taken | Future action items and/or POMO link |
|----------|------------|----------------------|-------------|---------------|---------------------------------------|
| [FILL rows] |

### Shared (Platform + Growth)

| Incident | # of pages | # of nighttime pages | Description | Actions taken | Future action items and/or POMO link |
|----------|------------|----------------------|-------------|---------------|---------------------------------------|
| [FILL rows — append service name in parens to Incident title] |

## [P0] On-call handoff items

Goal: Review the board and assign the top 1-2 most critical task to resolve

[https://app.asana.com/1/1174208460831550/project/1209311263527342/list/1209860521702625](https://app.asana.com/1/1174208460831550/project/1209311263527342/list/1209860521702625)

## [P1] Non-Paging Incidents

Goal: Discuss incidents that were not captured by the above pages. Determine if there are observability gaps

| Incident (include link if applicable) | Description | Actions taken so far | **Future action items and/or POMO link** | Additional observability needed to catch this sooner? |
| --- | --- | --- | --- | --- |
| n-a |  |  |  |  |

## [P2] Sentry alerts

[Sentry alerts from the past 7 days](https://merge.sentry.io/issues/?environment=production&project=5499632&query=is%3Aunresolved%20issue.type%3Aerror&referrer=issue-list&sort=freq&statsPeriod=7d)

Goal: Review the top 3 highest event count issues and take action toward resolving them.

| Alert name | Link | Resolution | Asana ticket |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

# Meeting Notes

### Notes

- …

### Action Items

For any AIs that we need to track beyond this meeting, cut tickets to the **[On-call action items Asana](https://app.asana.com/0/1209311263527342/1209860521702625)** board.

[https://app.asana.com/1/1174208460831550/project/1209311263527342/list/1209312245858978](https://app.asana.com/1/1174208460831550/project/1209311263527342/list/1209312245858978)

- …

### Handoff checklist

<details>
<summary><strong>Click to expand</strong></summary>

#### **Review on-call documentation**

- [ ]  [**Communication**](https://www.notion.so/Communication-c3d6faad0aa74666af18455d623d4955?pvs=21)

    The on-call engineer owns the communication of the incident. They should:

    - Start a thread in #on-call-discussion channel if there is not one already
    - Communicate to the broader team in #general that a P0 incident is occurring
    - Direct all other communication that occurs internally to the on-call channel
    - Send updates in the on-call channel at least every 30 minutes on the status of the issue. For very serious incidents (ex: site outage) send an update every 15 minutes.
- [ ]  [On-Call Responsibilities](https://www.notion.so/On-Call-Responsibilities-8a9776c2b8914578a3d1279bcf6a12cf?pvs=21)
- [ ]  [Monitoring + Alerting](https://www.notion.so/Monitoring-Alerting-f35ca14c32eb43c799867b5541e0524a?pvs=21)
- [ ]  [P0 Incidents](https://www.notion.so/P0-Incidents-667618f349d04deab29be165e785c2aa?pvs=21)
- [ ]  If there is an engineer that is doing on-call training, make sure to read [On-call Training](https://www.notion.so/On-call-Training-68994fc9825c4e098c5adb2bff02cd36?pvs=21) for guidance

#### **Make sure you have relevant access provisioned**

- [ ]  Sign in and out of Okta (otherwise EKS access will not be granted)
- [ ]  Review instructions for how to request EKS / Looker / Kibana access as on-call: [How to Request Access to AWS EKS & Looker via Okta Workflows for On-Call](https://www.notion.so/How-to-Request-Access-to-AWS-EKS-Looker-via-Okta-Workflows-for-On-Call-15b1da993e97801f8d57cabcfc8f3754?pvs=21)
- [ ]  Looker
- [ ]  Grafana
- [ ]  Sentry
- [ ]  Pagerduty
- [ ]  Cloudflare
- [ ]  SorryApp (through Engineering Vault in 1Pass)

#### **Take ownership in Slack**

- [ ]  Update the @oncall-eng user group by removing the outgoing on-call and adding yourself. Add the shadow as well
    1. From the Home page Slack, select Directories > User Groups
    2. Find  `On-call Engineer`
    3. Right side panel will pop-out showing the User Group. Select `Edit Members`, remove previous and add yourself
    4. You can also click the @oncall-eng tag within Slack and the panel will appear.
- [ ]  Turn on your notifications for [#on-call-discussions](https://mergeapi.slack.com/archives/C0345BCCZGQ) and [#on-call-alerts](https://mergeapi.slack.com/archives/C01JY0JEHJL), including in the mobile app!
- [ ]  Communicate action in response to any alerts that appear in the channel, whether by typing or reacting

</details>
````

### Empty subsections

If a Platform / Growth / Shared subsection has zero rows, still output the heading and table headers, then add a one-line note like "No paging incidents from Platform-Owned services during this window." Do not silently drop subsections.

### Description / Actions taken / Future action items columns

Always leave these three columns blank in the generated tables. The team fills them in during the meeting.

## Troubleshooting

Format: **SYMPTOM** / **CAUSE** / **FIX**.

---

**SYMPTOM:** `Notion:notion-search` returns no results for "On-call Handoff Meetings".
**CAUSE:** The database doesn't exist yet, or it has a different name, or the Notion integration doesn't have access to it.
**FIX:** Confirm the exact database name. If it doesn't exist, ask the user to create it (or fall back to local file mode). If it exists but isn't found, check that the Notion integration has been shared with that database.

---

**SYMPTOM:** `PagerDuty:list_incidents` returns 100 results (the limit).
**CAUSE:** There are more incidents than the limit allows.
**FIX:** Warn the user. Suggest narrowing the time window or running the skill multiple times for different date ranges.

---

**SYMPTOM:** A whole bucket is empty even though there were incidents.
**CAUSE:** The service name doesn't match the allowlist exactly.
**FIX:** Check `service.summary` in the raw response. The allowlist is exact-string match. If the team renamed a service, update Step 4 / the allowlist table.

---

**SYMPTOM:** The skill creates a new page on Monday instead of updating the existing one.
**CAUSE:** The existing page title didn't match the search, or it isn't indexed yet.
**FIX:** Try the search again. Alternatively, ask the user for the existing page URL and use `Notion:notion-update-page` directly.

---

**SYMPTOM:** Timestamps in the doc are off by 4–5 hours.
**CAUSE:** Wrong timezone conversion.
**FIX:** Always convert UTC → `America/New_York` (handles DST). Don't apply a fixed UTC offset.

---

**SYMPTOM:** The same alert appears in multiple rows.
**CAUSE:** Title cleanup didn't normalize properly — e.g., one occurrence has `[FIRING]`, another doesn't, or whitespace differs.
**FIX:** Strip `[FIRING]` and leading/trailing whitespace *before* grouping. Dedup key is `(cleaned_title, service.summary)`.

---

**SYMPTOM:** Merge dropped a row that had filled-in Description / Actions / Future columns.
**CAUSE:** The new dedup key (cleaned title) didn't match the prior doc's Incident column — usually because the alert title changed slightly (e.g., a new env in the title) or a service was renamed.
**FIX:** Look for the row in the new doc's "(no longer in window)" stale section. If it's not there either, the row may have been overwritten — check the backup file (`oncall-handoff-YYYY-MM-DD.backup-<HHMMSS>.md`) and manually copy it back. To prevent recurrence, the title-cleanup logic may need updating.

---

**SYMPTOM:** `<details>` toggle for Handoff checklist doesn't collapse in Notion after import.
**CAUSE:** Notion's markdown importer doesn't always preserve `<details>` as a native toggle.
**FIX:** After import, manually highlight the "Handoff checklist" heading and convert it to a Notion toggle heading. Or skip the `<details>` wrapper in Notion mode and rely on Notion's heading toggle UI applied post-creation.

## Edge cases

- **Notion MCP unavailable**: Auto-fall-back to local file mode.
- **Merging from prior doc**: Always ask in Step 2.5 whether a prior doc exists for this week. If yes, get the path/URL, parse it, and merge in Step 6. Always back up the prior local file before overwriting. Never silently overwrite filled-in content.
- **Prior doc parse failure**: Don't silently fall back to fresh generation. Surface the error and ask the user how to proceed.
- **No incidents at all**: Still emit the full template with zeros and "No incidents..." notes in each subsection. Note it was a quiet week.
- **Pagination**: If 100 results returned, warn and suggest narrowing the window.
- **Monday but no existing page found**: Just create a new one.
- **Monday update with manual content**: Preserve any team-added content below the auto-generated sections — fetch first, identify the boundary, append it back after fresh data.
- **Run on a non-Monday/non-Thursday**: Use midweek logic (auto window, new page).
- **Timezone**: PagerDuty returns UTC. Convert to `America/New_York` for display and nighttime check (handles DST).
- **Title cleanup**: Strip `[FIRING]` and leading/trailing whitespace BEFORE deduplication.
- **New services**: The allowlist is hardcoded. If the team adds a new on-call service (e.g., a new escalation policy), update the allowlist table and Step 4. When in doubt, ask the user before assuming.
- **Same alert across multiple services**: Dedup is keyed on `(cleaned title, service)`. The same title from two services produces two rows in two buckets. Correct behavior.
- **Shared bucket service disambiguation**: Always append `(service name)` to the Incident column for Shared rows since the bucket contains multiple services. Don't do this for Platform-Owned or Growth-Owned.
