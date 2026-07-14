---
name: export-status-surfaces
description: Pending/failed export + vault re-grant surfaces — status-not-content, quiet pending, loud only on failed/access-lost; shared failure-reason seam with tech-lead.
metadata:
  type: project
---

How Jackdaw surfaces the retention model ("hold until sync confirmed" → notes sit
`pending`/`failed`) and stale-bookmark recovery, without becoming an archive.

**Design line: status + counts, not re-readable content.**
- Kept notes leave the Triage inbox immediately (Keep feels "handled").
- Primary surface = **Settings & Status sheet**: "Export: 2 pending · 1 failed."
- **Pending (offline) is normal/calm — no loud badge**; auto-flushes.
- **Loud only for `failed` / access-lost** (actionable): subtle Triage nav-bar
  indicator + Retry / Re-grant in the sheet.
- Optional capped per-note list: truncated first line + state + time + Retry +
  "Return to inbox." No bodies, no edit-in-place, no search/sort. Self-empties.
- **Re-grant recovery** (stale security-scoped bookmark): non-blocking Triage banner
  + Settings row → reopens the document picker; never interrupts Capture; framed as
  routine re-confirmation, not user error. No data loss (notes stay queued).

**Shared build seam with tech-lead (name it):** Talon / retention state machine must
expose per queued note: state (`pending/writing/failed/confirmed`), **failure reason
(offline vs access-lost vs write-error)** — drives Retry vs Re-grant, count by
state, retry trigger, return-to-inbox transition.

**Push-back expected:** product-lead may call the per-note list archive-adjacent;
fallback = counts-only, as long as failed notes still route back to the inbox.

Full doc: `docs/design/open-ux-threads.md` (Threads 3 & 4). Related:
[[funnel-nav-constraint]], [[nav-model]].
