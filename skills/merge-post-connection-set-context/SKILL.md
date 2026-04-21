---
name: merge-post-connection-set-context
description: Load post-connection reference documentation and scan the codebase for existing settings UI and error handling. Use as Step 1 of the post-connection implementation before writing any code. Typically invoked automatically by the `implementing-merge-post-connection` skill — you usually don't need to invoke this directly.
license: MIT
metadata:
  author: Merge
  version: 0.1.0
---

# Set Context: Post-Connection

Load reference docs and scan the codebase. Do NOT write any code during this step.

## 1. Read Reference Documentation

Read these files (paths are relative to this skill's directory):

- `../implementing-merge-link/references/platform-overview.md` — Merge concepts and account lifecycle
- `../implementing-merge-link/references/backend-implementation.md` — Backend patterns and sync implementation
- `../implementing-merge-post-connection/references/post-connection-fundamentals.md` — Initial sync best practices, error messaging, custom fields, and filtering options

## 2. Scan the Codebase

Ask the user before scanning: "I'll search your codebase for existing settings pages, error handling, and the `linked_accounts` schema. Ready to proceed?"

Search for:

- Existing settings or account management pages (routes, views, or components)
- Error handling logic and user-facing error messages
- Any existing relinking or re-authentication flows
- The `linked_accounts` table schema (columns, indexes, relations)

## 3. Confirm Readiness

Output a brief summary covering:

- Tech stack detected (language, framework, ORM, frontend library)
- Any existing settings UI or error-handling patterns found
- `linked_accounts` schema (relevant columns)
- Confirmation that all three reference docs were loaded

Do not write or modify any code until Step 2 (`merge-post-connection-build-settings-page`) is invoked.
