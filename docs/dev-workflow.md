# Development workflow — PRs & reviews

How changes land in Jackdaw. The short version: **work on a branch, open a PR,
review at checkpoints, merge to `main`.** `main` is protected by convention — we
don't push straight to it anymore.

This doc is the canonical reference; `CLAUDE.md` links here. The commands
`/open-pr` and `/checkpoint-review` automate the ceremony.

---

## Why PRs at all (for a single-owner project)

Jackdaw is one owner plus the tripod (product-lead, design-lead, tech-lead). PRs
aren't about gatekeeping a team — they buy three things a solo project still
wants:

1. **A review surface.** A diff the tripod can critique as a unit, before it's
   permanent, instead of after-the-fact archaeology on `main`.
2. **A checkpoint.** A named boundary ("Slice 6 export") where we stop and ask
   *is this right?* rather than letting slices blur together.
3. **A revert seam.** A merge commit is a clean undo point if a slice goes wrong.

The cost is ceremony. We keep it low: thin commands, docs that ride with code,
and no build gate the owner has to babysit (see Xcode Cloud, below, for when
that changes).

---

## Branching model

- **`main`** is the trunk. It should always build and pass unit tests. Merge into
  it via PR; don't push to it directly.
- **Feature branches** are short-lived and descriptive. Two flavors:
  - **Owner / local work:** name for the slice or change, e.g.
    `slice-6-apple-notes-export`, `fix-snooze-boundary`.
  - **Remote / agent sessions:** the Claude Code web/remote harness assigns a
    `claude/<description>-<id>` branch automatically; work on the branch it gives
    you. Don't rename it.
- **One PR = one coherent change** — a slice, a fix, or a decision. Don't let a
  branch sprawl across unrelated concerns; that makes review and revert harder.

---

## The flow

```
branch  →  commit work  →  /open-pr  →  /checkpoint-review  →  address feedback  →  merge  →  delete branch
```

1. **Branch** off the current `main`.
2. **Do the work** and commit in logical steps with clear messages. Keep building
   and running unit tests locally as you go (the simulator recipe in
   `docs/STATUS.md` is unchanged).
3. **`/open-pr`** when the change is coherent enough to look at. It scaffolds the
   PR against `main`, writes the description from the diff + linked slice/ADR, and
   checks for a PR template. Opening a PR early (even "draft") is fine — it's a
   review surface, not a finish line.
4. **`/checkpoint-review`** at a reasonable checkpoint (see below). It runs the
   tripod review + line-level `/code-review` and consolidates the feedback onto
   the PR.
