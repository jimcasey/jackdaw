---
name: project_v1_scope
description: Jackdaw v1 MVP scope — settled decisions, owner arbitrations (incl. overrides of product-lead), and downstream dependencies
metadata:
  type: project
---

v1 MVP scope lives in `docs/prd/mvp-scope.md`. Governing constraint:
[[project_funnel-principle]]. All open questions were arbitrated by the owner
on 2026-07-14; treat these as settled — do not relitigate.

**In scope (minimal set):** text-only capture; auto context = timestamp +
**precise GPS** location; offline capture queue; batch triage inbox with
Discard / Snooze / **Keep**; edit note text + context before keeping; export to
Obsidian markdown with YAML frontmatter; **hold-until-sync-confirmed** retention
(note deletes only after the Obsidian write is verified). Single user, single
device, no account/sync.

**Owner arbitrations that OVERRODE my recommendation:**
- **Snooze KEPT in v1** (I leaned to cut it). Owner sided with a real triage
  rhythm. The "what is a session / when do snoozed notes reappear" question is
  now a **design-lead** open question, not a scope question.
- **Location = PRECISE GPS** (I leaned coarse for privacy/permissions). Owner
  chose precise. Consequence: heavier permission ask + privacy surface that
  design-lead (permission rationale/flow) and tech-lead (entitlement + denied
  handling) must own.
- **Apple Notes = sanctioned intermediate build-order milestone** (I argued
  stub-only / near-zero value). Owner kept it as a real de-risking deliverable
  used before the Obsidian write is solved — but it is NOT a shipped v1
  destination. Shipped destination is Obsidian only.

**Owner arbitrations that upheld my position:**
- **Pluggable seams = clean internal boundaries only.** No plugin system, no
  config UI, no tests for hypothetical plugins.
- **Context set = time + location only** for v1.
- **Retention = hold until sync confirmed** (matched my recommendation).
- **Keep-for-export name = "Keep"** (my lean).

**Downstream dependencies created:**
- **Obsidian write mechanism = tech-lead ADR, BLOCKING** (share sheet /
  obsidian:// / synced folder / git commit). New hard requirement: the mechanism
  MUST be able to confirm a successful write, or hold-until-sync-confirmed is not
  implementable. Blocks export UX + retention.

**Non-goals (sharpest, unchanged):** no browsing/search/history of exported
notes; no folders/tags/categories; no AI/auto triage; no share-sheet/quick-
actions/implicit capture; no photos/audio/voice/links (text only); no context
beyond time+location; no sync/backup/cloud; no markdown editor; no notifications;
no Apple Notes as a shipped destination.
