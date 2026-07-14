---
name: snooze-model
description: Snooze-session model — snoozed notes reappear next calendar day, hidden for the current sitting, never browsable, with an anti-graveyard count nudge.
metadata:
  type: project
---

Design-lead's proposed snooze-session model (design-lead owns this per PRD;
product-lead wanted Snooze cut, owner kept it — so it must resist becoming an
infinite-deferral graveyard).

**The model:**
- A triage **session = one sitting** (no visible "start session" button).
- Snoozing hides a note **for the rest of the current sitting** (anti-churn guard).
- Snoozed notes **reappear at the first Triage open on a later calendar day** than
  they were snoozed. Simple, predictable, "sleep on it."
- Snoozed notes are **never browsable** — no folder to rummage; only a count-only
  line in the empty state ("3 will return in a later session").
- Snoozed notes **don't count in the Triage tab badge** until due (badge =
  actionable-now).
- **Anti-graveyard:** track snoozeCount; after ~3× surface it on the row ("snoozed
  3×") to nudge a decision. Surface, don't hard-disable (hard-disable forces a
  rushed keep/kill).

**Why calendar-day over alternatives:** "next open" too soon/muddy (launch =
Capture); "manual start session" adds a mode/tap. Calendar-day is simplest,
predictable, resists same-sitting churn.

**[ASSUMPTION]** local time zone; midnight edge case negligible for single user.
Drop-in refinement if it grates: "next 4am boundary or ≥6h, whichever later."

**Push-back expected:** product-lead may want the count-nudge cut — deferred to
owner. Full doc: `docs/design/open-ux-threads.md` (Thread 1). Related:
[[funnel-nav-constraint]].
