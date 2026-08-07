---
name: pr16-learnings-review
description: Product-lead scope review of PR #16 (prototype-learnings doc) — verdict fix-then-ship, findings raised, and the evidence bounds behind them
metadata:
  type: project
---

Reviewed PR #16 (fills `docs/prototype-learnings.md`, closes #1) on 2026-08-06.
Verdict: **fix-then-ship** — no verdict reintroduces triage or organizing/browsing;
all findings were framing fixes, not scope violations.

**Why:** the doc will be cited as evidence by #2–#6, so framing precision is
load-bearing — a "must" written today becomes settled ground tomorrow.

**How to apply:** don't re-raise these once the owner resolves the PR; do hold
the downstream issues to the bounds below.

Positions I took (hold these consistently):
- **Junk-filter evidence is bounded**: ~3 weeks, one user, 5–15 captures/week,
  inbox never faced a pile. "Keep-everything + vault stayed clean" supports the
  triage cut but is "consistent with," not proof junk doesn't exist. The cut's
  real justification is the owner's workflow rationale (destination edits, AI
  sorts later) — the field data corroborates, it doesn't carry the decision.
- **#4 (export) must stay genuinely open**: the spike's retention lessons
  (confirmation requirement, state-vs-reason, poison note) enter as evidence,
  not constraints. "State vs reason must stay separate fields" presumes
  persisted failure state exists — that's #4's call under the simplicity rule.
  Per-note "Retry" vocabulary is banned by CLAUDE.md §Simplicity rule.
- **Capture-model promote is coupled to #6 (persistence)**: the promoted
  implementation posture (SwiftData main-context autosave coalescing) presumes
  SwiftData while #6 re-opens it. The UX invariants (autosave, lazy create,
  prune, fresh-note re-entry) are persistence-agnostic and genuinely settled
  (autosave was an explicit owner override — don't relitigate).
- **§8 external-surface lean endorsed on product grounds**: in-app + Siri seam,
  further surfaces earn their way via demonstrated pull. Action button failed
  its own two-week adoption experiment. But "intent seam is nearly free" is a
  tech-lead feasibility claim, not usage evidence — priced by tech-lead, not
  inherited.
- **Evidence gap flagged**: §1 doesn't record which export destination saw real
  field use (Obsidian did, via the toast; Apple Notes path apparently unused).
  #4's destination decision should have that datum.
