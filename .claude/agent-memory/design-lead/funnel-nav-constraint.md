---
name: funnel-nav-constraint
description: The "funnel not archive" principle is a navigation constraint — no browsable history of past notes anywhere in the app.
metadata:
  type: project
---

Treat "funnel, not archive" as a **navigation/UX constraint**, not just a
feature-list one. The single decision that turns capture tools into piles is making
*the list of notes* the home screen — Jackdaw must not.

**How to apply (design guardrails):**
- **Capture is home** (launch surface), not the inbox.
- **The only list of note *content* in the whole app is the un-triaged Triage
  inbox.** Everything downstream of a decision — kept/queued/exported notes, snoozed
  notes — is surfaced as **status and counts, not re-readable/re-organizable
  content.**
- **No "exported"/"recently sent"/history view, ever** (PRD non-goal). Confirmed
  notes are deleted and vanish.
- **No browsable "Snoozed" list** — snoozed notes are absent until due, then rejoin
  the inbox; acknowledged only as a count in the empty state.
- When any surface (e.g. the pending/failed export list) starts drifting toward
  browsable/organizable content, that's the line to defend. Keep it status, capped.

Related: [[nav-model]], [[snooze-model]], [[export-status-surfaces]].
