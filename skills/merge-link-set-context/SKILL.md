---
name: merge-link-set-context
description: Load Merge platform, backend, and frontend documentation into context. Use as Step 1 of Merge Link implementation before writing any code. Typically invoked automatically by the `implementing-merge-link` skill — you usually don't need to invoke this directly.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Loading Merge Link Context

Step 1 of the Merge Link implementation guide. Read reference docs and scan the codebase. Do NOT write any code during this step.

## Step 1: Read Reference Documentation

Read all three files (paths relative to this skill's base directory):

- `../implementing-merge-link/references/platform-overview.md` — Core Merge concepts, auth flow, account lifecycle
- `../implementing-merge-link/references/backend-implementation.md` — Backend API patterns, token exchange, database schema
- `../implementing-merge-link/references/frontend-implementation.md` — Frontend UI patterns (Connect Button and Marketplace)

Read each file completely before proceeding.

## Step 2: Scan the Codebase

Ask the user before scanning: "I'll search your codebase for your tech stack, existing schema, and any Merge-related code. Ready to proceed?"

Identify:

- Tech stack: language, framework, ORM
- Existing database schema (migrations, models, or schema files)
- Any existing Merge-related code (search for "merge", `MERGE_API_KEY`, `account_token`)

## Step 3: Confirm Readiness

Output a brief confirmation covering:

1. Tech stack identified (language, framework, ORM)
2. Merge docs loaded (list the three files read)
3. Any existing Merge code found (or none)
4. Ready to proceed to the next implementation step

Do not write any implementation code during this step.
