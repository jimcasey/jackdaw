# CLAUDE.md

Project context for Claude Code. This file loads automatically into every
session and every subagent, so keep it lean — put deep detail in the linked
docs, not here.

## Project

- **App:** An iOS quick-capture inbox that grabs fleeting notes with ambient
  context attached automatically and exports the keepers to your notes system —
  a funnel into your notes, not an archive. **No triage step.**
- **Codename:** Jackdaw (marketable name TBD later in the project).
- **Platform:** iOS (native). New app, greenfield. Single user (the owner).
- **Status:** Pre-planning. The repo currently holds the workflow scaffolding
  and nothing else — no PRD, no ADRs, no Xcode project yet.
- **Governing principle:** Jackdaw is a funnel, not an archive. Notes flow
  Capture → Export and leave the app; it never becomes their home. If a feature
  helps fast capture or clean handoff, it's in scope; if it moves toward
  organizing, searching, or browsing past notes, it's out.
- **Relationship to the prototype:** this is a **restart**, not a continuation.
  A prior spike lives at `~/Code/jackdaw-spike`
  ([jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike)) and
  reached TestFlight with capture + SwiftData working. Its code, docs, ADRs,
  and persona memory are **reference material to mine, not inherited truth** —
  see "Scope reset," below.

## Scope reset (why this repo exists)

The spike scoped the app as a funnel: Capture → **Triage** → Export. The new
version **cuts triage.** The funnel keeps both ends — notes still leave the app —
but there is no batch-sorting stage in between.

- **In:** fast, reliable capture of a fleeting note with ambient context
  attached automatically, and **export** of notes to the owner's notes system.
- **Out:** triage and everything built on it — batch sorting, swipe-to-keep or
  discard, snooze, a triage inbox as the app's root — and anything else that
  turns the app into a place you organize or browse past notes.
- **Changing, not just shrinking:** dropping triage moves work that triage used
  to do. Chief among them, **tagging notes at capture time** — the spike deferred
  classification to the triage stage; here it has to happen at or near capture, or
  not at all. Expect the capture screen, the note model, and the export mapping to
  differ from the spike as a result. The planning session owns the specifics; the
  design-lead owns the interaction cost of putting tagging in the capture path,
  which is the sharpest tension in this scope (capture must stay fast).
- **Open for planning:** the export destination(s) and mechanism (the spike shipped
  Obsidian and Apple Notes paths), and how tagging works end to end.

Until the planning session lands a PRD, treat any scope claim inherited from
the spike as unratified. The spike's export work is a **candidate to reuse**, not
a settled decision.

## Who's who

This project runs as a one-person product team plus three AI personas — the
"tripod." The human owner is an experienced full-stack engineer and
engineering manager, new to iOS specifically, acting as **high-level architect
and product owner**. The owner arbitrates when the personas disagree.

The three personas are Claude Code subagents in `.claude/agents/`:

- **`product-lead`** — owns the *why/what*: problem, users, jobs-to-be-done,
  MVP scope, non-goals, success criteria. Biases toward scope discipline.
- **`design-lead`** — owns the *experience*: flows, navigation, screens, HIG
  conformance, accessibility. Biases toward native, high-quality UX.
- **`tech-lead`** — owns the *how*: architecture, iOS/Swift stack, feasibility,
  code review, testing. Biases toward maintainability and correctness.

They are meant to disagree. Productive tension between the three mandates is
the point; if they just agree with each other and the owner, they add no
signal. Each states disagreements plainly, names the tradeoff, and defers the
final call to the owner.

Invoke a persona by naming it ("have the tech-lead review this") or with an
@-mention (`@agent-tech-lead`). Each keeps persistent project memory under
`.claude/agent-memory/` (committed to version control). **That directory is
empty by design** — the personas start fresh here. Carrying a lesson over from
the spike is a deliberate act (see `docs/prototype-learnings.md`), not a copy.

## Stack decisions (working defaults — ratify via ADR before relying on them)

- **UI:** SwiftUI (UIKit only where SwiftUI has real gaps).
- **Architecture:** MVVM. Defer heavier patterns (e.g. TCA) for now.
- **Dependencies:** Swift Package Manager. No CocoaPods.
- **Persistence:** TBD. The spike chose SwiftData for a store that had to hold
  notes through a triage stage; without triage, notes are shorter-lived here.
  Re-decide, don't inherit.
- **Min iOS target:** TBD — choose deliberately; it gates available APIs.

Changes to these go through an ADR in `docs/adr/`.

