# STATUS — Jackdaw (no-triage rebuild)

**Read this first** when resuming Jackdaw in a new or remote session. It is the
living handoff: where the project stands, what's decided, and how to build.
Refresh it with `/handoff`.

Open work lives in **GitHub Issues**, grouped by milestone — this file points at
it rather than duplicating it.

**Last updated:** 2026-08-05

---

## Where we are

**Pre-planning.** This repo is a fresh start on a reduced scope: the funnel keeps
both ends (**capture → export**) but **triage is dropped.** It contains the
workflow scaffolding carried over from the prototype and nothing else — no PRD,
no ADRs, no design docs, no Xcode project, no code.

The prior spike is at `~/Code/jackdaw-spike`
([jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike)). It got as
far as TestFlight with capture + SwiftData working. Treat it as **reference
material to mine**, not as inherited decisions.

### What's next

The plan lives in **[GitHub Issues](https://github.com/jimcasey/jackdaw/issues)**,
grouped by milestone — not in this file. Check the tracker for current state; the
summary below is orientation only and goes stale.

- **[M0 — Planning & decisions](https://github.com/jimcasey/jackdaw/milestone/1)**
  — define the no-triage v1. Distill the prototype (#1), PRD (#2), tagging design
  (#3), export decision (#4). No app code in this milestone.
- **[M1 — Walking skeleton](https://github.com/jimcasey/jackdaw/milestone/2)** —
  deployment target (#5) and persistence (#6) ADRs, Xcode project (#7), TestFlight
  (#8), Xcode Cloud CI (#9).

Later milestones — capture and export themselves — come out of M0. Deliberately
not planned yet; that would presuppose the PRD.

**Start with #1 (distill the prototype).** Listed second in the owner's original
framing, but it feeds the scope, tagging, and export decisions rather than
following them.

**The sharpest open question** is where tagging sits (#3). Tagging is an
owner-ratified scope *expansion*, not recovered triage work — the spike banned
organizing in v1 and its unbuilt successor put type selection at the capture
trigger, deliberately not as tags. Every control in the capture path costs capture
speed, which is the whole product, so get design-lead on it rather than letting it
get settled by default.

---

## Key decisions

| Decision | Status | Where |
|----------|--------|-------|
| Triage/sorting is cut | Owner-directed, pre-PRD | `CLAUDE.md` §Scope reset |
| Tagging is in — a deliberate scope expansion beyond the spike | Owner-ratified 2026-08-05; **specifics undesigned** | `CLAUDE.md` §Scope reset |
| Export survives — the funnel keeps both ends | Owner-directed, pre-PRD | `CLAUDE.md` §Scope reset |
| Development workflow (PR + tripod review) | Carried over from spike | `docs/dev-workflow.md` |
| Export destinations & mechanism | **Undecided** — spike's Obsidian/Apple Notes work is a reuse candidate | — |
| Everything else (persistence, min iOS target, nav model) | **Undecided — re-decide, don't inherit** | — |

No ADRs yet. `docs/adr/` is empty.

---

## Build & verify recipe

None yet — there is no Xcode project. This section gets filled in with the
walking skeleton (scheme name, simulator target, the `xcodebuild` test
invocation, and any gotchas).

Building/verifying on the far side of a session move needs **Xcode 26.x + the
iOS 26 SDK**; a sandbox without Xcode can still edit code and drive the
docs-based workflow.

---

## The tripod & memory

Three persona subagents in `.claude/agents/` — `product-lead`, `design-lead`,
`tech-lead` — each with project memory under `.claude/agent-memory/`.

**Their memory is intentionally empty.** The spike's persona memory was *not*
copied: starting the personas fresh is what keeps the scope cut real, since much
of what they had learned assumed a triage stage — and their settled position on
classification (ban it in v1; type at the trigger in v1.x) is the very thing the
tagging expansion overrides. Lessons worth keeping come back deliberately via
issue #1, one at a time.

---

## What travels vs. what doesn't

The **git repo is the single source of truth.** A new or remote session sees only
what is committed and pushed.

- **Travels:** `CLAUDE.md`, everything in `docs/`, `.claude/agent-memory/`,
  `.claude/agents/`, `.claude/commands/`, `ci_scripts/`, and all code + tests.
  GitHub Issues and milestones aren't in git, but any session with `gh` or the
  GitHub MCP tools can read them.
- **Does not travel:** Claude Code's per-project auto-memory
  (`~/.claude/projects/.../memory/`), the conversation transcript, prior agent
  instances, and anything in `~/Code/jackdaw-spike` (a separate repo — a remote
  session cannot see it).

**Before switching sessions:** run `/handoff`, then commit and push your branch
and open/update its PR. Unmerged work must be on a pushed branch, not stranded
locally.
