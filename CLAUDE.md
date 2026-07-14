# CLAUDE.md

Project context for Claude Code. This file loads automatically into every
session and every subagent, so keep it lean — put deep detail in the linked
docs, not here.

## Project

- **App:** An iOS quick-capture inbox that grabs fleeting notes with ambient context attached automatically, lets you triage them in batches, and exports the keepers to Obsidian — a funnel into your notes system, not an archive.
- **Codename:** Jackdaw.
- **Platform:** iOS (native). New app, greenfield.
- **Status:** Pre-build. Currently in product definition / technical design.

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

## Owner background (for tailoring explanations)

Strong full-stack engineer and ex-EM; comfortable at architecture and product
level. Little iOS/Swift experience. Explain iOS-specific choices and teach the
reasoning rather than just asserting — the owner needs to be able to audit
generated Swift.
