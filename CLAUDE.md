# CLAUDE.md

Project context for Claude Code. This file loads automatically into every
session and every subagent, so keep it lean — put deep detail in the linked
docs, not here.

## Project

- **App:** An iOS quick-capture inbox that grabs fleeting notes with ambient
  context attached automatically, lets you triage them in batches, and exports
  the keepers to Obsidian — a funnel into your notes system, not an archive.
- **Codename:** Jackdaw (marketable name TBD later in the project).
- **Platform:** iOS (native). New app, greenfield. Single user (the owner).
- **Status:** Pre-build. Currently in product definition / technical design.
- **Governing principle:** Jackdaw is a funnel, not an archive. Notes flow
  Capture → Triage → Export and leave the app; it never becomes their home.
  If a feature helps fast capture or clean handoff, it's in scope; if it moves
  toward organizing, searching, or browsing past notes, it's out. Concept seed:
  `docs/prd/concept-brief.md`.

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
`.claude/agent-memory/` (committed to version control).

## Stack decisions (working defaults — ratify via ADR before relying on them)

- **UI:** SwiftUI (UIKit only where SwiftUI has real gaps).
- **Architecture:** MVVM. Defer heavier patterns (e.g. TCA) for now.
- **Dependencies:** Swift Package Manager. No CocoaPods.
- **Persistence:** TBD — SwiftData vs. Core Data vs. files/UserDefaults.
  Decide whether a backend is needed before over-building.
- **Min iOS target:** TBD — choose deliberately; it gates available APIs.

Changes to these go through an ADR in `docs/adr/`.

## The de-risking rule

Build a **walking skeleton first**: one thin end-to-end slice that actually
builds onto a physical device via TestFlight, *before* real features. For a
web engineer the platform risk is the toolchain — signing, provisioning,
Xcode, TestFlight, App Store review — not writing views. De-risk that while
the app does almost nothing, then iterate features against a known-good
deployment path.

## iOS toolchain reality

Xcode is unavoidable here. Claude Code and Cursor write and edit Swift well,
but building, running the simulator, wiring signing, and profiling with
Instruments happen in Xcode. Expect that context switch.

## Conventions

- **Docs:** PRD in `docs/prd/`, architecture decisions in `docs/adr/` (one
  decision per file: context / decision / consequences), design flows and
  screen inventory in `docs/design/`.
- **Naming:** corvid/crow theme for modules, features, and internal codenames.
- **Decisions:** if it's a real decision, write it down (ADR or PRD) so it
  survives across sessions and the personas don't relitigate settled ground.
- **Tracking vs. decisions (since v1):** bugs, feature ideas, and forward-looking
  planning live in **[GitHub Issues](https://github.com/jimcasey/jackdaw/issues)** (the
  backlog); `docs/` records **decisions and specs** — the durable "why" that travels
  across sessions. Don't reintroduce to-do / backlog lists into the docs; file an issue.

## Development workflow (PRs & reviews)

Changes land via **pull request**, not direct pushes to `main`. Full process in
`docs/dev-workflow.md`; the essentials:

- **Branch → commit → `/open-pr` → `/checkpoint-review` → merge.** `main` stays
  buildable and green; don't push to it directly.
- **Agent PR automation (owner-directed, standing):** after pushing a coherent
  change to its branch, the agent **opens the PR automatically** — it does **not**
  wait for owner confirmation. It then watches `PR CI` on a **~5-minute** cadence (a
  run takes ~5 min) and acts on the result: **green →** stop watching, hand back to
  the owner for the next action (don't re-arm); **yellow** (still building) **→**
  re-arm a ~5-min check; **red →** diagnose and push a fix. Full rules in
  `docs/dev-workflow.md` §"Agent PR automation."
- **Reviews reuse the tripod**, each on its dimension — tech-lead (architecture,
  Swift, tests), design-lead (HIG, a11y, when UI changes), product-lead (scope,
  funnel principle) — plus the built-in `/code-review` for line-level mechanics.
  No separate reviewer agent. Calibrate the panel to the change; reviews advise,
  the owner decides.
- **Recording decisions:** a real architectural decision gets its **own ADR PR
  first** (ratify before building); persona-memory and slice specs ride **in the
  same PR** as the code they document.
- **Xcode Cloud (future, not built):** will build/test on PRs and distribute to
  TestFlight on merge. Cloud minutes are a finite owner-managed quota — the agent
  never triggers or reconfigures cloud builds; it iterates on the local simulator
  + unit tests and stops at "push branch / open PR." Details in the workflow doc.

## Session continuity (resuming, or moving to a remote session)

The **git repo is the single source of truth.** A new or remote Claude Code
session only sees what is **committed and pushed** — Claude Code's per-project
auto-memory (`~/.claude/projects/.../memory/`) and the conversation transcript are
machine-local and do **not** travel.

- **Resuming Jackdaw?** Read `docs/STATUS.md` first — it's the living handoff:
  slice progress, the decision log with ADR pointers, the build/verify recipe and
  gotchas, and the immediate next step. Open/backlog work (bugs, v1.x features,
  decisions) lives in **GitHub Issues**, not the docs.
- **Travels via git:** this file, everything in `docs/` (PRD, ADRs, design,
  build-order, slices, STATUS.md), `.claude/agent-memory/` (the personas reload
  their state — re-invoke them; prior agent *instances* don't survive a move),
  `.claude/agents/`, `.claude/commands/`, and all code + tests.
- **Before switching sessions:** run `/handoff` to refresh `docs/STATUS.md`, then
  **commit and push your branch** (and open/update its PR — see
  `docs/dev-workflow.md`). A remote session only sees pushed commits; unmerged
  work must be on a pushed branch, not stranded locally. Keep decisions and
  in-flight context out of the chat and in a doc/ADR/persona-memory so nothing is
  lost in the move.
- **Remote build env** needs Xcode 26.x + the iOS 26 SDK to build/verify; a sandbox
  without Xcode can still edit code and drive the docs-based workflow.

## Owner background (for tailoring explanations)

Strong full-stack engineer and ex-EM; comfortable at architecture and product
level. Little iOS/Swift experience. Explain iOS-specific choices and teach the
reasoning rather than just asserting — the owner needs to be able to audit
generated Swift.
