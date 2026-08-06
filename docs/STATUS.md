# STATUS — Jackdaw (no-triage rebuild)

**Read this first** when resuming Jackdaw in a new or remote session. It is the
living handoff: where the project stands, what's decided, and how to build.
Refresh it with `/handoff`.

Open work lives in **GitHub Issues**, grouped by milestone — this file points at
it rather than duplicating it.

**Last updated:** 2026-08-06

---

## Where we are

**Pre-planning, scaffolding merged.** The bootstrap PR (#10) is on `main`. The
repo holds the development framework — the tripod personas, the slash commands,
the PR workflow, and the scope decisions below — and **no product yet**: no PRD,
no ADRs, no design docs, no Xcode project, no app code, no tests.

The prior spike is at `~/Code/jackdaw-spike`
([jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike)). It reached
TestFlight with capture + SwiftData working. Treat it as **reference material to
mine**, not as inherited decisions — that's issue #1.

### What's next

The plan lives in **[GitHub Issues](https://github.com/jimcasey/jackdaw/issues)**,
grouped by milestone — not in this file. Check the tracker for current state; the
summary below is orientation only and goes stale.

- **[M0 — Planning & decisions](https://github.com/jimcasey/jackdaw/milestone/1)**
  — define the no-triage v1. Distill the prototype (#1), PRD (#2), classification
  decision (#3), export decision (#4), persistence ADR (#6), plus two product calls
  surfaced by review: the "inbox" naming contradiction (#11) and whether v1
  attaches location (#12). **No app code in this milestone.**
- **[M1 — Walking skeleton](https://github.com/jimcasey/jackdaw/milestone/2)** —
  pure toolchain: deployment-target ADR (#5), Xcode project (#7), TestFlight (#8),
  Xcode Cloud CI (#9).
- **Unmilestoned:** #13, small docs/process cleanups from the #10 review.

Later milestones — capture and export themselves — come out of M0. Deliberately
not planned yet; that would presuppose the PRD.

**Start with #1 (distill the prototype).** It feeds the scope, classification, and
export decisions rather than following them. It now leads with **usage evidence** —
what the owner actually did with the shipped spike — which is the best product
data this project will ever have and exists nowhere in either repo.

**The sharpest open question** is #3, whether v1 classifies notes at all and where.
Tagging is an owner-ratified scope *expansion*, not recovered triage work. Every
control in the capture path taxes capture speed, which is the whole product — get
design-lead on it rather than letting it settle by default.

---

## Key decisions

| Decision | Status | Where |
|----------|--------|-------|
| Triage/sorting is cut — superfluous; the destination app edits, AI sorts later | Owner-directed 2026-08-05 | `CLAUDE.md` §Scope reset |
| Export survives — the funnel keeps both ends | Owner-directed | `CLAUDE.md` §Scope reset |
| Export directly and fail loudly — no pending list, outbox, badge, or retry queue | Owner-directed 2026-08-05 | `CLAUDE.md` §Simplicity rule |
| Tagging is in — a deliberate scope expansion beyond the spike | Owner-ratified 2026-08-05; **specifics undesigned** (#3) | `CLAUDE.md` §Scope reset |
| This version **replaces** the spike — reuse its App Store Connect record, start at **2.x** | Owner-directed 2026-08-05 | #7, #8 |
| Squash-and-merge only; PR required on `main` (ruleset **active**) | Owner-directed 2026-08-05 | `docs/dev-workflow.md` §Merge strategy |
| Development workflow (PR + tripod review) | Carried over from spike | `docs/dev-workflow.md` |
| Work is tracked as GitHub issues/milestones; "slice" retired | Owner-directed | `docs/dev-workflow.md` §How work is named |
| Export destinations & mechanism | **Undecided** — #2 picks destinations, #4 owns mechanism | — |
| Persistence, min iOS target, nav model | **Undecided — re-decide, don't inherit** | #6, #5 |

**No ADRs yet.** `docs/adr/`, `docs/prd/`, `docs/design/`, and `docs/specs/` are
all empty. Per `docs/dev-workflow.md`, a decision that gates code gets its own
ratified ADR PR *before* the code — that rule is untested so far because nothing
has been built.

### The constraint most likely to be violated by accident

`CLAUDE.md` §Simplicity rule. Export failure has a natural pull toward a durable
queue, and the path there is four individually-reasonable steps: retry → needs
durable storage → user should know → needs a count → should see which ones → needs
a list → should act on each → **that list is triage, rebuilt.** #4 and #6 are both
explicitly bound by this. **What happens to a note whose export fails is still an
open question** — it just has to be answered without a per-note decision surface.

---

## Build & verify recipe

**None yet — there is no Xcode project and no test suite.** Test count: 0 (no
target exists). This section gets written as part of #7, and should cover the
scheme name, simulator target, the `xcodebuild` test invocation, and gotchas.

Building/verifying on the far side of a session move needs the **current stable
Xcode** (26.x as of 2026-08); a sandbox without Xcode can still edit code and drive
the docs-based workflow. Deliberately not pinned to an SDK version — the minimum
deployment target is undecided (#5), and iOS 27 is expected around September 2026.

### Known toolchain traps, recorded before they bite

These came out of the #10 review and are written into the issues that will hit
them. Repeated here because they are the expensive kind:

- **`ci_scripts/` must be a sibling of the `.xcodeproj`** (Xcode Cloud
  requirement). Xcode's New Project wizard pointed at the repo root defaults to
  `jackdaw/Jackdaw/Jackdaw.xcodeproj`, which **silently** breaks script discovery —
  the symptom appears days later as a duplicate-build-number rejection. (#7)
- **`ci_scripts/ci_post_clone.sh` fails silently** when its `sed` pattern doesn't
  match: exits 0, changes nothing, and logs a line claiming success. Left unhardened
  on purpose — it's inert until a project exists. (#7)
- **Never apply the docs-only skip to `PR CI`.** It belongs on the TestFlight
  workflow only; a *required* check that never reports leaves the PR permanently
  unmergeable. Every M0 issue is a docs-only PR, so the temptation arrives early. (#9)
- **Xcode Cloud's 25 compute-hours/month is per developer account, not per app** —
  shared with any workflows still enabled on the spike's repo. Disable those. (#8, #9)
- **The agent never triggers or reconfigures Xcode Cloud.** Cloud spend is
  owner-managed; the agent's job ends at "push branch / open PR."

---

## Git & PR mechanics (verified 2026-08-06)

- `main` is **protected by an active ruleset** requiring a pull request. Direct
  pushes are refused — this is enforcement, not just convention.
- **Squash-and-merge is the only strategy enabled.** Merge commits and rebase are
  off; branches delete automatically on merge.
- Squash title = **PR title**, so `(#N)` is always appended. Squash body = the
  **concatenated branch commit messages**. Verified on #10: all four commit
  messages survived into `main` (162 lines).
- **Therefore commit messages are the durable record.** A branch of `wip` / `fix
  typo` commits produces a useless permanent history. Write them properly.
- `(#N)` is a **pointer, not content** — following it needs network access and a
  live GitHub. Reasoning that must survive belongs in the commit body, an ADR, or
  `docs/specs/`.
- Branches are named for the issue they close (`issue-12-capture-screen`).

---

## The tripod & memory

Three persona subagents in `.claude/agents/` — `product-lead`, `design-lead`,
`tech-lead` — each with project memory under `.claude/agent-memory/`.

**Their memory is intentionally empty.** The spike's persona memory was *not*
copied: starting fresh is what keeps the scope cut real, since much of what those
personas learned assumed a triage stage — and their settled position on
classification (ban it in v1; type at the trigger in v1.x) is the very thing the
tagging expansion overrides. Lessons come back deliberately via #1, one at a time.

**Reviews are advisory and don't get committed.** During the #10 review a persona
wrote to its memory directory unprompted; that was removed. Memory records
**ratified** decisions, not review opinions — otherwise unarbitrated positions
become durable project context by accident.

Routing (`docs/dev-workflow.md`): tech-lead on any code change, design-lead only
when UI changes, product-lead on scope, `/code-review` for line-level mechanics.
Calibrate — a docs-only PR needs a read-through, not the full panel.

---

## What travels vs. what doesn't

The **git repo is the single source of truth.** A new or remote session sees only
what is committed and pushed.

- **Travels:** `CLAUDE.md`, everything in `docs/`, `.claude/agent-memory/`,
  `.claude/agents/`, `.claude/commands/`, `ci_scripts/`, and all code + tests.
- **Reachable but not in git:** GitHub Issues, milestones, and PR review threads.
  Any session with `gh` or the GitHub MCP tools can read them — but they need
  network and a live GitHub, and **comments on merged PRs are easy to lose track
  of.** The #10 review findings were moved into issues #11–#13 for exactly this
  reason.
- **Does not travel:** Claude Code's per-project auto-memory
  (`~/.claude/projects/.../memory/`), the conversation transcript, prior agent
  instances, and anything in `~/Code/jackdaw-spike` (a separate repo a remote
  session cannot see — mine it via #1 while local access lasts).

**Before switching sessions:** run `/handoff`, then commit and push your branch and
open/update its PR. `main` rejects direct pushes, so unmerged work must be on a
pushed branch, not stranded locally.
