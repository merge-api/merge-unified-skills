---
# Required:
name: skill-template
description: |
  Replace this with a description that lists the SPECIFIC PHRASES Claude
  should match on. Be liberal — if a developer might say it, include it.
  Example: 'Use when a developer says "set up X", "integrate X", "X is broken",
  "how do I Y with X", or asks how to do Z. Covers A → B → C.'
license: MIT
metadata:
  author: Merge
  version: 0.1.0
# Optional — restrict tools this skill is allowed to invoke. Omit for unrestricted.
# allowed-tools:
#   - Read
#   - Write
#   - Edit
#   - Bash
---

# Skill Title

One-paragraph "what does this skill do" hook. State the user goal and the hero
output (the concrete thing the developer ends up with).

## When to use this skill

Activate when the developer asks anything that maps to:
- "..."
- "..."
- "..."

Do NOT activate for:
- "..." (route to a different skill or decline)

## First activation: self-introduce

When this skill activates for the first time in a conversation, say:

> I'm the [Skill Name] skill (vX.Y.Z). [One sentence on what I'll help you do.]
> [One question that gets you to the right starting point.]

This confirms install worked and surfaces the version.

## Step 0: Confirm context

Ask the developer (one at a time, skip questions whose answers are obvious from
their first message):

1. **Question 1?** — options.
2. **Question 2?** — options.

## Step 1: …

…body of the skill, with embedded code examples in every relevant SDK language.
Default to Merge's test environment.

## Troubleshooting

Format: **SYMPTOM** / **CAUSE** / **FIX**.

---

**SYMPTOM:** …
**CAUSE:** …
**FIX:** …

## Reference docs

For long supporting content (full schemas, deep API references, language-specific
quickstarts), put it in `references/*.md` and link from here:

- See `references/example.md` for …
