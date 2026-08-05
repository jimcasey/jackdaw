# Development workflow — PRs & reviews

How changes land in Jackdaw. The short version: **work on a branch, open a PR,
review at checkpoints, merge to `main`.** `main` is protected by convention — we
don't push straight to it.

This doc is the canonical reference; `CLAUDE.md` links here. The commands
`/open-pr` and `/checkpoint-review` automate the ceremony.

> **Carried over from the prototype.** This process was developed and proven on
> the spike (`~/Code/jackdaw-spike`) and is deliberately kept intact for the
> no-triage rebuild. What changed: CI is not wired up yet, and the product-lead's
> review dimension now polices the dropped triage stage as well as the funnel
> principle.

---

## Why PRs at all (for a single-owner project)

Jackdaw is one owner plus the tripod (product-lead, design-lead, tech-lead). PRs
aren't about gatekeeping a team — they buy three things a solo project still
wants:

1. **A review surface.** A diff the tripod can critique as a unit, before it's
   permanent, instead of after-the-fact archaeology on `main`.
2. **A checkpoint.** A named boundary (the issue being closed) where we stop and ask
   *is this right?* rather than letting work blur together.
3. **A revert seam.** A merge commit is a clean undo point if an issue goes wrong.

The cost is ceremony. We keep it low: thin commands, docs that ride with code,
and no build gate the owner has to babysit.

---

## How work is named and tracked

Work is tracked in **GitHub Issues**, using GitHub's own vocabulary. The spike
called a unit of functionality a "slice"; that word is retired — it was a private
noun that had to be mapped onto the issue tracker every time.

| Term | Means |
|------|-------|
| **Milestone** | A coherent group of issues that ships together — the walking skeleton, capture, export. Replaces the spike's "waves" and its `build-order.md`. |
| **Issue** | The unit of work. One issue = one thin, reviewable piece of functionality, a decision to make, or a bug. Replaces "slice." |
| **PR** | Implements one issue (occasionally a couple of tightly-coupled ones). Closes it on merge via `Closes #N`. |
| **Label** | Cross-cutting kind: `adr`, `design`, `product`, `infra`, `bug`. |

**The division of labor is unchanged:** GitHub Issues holds the *backlog* — what's
open, what's next, what's broken. `docs/` holds *decisions and specs* — the
durable "why," which travels in git and is what a fresh or remote session reads.
Don't put a to-do list in `docs/`, and don't put an architectural decision only in
an issue comment.

**Where an issue's spec lives.** Most issues carry their own spec in the issue
body — that's enough for something small or self-evident. An issue with durable
design or architectural rationale gets a file in `docs/specs/`, named
`<issue-number>-<slug>.md`, linked from the issue. Rule of thumb: if someone six
months from now would need it to understand *why the code looks like this*, it
belongs in git, not in an issue body.

---

## Branching model

- **`main`** is the trunk. It should always build and pass unit tests. Merge into
  it via PR; don't push to it directly.
- **Feature branches** are short-lived and descriptive. Two flavors:
  - **Owner / local work:** name for the issue it closes, e.g.
    `issue-12-capture-screen`, `issue-31-fix-autosave-debounce`.
  - **Remote / agent sessions:** the Claude Code web/remote harness assigns a
    `claude/<description>-<id>` branch automatically; work on the branch it gives
    you. Don't rename it.
- **One PR = one coherent change** — usually one issue, sometimes a fix or a
  decision. Don't let a branch sprawl across unrelated concerns; that makes review
  and revert harder.

---

## The flow

```
branch  →  commit work  →  /open-pr  →  /checkpoint-review  →  address feedback  →  merge  →  delete branch
```

1. **Branch** off the current `main`, named for the issue it closes.
2. **Do the work** and commit in logical steps with clear messages. Keep building
   and running unit tests locally as you go.
3. **`/open-pr`** when the change is coherent enough to look at. It scaffolds the
   PR against `main`, writes the description from the diff + linked issue/ADR, and
   checks for a PR template. Opening a PR early (even "draft") is fine — it's a
   review surface, not a finish line.
4. **`/checkpoint-review`** at a reasonable checkpoint (see below). It runs the
   tripod review + line-level `/code-review` and consolidates the feedback onto
   the PR.