5. **Address feedback**, push follow-up commits to the same branch.
6. **Merge** to `main` (owner's call — the owner arbitrates). Delete the branch.

---

## Agent PR automation (owner-directed 2026-07-21, revised 2026-07-23)

Standing rules for how the agent drives the PR half of the loop, so the owner
isn't the bottleneck on ceremony. These **override** the agent's default "don't
open a PR unless asked" posture for this repo.

1. **Open the PR automatically — don't wait for owner input.** Once a change on a
   branch is coherent (work committed and pushed), the agent opens the PR against
   `main` itself (description from the diff + linked slice/ADR, honoring any PR
   template — i.e. `/open-pr`). Opening early / as draft is fine.

2. **Then stop — the agent does not watch `PR CI`.** After opening the PR the agent
   hands back. It does **not** poll, watch, subscribe to, or gate on `PR CI`, and it
   does **not** schedule check-back Routines for CI status. The **owner** owns the
   rest of the loop:
   - the owner **notifies the agent when a PR is merged** (the agent's cue to pick up
     the next piece of work), and
   - the owner **reports any CI / build errors back to the agent**, which then
     diagnoses and pushes a fix on request.

   This **replaces** the earlier "watch `PR CI` on a ~5-minute durable-Routine
   cadence, act on the color" rule (**retired 2026-07-23**). On the web/remote runner
   that polling proved brittle — runs that queued or never started left the agent
   looping on a status that never resolved — and the owner is a faster, more reliable
   signal for both merge and failure than the agent watching a required check it
   can't influence anyway.

3. **This does not change the cloud-spend guardrails below.** The agent still never
   *triggers* or reconfigures Xcode Cloud; CI runs are a consequence of the
   owner-configured PR/merge triggers. Auto-opening a PR is the one git event the
   agent performs without asking — it costs the one `PR CI` run that a PR was always
   going to cost.

> **Note on the `PR CI` required status check (infrastructure, owner-managed).**
> Whether `PR CI` remains a *required* status check on `main` lives in **GitHub
> branch protection + App Store Connect (Xcode Cloud)**, not in this repo — the agent
> can't change it. Removing the agent's watching of CI (above) does **not** remove
> that gate; if the owner wants `main` to accept merges with no check at all, that's a
> branch-protection / Xcode Cloud settings change the owner makes directly.

---

## Checkpoint review — who reviews what

We **do not** use a separate generic reviewer agent. Reviews reuse the tripod,
each on the dimension it already owns, plus the built-in `/code-review` skill for
mechanics. `/checkpoint-review` orchestrates this; you can also invoke any
reviewer by hand.

| Reviewer | Looks for |
|----------|-----------|
| **tech-lead** | Architecture fit, Swift/SwiftUI correctness, the seams (e.g. `ExportDestination`), test coverage, iOS platform naivety. |
| **design-lead** | HIG conformance, native feel, navigation model, accessibility (Dynamic Type, VoiceOver, contrast). Only when the PR touches UI. |
| **product-lead** | Scope discipline and the **funnel-not-archive** principle — does this creep toward organizing/browsing? Is it in v1? |
| **`/code-review`** (built-in) | Line-level correctness, reuse, simplification, efficiency. Mechanical, not judgment. |

**When to run it.** Not every PR needs the full panel. Calibrate to the change:

- **Slice / feature PR** → full tripod + `/code-review`. This is the real
  checkpoint.
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
- **Persona memory and slice specs ride *with* the code.** The tripod's
  `.claude/agent-memory/` notes and the `docs/slices/slice-N-*.md` spec for a
  slice land in the **same PR** as the code they describe. They document *why the
  code is the way it is*; separating them would make each PR less self-contained
  and force the reviewer to cross-reference two diffs.

Quick reference:

| Artifact | Where it lands |
|----------|----------------|
| Architectural decision (ADR) that gates code | **Its own PR, first** |
| Slice spec (`docs/slices/`) | Same PR as the slice's code |
| Persona memory (`.claude/agent-memory/`) | Same PR as the related code/decision |
| Review feedback | PR comments (→ ADR only if it's a real decision) |
| STATUS.md refresh (`/handoff`) | Its own small PR, or folded into the slice PR |

---

## Xcode Cloud (active)

Live since ADR 0006 (Accepted). Xcode Cloud is Apple's CI: it builds, tests, and
distributes to TestFlight on git triggers configured in App Store Connect. Two
workflows, each a distinct gate. Full setup + owner runbook:
`docs/ci/xcode-cloud-setup.md`.

- **`PR CI` — on Pull Request → `main`:** builds the `Jackdaw` scheme and runs
  **`JackdawTests`** (unit only — the scheme's Test action excludes UI tests).
  ~3 min. It is a **required status check** on `main`, so it's an automated
  *correctness* gate beside the tripod's *judgment* review — no PR merges red.
- **`TestFlight` — on merge to `main`:** archives (Release) and distributes to
  **TestFlight Internal Testing** (owner's device). Every **code** merge (ADR 0006
  Decision 1), ~15–20 min; docs/prose-only merges (`docs/`, `.claude/`, `CLAUDE.md`)
  are skipped via a Files & Folders start condition — see the runbook. Cloud-managed
  signing handles the distribution cert.

**Repo pieces that make this work** (all landed via PR): the shared `Jackdaw`
scheme (`.xcscheme`, Test action = `JackdawTests` only), `ci_scripts/ci_post_clone.sh`
(stamps a unique build number so TestFlight uploads don't collide),
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (export compliance), and the
app icon. No `ci_scripts` beyond the build-number step — the project has no
external dependencies to resolve.

### Guardrails against overusing cloud build minutes

Cloud compute is a **finite, owner-managed quota** (25 compute-hours/month free;
real usage ≈ a few hours). To keep the agent from burning it:

- **The agent never triggers cloud builds directly.** They are a consequence of
  git events *the owner configured* in App Store Connect — the agent's job ends
  at "push branch / open PR." There is no agent action that spends a build minute.
- **Triggers never match WIP branches.** Only PR-to-`main` (`PR CI`) and
  merge-to-`main` (`TestFlight`). WIP pushes on `claude/*` / `slice-*` cost nothing.
- **The agent keeps iterating locally** — simulator build + unit tests, exactly
  as today. Cloud is for the device/TestFlight path the simulator can't cover,
  not the inner loop.
- **The agent must not reconfigure Xcode Cloud** (workflows, triggers, start
  conditions) without an explicit owner request. Changing a trigger can multiply
  spend silently.

---

## Command reference

| Command | Does |
|---------|------|
| `/open-pr` | Scaffold a PR from the current branch to `main`: description from the diff, link the slice/ADR, honor any PR template. |
| `/checkpoint-review` | Run the checkpoint review — the relevant tripod personas by dimension + built-in `/code-review` — and post consolidated feedback on the PR. |
| `/handoff` | Refresh `docs/STATUS.md` before switching sessions (unchanged; now push the branch + open a PR rather than pushing `main`). |
| `/adr`, `/prd` | Scaffold an ADR / PRD via the tech-lead / product-lead (unchanged). |
| `/code-review`, `/review` | Built-ins: review the working diff / review a GitHub PR. `/checkpoint-review` uses `/code-review` under the hood. |