## The de-risking rule

Build a **walking skeleton first**: one thin end-to-end path that actually
builds onto a physical device via TestFlight, *before* real features. For a
web engineer the platform risk is the toolchain — signing, provisioning,
Xcode, TestFlight, App Store review — not writing views. De-risk that while
the app does almost nothing, then iterate features against a known-good
deployment path.

The spike already proved this path once (App Store Connect record, Xcode Cloud,
TestFlight). Re-walking it here should be faster, but it is still step one.

## iOS toolchain reality

Xcode is unavoidable here. Claude Code and Cursor write and edit Swift well,
but building, running the simulator, wiring signing, and profiling with
Instruments happen in Xcode. Expect that context switch.

## Conventions

- **Docs:** PRD in `docs/prd/`, architecture decisions in `docs/adr/` (one
  decision per file: context / decision / consequences), design flows and
  screen inventory in `docs/design/`, per-issue specs in `docs/specs/` (only
  where an issue needs durable rationale — see `docs/dev-workflow.md`).
- **Naming:** corvid/crow theme for modules, features, and internal codenames.
- **Decisions:** if it's a real decision, write it down (ADR or PRD) so it
  survives across sessions and the personas don't relitigate settled ground.
- **Tracking vs. decisions:** work is tracked in **GitHub Issues**, grouped by
  **milestone** — that's the backlog and the plan. `docs/` records **decisions and
  specs** — the durable "why" that travels in git across sessions. Don't
  reintroduce to-do / backlog lists into docs; file an issue. The unit of work is
  an **issue** (the spike's "slice" is retired). Vocabulary and the
  where-does-a-spec-live rule: `docs/dev-workflow.md`.

## Development workflow (PRs & reviews)

Changes land via **pull request**, not direct pushes to `main`. Full process in
`docs/dev-workflow.md`; the essentials:

- **Branch → commit → `/open-pr` → `/checkpoint-review` → merge.** `main` stays
  buildable and green; don't push to it directly.
- **Agent PR automation (owner-directed, standing):** after pushing a coherent
  change to its branch, the agent **opens the PR automatically** — it does **not**
  wait for owner confirmation — and then **stops**. The agent does **not** watch,
  poll, or gate on CI. The **owner** notifies the agent when a PR is merged and
  reports any CI/build errors back for the agent to fix. Full rules in
  `docs/dev-workflow.md` §"Agent PR automation."
- **Reviews reuse the tripod**, each on its dimension — tech-lead (architecture,
  Swift, tests), design-lead (HIG, a11y, when UI changes), product-lead (scope) —
  plus the built-in `/code-review` for line-level mechanics. No separate reviewer
  agent. Calibrate the panel to the change; reviews advise, the owner decides.
- **Recording decisions:** a real architectural decision gets its **own ADR PR
  first** (ratify before building); persona-memory and issue specs ride **in the
  same PR** as the code they document.
- **CI (not built yet):** Xcode Cloud will build/test on PRs and distribute to
  TestFlight on merge, as it did in the spike. Cloud minutes are a finite
  owner-managed quota — the agent never triggers or reconfigures cloud builds;
  it iterates on the local simulator + unit tests and stops at "push branch /
  open PR." Details in the workflow doc.

## Session continuity (resuming, or moving to a remote session)

The **git repo is the single source of truth.** A new or remote Claude Code
session only sees what is **committed and pushed** — Claude Code's per-project
auto-memory (`~/.claude/projects/.../memory/`) and the conversation transcript
are machine-local and do **not** travel.

- **Resuming Jackdaw?** Read `docs/STATUS.md` first — it's the living handoff:
  where the project stands, the decision log with ADR pointers, the build/verify
  recipe, and the immediate next step. Open/backlog work lives in **GitHub
  Issues**, not the docs.
- **Travels via git:** this file, everything in `docs/`, `.claude/agent-memory/`,
  `.claude/agents/`, `.claude/commands/`, and all code + tests.
- **Before switching sessions:** run `/handoff` to refresh `docs/STATUS.md`, then
  **commit and push your branch** (and open/update its PR). Keep decisions and
  in-flight context out of the chat and in a doc/ADR/persona-memory so nothing is
  lost in the move.

## Owner background (for tailoring explanations)

Strong full-stack engineer and ex-EM; comfortable at architecture and product
level. Little iOS/Swift experience. Explain iOS-specific choices and teach the
reasoning rather than just asserting — the owner needs to be able to audit
generated Swift.