5. **Address feedback**, push follow-up commits to the same branch.
6. **Merge** to `main` (owner's call — the owner arbitrates). Delete the branch.

---

## Agent PR automation (owner-directed, standing)

Standing rules for how the agent drives the PR half of the loop, so the owner
isn't the bottleneck on ceremony. These **override** the agent's default "don't
open a PR unless asked" posture for this repo.

1. **Open the PR automatically — don't wait for owner input.** Once a change on a
   branch is coherent (work committed and pushed), the agent opens the PR against
   `main` itself (description from the diff + linked issue/ADR, honoring any PR
   template — i.e. `/open-pr`). Opening early / as draft is fine.

2. **Then stop — the agent does not watch CI.** After opening the PR the agent
   hands back. It does **not** poll, watch, subscribe to, or gate on CI, and it
   does **not** schedule check-back Routines for CI status. The **owner** owns the
   rest of the loop:
   - the owner **notifies the agent when a PR is merged** (the agent's cue to pick
     up the next piece of work), and
   - the owner **reports any CI / build errors back to the agent**, which then
     diagnoses and pushes a fix on request.

   This rule replaced an earlier "watch CI on a ~5-minute cadence" approach on the
   spike, which proved brittle: on the web/remote runner, runs that queued or never
   started left the agent looping on a status that never resolved. The owner is a
   faster, more reliable signal for both merge and failure than the agent watching
   a required check it can't influence anyway.

3. **This does not change the cloud-spend guardrails below.** The agent never
   *triggers* or reconfigures Xcode Cloud; CI runs are a consequence of the
   owner-configured PR/merge triggers. Auto-opening a PR is the one git event the
   agent performs without asking.

---

## Checkpoint review — who reviews what

We **do not** use a separate generic reviewer agent. Reviews reuse the tripod,
each on the dimension it already owns, plus the built-in `/code-review` skill for
mechanics. `/checkpoint-review` orchestrates this; you can also invoke any
reviewer by hand.

| Reviewer | Looks for |
|----------|-----------|
| **tech-lead** | Architecture fit, Swift/SwiftUI correctness, the seams, test coverage, iOS platform naivety. |
| **design-lead** | HIG conformance, native feel, navigation model, accessibility (Dynamic Type, VoiceOver, contrast). Only when the PR touches UI. |
| **product-lead** | Scope discipline: is this in v1, does it hold the **funnel-not-archive** principle (no drift toward organizing/browsing/history), and does it stay clear of the dropped **triage** stage? Also: has tagging crept into the capture path in a way that costs capture speed? |
| **`/code-review`** (built-in) | Line-level correctness, reuse, simplification, efficiency. Mechanical, not judgment. |

**When to run it.** Not every PR needs the full panel. Calibrate to the change:

- **Feature PR (closes a substantive issue)** → full tripod + `/code-review`.
  This is the real checkpoint.
- **UI-only tweak** → design-lead + `/code-review`.
- **Refactor / bug fix, no behavior change** → tech-lead + `/code-review`.
- **Docs / memory only** → skip the panel; a read-through is enough.

The reviews **advise**; the owner decides. Productive disagreement between the
personas is the point — a review where all three rubber-stamp adds no signal.

Review output lives as **PR comments**, not committed files. If a review surfaces
a real architectural decision, that becomes an ADR (next section) — not a buried
comment thread.

---

## Recording decisions — what rides with code, what goes first

Two rules, matching the project's "if it's a real decision, write it down" and
"ratify via ADR before relying on it" conventions:

- **ADR-first for real architectural decisions.** A decision that *gates* design
  or code (persistence engine, nav model, a new dependency) gets its **own small
  ADR PR** — proposed, ratified by the owner, merged — *before* the code that
  relies on it. This keeps the "should we do this?" conversation separate from
  "is the code right?", and gives the owner a clean ratification gate. A tiny ADR
  that only emerges mid-implementation can ride with the code, but anything the
  owner needs to weigh in on goes first.
- **Persona memory and issue specs ride *with* the code.** The tripod's
  `.claude/agent-memory/` notes and any `docs/specs/<issue>-*.md` land in the
  **same PR** as the code they describe. They document *why the code is the way
  it is*; separating them would make each PR less self-contained and force the
  reviewer to cross-reference two diffs.

Quick reference:

| Artifact | Where it lands |
|----------|----------------|
| Architectural decision (ADR) that gates code | **Its own PR, first** |
| Issue spec (`docs/specs/`) | Same PR as the issue's code |
| Persona memory (`.claude/agent-memory/`) | Same PR as the related code/decision |
| Review feedback | PR comments (→ ADR only if it's a real decision) |
| STATUS.md refresh (`/handoff`) | Its own small PR, or folded into the feature PR |

---

## Xcode Cloud (planned, not built)

Nothing is wired up in this repo yet. The spike ran two Xcode Cloud workflows and
the same shape is the expected target here, to be ratified by its own ADR before
setup:

- **`PR CI` — on Pull Request → `main`:** builds the app scheme and runs unit
  tests (~3 min). A **required status check** on `main`, so there's an automated
  *correctness* gate beside the tripod's *judgment* review.
- **`TestFlight` — on merge to `main`:** archives (Release) and distributes to
  TestFlight Internal Testing (~15–20 min). Docs/prose-only merges are skipped via
  a Files & Folders start condition.

**Repo pieces the spike needed** (carry over deliberately when the time comes): a
shared app scheme with its Test action limited to the unit-test target,
`ci_scripts/ci_post_clone.sh` (stamps a unique build number so TestFlight uploads
don't collide — **already carried over here**, inert until an Xcode project
exists), `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (export compliance),
and an app icon.

### Guardrails against overusing cloud build minutes

Cloud compute is a **finite, owner-managed quota** (25 compute-hours/month free).
To keep the agent from burning it:

- **The agent never triggers cloud builds directly.** They are a consequence of
  git events *the owner configured* in App Store Connect — the agent's job ends
  at "push branch / open PR." There is no agent action that spends a build minute.
- **Triggers never match WIP branches.** Only PR-to-`main` and merge-to-`main`.
  WIP pushes on `claude/*` / `issue-*` cost nothing.
- **The agent keeps iterating locally** — simulator build + unit tests. Cloud is
  for the device/TestFlight path the simulator can't cover, not the inner loop.
- **The agent must not reconfigure Xcode Cloud** (workflows, triggers, start
  conditions) without an explicit owner request. Changing a trigger can multiply
  spend silently.

---

## Command reference

| Command | Does |
|---------|------|
| `/open-pr` | Scaffold a PR from the current branch to `main`: description from the diff, link the issue/ADR (`Closes #N`), honor any PR template. |
| `/checkpoint-review` | Run the checkpoint review — the relevant tripod personas by dimension + built-in `/code-review` — and post consolidated feedback on the PR. |
| `/handoff` | Refresh `docs/STATUS.md` before switching sessions. |
| `/adr`, `/prd` | Scaffold an ADR / PRD via the tech-lead / product-lead. |
| `/code-review`, `/review` | Built-ins: review the working diff / review a GitHub PR. `/checkpoint-review` uses `/code-review` under the hood. |
