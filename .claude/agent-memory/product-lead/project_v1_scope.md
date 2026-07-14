---
name: project_v1_scope
description: Jackdaw v1 MVP scope decisions and rationale — in-scope, non-goals, and the contested calls awaiting owner arbitration
metadata:
  type: project
---

v1 MVP scope lives in `docs/prd/mvp-scope.md`. Key decisions and *why*, so we
don't relitigate settled ground. Governing constraint: [[project_funnel-principle]].

**In scope (minimal set):** text-only capture; auto context = timestamp +
coarse location; offline capture queue; batch triage inbox with Discard /
Snooze / Keep-for-export; edit note text + context before keeping; export to
Obsidian markdown with YAML frontmatter; note leaves app after confirmed export.
Single user, single device, no account/sync.

**Contested scope calls I made (owner may overrule):**
- **Cut Apple Notes as a shipped destination.** Concept brief floated it as an
  easier MVP destination. Product position: zero user value (their vault is
  Obsidian) = throwaway work. Allowed only as a tech-lead de-risking *stub* in
  the walking skeleton, not a v1 feature. **Why:** MVP destination should be the
  one that delivers real value; Obsidian is the actual deliverable.
- **"Pluggable seams" are code hygiene, NOT a v1 feature.** v1 ships exactly one
  capture source, one context set, one destination. Internal boundaries fine;
  building/testing/UI for a plugin system, 2nd source, or 2nd destination is a
  non-goal. **Why:** guards against gold-plating an extension architecture with
  nothing to plug in. Expect tech-lead pushback (cheap-seams-now argument).
- **Leaning to cut Snooze from v1** (logged as open question). Adds a note state
  + reentry rules; unclear the owner needs it. **Why:** scope discipline; Discard
  /Keep may be enough.

**Non-goals (sharpest):** no browsing/search/history of exported notes; no
folders/tags/categories; no AI/auto triage; no share-sheet/quick-actions/
implicit capture; no photos/audio/voice/links (text only); no context beyond
time+location; no sync/backup/cloud; no markdown editor; no notifications.

**Open questions for owner:** retention model after export; Snooze session
definition (and whether to keep Snooze); Keep-for-export name (lean "Keep");
confirm context = time+location only; Obsidian write mechanism (tech-lead ADR,
blocking); coarse vs precise location.
