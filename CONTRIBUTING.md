# Contributing to merge-unified-skills

This repo is the source of truth for Merge's Claude Code skills around the [Unified API](https://docs.merge.dev/). It is currently **private** while we build out the initial skill set; it will become public when ready (see "Publishing to public" below).

## Repo layout

```
.claude-plugin/         Plugin + marketplace metadata
  plugin.json
  marketplace.json
.claude/
  skills/
    _template/          Reference skeleton — copy this when adding a new skill
    merge-onboarding/   First skill: signup → working Linked Account
scripts/
  check-skill.sh        Validates SKILL.md frontmatter
.github/workflows/
  validate-skills.yml   Runs check-skill.sh on every PR
README.md               Public-facing intro
CHANGELOG.md            Versioned release notes
CLAUDE.md               Conventions for Claude Code working in this repo
AGENTS.md               Same, for non-Claude AI agents
LICENSE                 MIT
```

## Adding a new skill

1. Copy the template:

   ```bash
   cp -r .claude/skills/_template .claude/skills/your-skill-name
   ```

2. Edit `.claude/skills/your-skill-name/SKILL.md`:
   - Set `name:` to match the folder name (kebab-case).
   - Write a `description:` that lists the **specific phrases** Claude should match on. Be liberal — if a developer might say it, include it. Look at `merge-onboarding/SKILL.md` for a reference description.
   - Set `metadata.author: Merge` and `metadata.version: 0.1.0`.
3. Move long supporting docs (schemas, deep API references, code samples that don't need to be in Claude's main context every invocation) into `references/*.md` and link to them from `SKILL.md` by relative path.
4. Run the validator: `bash scripts/check-skill.sh`.
5. Open a PR. CI will re-run the validator.

### Skill writing principles

- **Make the first activation announce itself.** Claude should say which skill it just loaded and the version. This confirms install worked.
- **Always show both SDK and HTTP examples** unless the developer specifies a language.
- **Default to the test environment** in every example. Tell developers to swap to production explicitly before shipping.
- **Embed real schemas / endpoints / verification code.** Don't hand-wave with "see the docs". Skills exist to save the developer from reading docs.
- **Inline response schemas at every step that calls an API.** Show the fields, types, and gotchas (e.g., "this field is an SDK model object, not a string"). Don't delegate load-bearing information to reference docs — an AI agent follows the main skill body step-by-step and won't proactively read references unless told to.
- **Show complete handler patterns, not fragments.** Replace `# Save to your DB: customer.token = token` with a real handler that shows the DB lookup, update, and response. AI agents generate code from these examples literally.
- **Document SDK object types explicitly.** When the Merge SDK returns model objects (pydantic in Python, typed objects in Node), note that they're not plain dicts and show how to serialize them (`.model_dump()`, `.name`, spread operator).
- **Include a Troubleshooting section** with SYMPTOM / CAUSE / FIX entries for the top 5–8 things that go wrong.

## PR workflow

- Branch from `main`. Branch names: `add-<skill>`, `fix-<skill>-<issue>`, `docs-<topic>`.
- One skill per PR (don't bundle multiple new skills).
- PR description must include: what the skill does, who it's for, and one example user prompt that should activate it.
- Squash-merge into `main`.
- Bump `version` in `.claude-plugin/plugin.json` and add a `CHANGELOG.md` entry on every PR.

## Local testing

Test a skill locally before opening a PR:

```bash
# Install the plugin from this directory:
cd ~/Developer/merge-unified-skills
claude plugin install .

# Then in any project, invoke the skill:
claude
> /merge-unified:your-skill-name
```

Try several phrasings from the skill's `description` field to confirm Claude routes to it.

## Publishing to public

When the skill set is ready for client/public consumption, **do not flip this private repo to public** — that exposes all prior commits, PRs, and Actions logs. Instead, push an orphan branch to a new public repo so the public version starts from a single clean commit.

### Pre-publish checklist

Run from a clean checkout of `main`:

- [ ] Remove `.claude/skills/_template/` (build-only scaffolding; not for end users)
- [ ] Audit `CHANGELOG.md` for any internal-only notes; rewrite as a clean public changelog
- [ ] Confirm no internal URLs, employee names, customer references, or staging credentials in any skill or doc
- [ ] Bump `.claude-plugin/plugin.json` version to `1.0.0`
- [ ] Update the version in `.claude-plugin/marketplace.json` to match
- [ ] Confirm `README.md` install instructions reference the new public repo path

### Publish steps

```bash
# 1. From a clean checkout of merge-unified-skills (private), create an orphan branch:
git checkout --orphan publish
git add -A
git commit -m "Initial public release"

# 2. Create the new public repo:
gh repo create merge-api/merge-unified-skills-public \
  --public \
  --description="Claude Code skills for the Merge Unified API"

# 3. Push the orphan branch as `main` on the public repo:
git remote add public git@github.com:merge-api/merge-unified-skills-public.git
git push public publish:main

# 4. Restore your local branch:
git checkout main
git branch -D publish
```

### After publishing

- The public repo now has exactly one commit. No PR or Actions history.
- This private repo remains the internal source of truth. Continue developing here.
- To publish updates: cherry-pick or squash internal commits onto a new orphan branch, then push to the public repo. (Or for cleaner per-release publishing, repeat the whole orphan flow on each public release.)
- (Optional) Once stable, rename the public repo to drop the `-public` suffix and archive or rename the private repo.

## License

[MIT](LICENSE).
