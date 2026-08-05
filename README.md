# Jackdaw

An iOS quick-capture inbox: grab a fleeting note fast, with ambient context
attached automatically, then export it to your notes system. A funnel into your
notes, not an archive — **no triage stage**, no batch sorting, no browsing past
notes.

Codename only; a marketable name comes later. Greenfield native iOS app, single
user (the owner).

## Status

**Pre-planning.** This repo currently holds the development scaffolding — the
tripod personas, slash commands, and PR workflow — and no product yet. Next up:
a planning session to define v1.

A prior prototype (Capture → **Triage** → Export, reached TestFlight) lives at
[jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike). This repo is
a **restart at reduced scope**, not a continuation: triage is cut, capture and
export remain, and tagging is being redesigned now that there's no triage stage
to defer it to. The spike's decisions are reference material, re-examined in
`docs/prototype-learnings.md`.

## Start here

| If you want… | Read |
|---|---|
| Project context, scope, conventions | [`CLAUDE.md`](CLAUDE.md) |
| Current state and the next step | [`docs/STATUS.md`](docs/STATUS.md) |
| How changes land (branches, PRs, reviews) | [`docs/dev-workflow.md`](docs/dev-workflow.md) |
| What we're keeping from the prototype | [`docs/prototype-learnings.md`](docs/prototype-learnings.md) |

## Layout

```
.claude/agents/        product-lead, design-lead, tech-lead — the "tripod"
.claude/agent-memory/  their persistent project memory (empty by design)
.claude/commands/      /prd /adr /open-pr /checkpoint-review /handoff
ci_scripts/            Xcode Cloud post-clone hook (inert until there's a project)
docs/prd/              product requirements
docs/adr/              architecture decision records — one decision per file
docs/design/           flows, screen inventory, accessibility
docs/specs/            per-issue implementation specs (only where warranted)
```

Bugs, ideas, and backlog live in
[GitHub Issues](https://github.com/jimcasey/jackdaw/issues); `docs/` records
decisions and specs.
