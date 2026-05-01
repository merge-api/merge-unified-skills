# Merge Unified API — Claude Code Skills

A Claude Code plugin with skills for integrating with and building on the [Merge Unified API](https://docs.merge.dev/) — one API for HRIS, ATS, CRM, Accounting, Ticketing, File Storage, Knowledge Base, and Marketing integrations.

## Installation

Add the plugin marketplace, then install:

```bash
claude plugin marketplace add merge-api/merge-unified-skills
claude plugin install merge-unified
```

That's it — the skills are ready to use immediately.

### Alternative: manual install

If you prefer to add skills directly to a single project:

```bash
git clone https://github.com/merge-api/merge-unified-skills.git
mkdir -p /path/to/your/project/.claude/skills/
cp -r merge-unified-skills/skills/* /path/to/your/project/.claude/skills/
```

## Getting Started

After installing, open Claude Code and try:

### Onboard to the Merge Unified API

```
/merge-unified:merge-onboarding
```

### Implement Merge Link in your app

```
/merge-unified:implementing-merge-link
```

### Set up data syncing

```
/merge-unified:implementing-merge-sync
```

Or just describe what you want — Claude will pick the right skill:

- "Add Merge to this project"
- "Set up an HRIS integration with Merge"
- "Implement the Merge Link connect button"
- "Set up webhook-based syncing with Merge"
- "Build an integration settings page"

## Available Skills

| Skill | Command | What it does |
|-------|---------|--------------|
| **Merge Onboarding** | `/merge-unified:merge-onboarding` | Walk a developer from signup to a working Linked Account: SDK install, link_token → account_token flow, first API call, webhooks, and the production checklist. |
| **Integration Validator** | `/merge-unified:merge-validate` | Run diagnostic checks against a live Merge integration: API key, account_token, sync status, data access, pagination. Outputs a pass/fail report with fixes. |
| **Implementing Merge Link** | `/merge-unified:implementing-merge-link` | Full Merge Link implementation: database schema, backend API (link token, token exchange, relink, delete), and frontend UI. Step 1 loads context inline; Steps 2–4 invoke focused sub-skills (database setup, backend endpoints, and frontend — connect button OR marketplace). |
| **Implementing Merge Sync** | `/merge-unified:implementing-merge-sync` | Set up data syncing after a connection is established. Webhooks are the production-recommended primary; polling is the development starting point and a production fallback. A single skill per approach covers both initial and subsequent syncs. |
| **Implementing Post-Connection** | `/merge-unified:implementing-merge-post-connection` | Build the post-connection experience: integration settings page (with persistence backend), sync status UI, relinking, custom field mappings, and category-aware data-scope filtering. 6 numbered steps; Step 1 loads context inline. |

## What You'll Need

- A Merge API key — get one from the [Merge dashboard](https://app.merge.dev/keys). Use a `test_xxx` key while developing; switch to `production_xxx` before launch.

## How It Works

All skills use Merge's official **SDKs**. Six languages are supported:

| Language | Package | Repo |
|---|---|---|
| Python | `MergePythonClient` (PyPI) | [merge-python-client](https://github.com/merge-api/merge-python-client) |
| Node / TypeScript | `@mergeapi/merge-node-client` (npm) | [merge-node-client](https://github.com/merge-api/merge-node-client) |
| Java / Kotlin (JVM) | `dev.merge:merge-java-client` (Maven) | [merge-java-client](https://github.com/merge-api/merge-java-client) |
| Go | `github.com/merge-api/merge-go-client` | [merge-go-client](https://github.com/merge-api/merge-go-client) |
| Ruby | `merge_ruby_client` (RubyGems) | [merge-ruby-client](https://github.com/merge-api/merge-ruby-client) |
| C# / .NET | `Merge.Client` (NuGet) | [merge-csharp-client](https://github.com/merge-api/merge-csharp-client) |

Skills support all six languages — tell Claude which one you're using, or it'll ask. Two examples:

**Python**

```python
from merge import Merge

client = Merge(api_key="YOUR_API_KEY", account_token="ACCOUNT_TOKEN")
employees = client.hris.employees.list()
```

**TypeScript / Node**

```typescript
import { MergeClient } from "@mergeapi/merge-node-client";

const merge = new MergeClient({
  apiKey: "YOUR_API_KEY",
  accountToken: "ACCOUNT_TOKEN",
});
const employees = await merge.hris.employees.list();
```

For canonical install + initialization snippets in Java, Go, Ruby, and C#, see each SDK's repo README (linked above).

## Multi-Tool Support

Convert all 16 skills to 9 AI coding tools with a single script.

| Tool | Format | Install |
|------|--------|---------|
| Cursor | `.cursor/rules/` | `./scripts/convert.sh --tool cursor --target .` |
| Aider | `CONVENTIONS.md` | `./scripts/convert.sh --tool aider --target .` |
| Windsurf | `.windsurf/skills/` | `./scripts/convert.sh --tool windsurf --target .` |
| Kilo Code | `.kilocode/rules/` | `./scripts/convert.sh --tool kilocode --target .` |
| OpenCode | `.opencode/skills/` | `./scripts/convert.sh --tool opencode --target .` |
| Codex | `.codex/skills/` | `./scripts/convert.sh --tool codex --target .` |
| Augment | `.augment/rules/` | `./scripts/convert.sh --tool augment --target .` |
| Antigravity | `~/.gemini/antigravity/skills/` | `./scripts/convert.sh --tool antigravity --target .` |
| Hermes Agent | `~/.hermes/skills/` | `./scripts/convert.sh --tool hermes --target .` |

### How it works

```bash
# 1. Convert all skills to all tools (takes ~15 seconds)
./scripts/convert.sh --tool all

# 2. Or install directly into your project for a specific tool
./scripts/convert.sh --tool cursor --target /path/to/your/project

# 3. Or generate tool-specific outputs locally
./scripts/convert.sh --tool aider
```

Each tool gets:
- All 16 skills converted to native format
- Per-tool README with installable/pluggable steps
- Reference docs preserved alongside skills
- Zero manual conversion work

Run `./scripts/convert.sh --list` to see all supported tools.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a new skill, the PR workflow, and the publish playbook.

## License

[MIT](LICENSE).
