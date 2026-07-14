---
name: capture-model
description: Capture is autosave-as-you-type (owner-confirmed, overrides explicit-save) — no Save button; "New note" delimits thoughts; prune-on-abandon; Capture never resumes a note.
metadata:
  type: project
---

**Owner-confirmed capture model (overrides the earlier explicit-save/compose-then-
commit flow).** Rationale: losing a fleeting thought is the worst failure for a
quick-capture funnel; autosave makes it structurally impossible.

- **Field always live, autosave-as-you-type, NO Save/Done button.** Every keystroke
  persists.
- **Lazy creation:** note exists on the **first non-whitespace character** (not on
  opening Capture).
- **Prune-on-abandon:** empty/whitespace note is discarded **when the user leaves
  Capture** — now = **dismissing the Capture sheet** (drag/`Done`) / background /
  close / end of an external-intent prompt with no text. Clearing the field while
  the sheet stays open does NOT prune — typing again continues the same note; pruned
  only if you then dismiss empty. Tapping New note on an empty field is a no-op.

**Presentation (revised): in-app Capture is a modal SHEET, not a tab** (own keyboard,
own `Done`/drag dismiss) — this fixed the keyboard-vs-tab-bar defect; see
[[nav-model]]. Autosave rules unchanged; "leaving Capture" = dismissing the sheet.
Capture may also be triggered externally (App Intent) — see [[external-capture]].
Dismiss needs no "discard changes?" prompt (autosave = never unsaved data).

**The "start the next thought" moment (design owns this — the key UX autosave
creates):**
- **Exit A (leaving Capture) = the commit.** Leave with content → it's in the Triage
  inbox. No action needed.
- **Exit B (capture another now) = an explicit "New note" action** (NOT a save — the
  note is already saved; it means "bank this, give me a fresh field"). Lives in a
  **keyboard toolbar / input accessory** (thumb-reachable, keyboard stays up), with a
  light haptic + brief "Captured" micro-confirmation. Disabled/absent when field
  empty; its appearance doubles as the ambient "you've captured something" signal.
- **Re-entry rule (funnel discipline): Capture always opens a FRESH empty note; it
  never resumes a prior note.** Continuing to edit a captured note happens in
  Triage, not Capture. This is the line that stops Capture drifting into an
  editor/notepad.

**No per-keystroke "saved" indicator** (web-app noise + VoiceOver spam). Optional
subtle static "Saved" label is tunable polish, not core. Pruning is silent.

**Only content-destroying paths in the app: Discard (Triage) + confirmed-export-
delete.** Prune only ever removes empties.

**Tech-lead alignment (Slice 2, parallel):** persist a note the instant it has
content, before a GPS fix, backfill location async (`location: pending` is steady
state now). Prune triggers above are the UX definition to match.

**Impact on the discard-undo fork (Slice 4):** autosave means every Triage row is a
real persisted thought → a mis-tapped Discard destroys real data → **strengthens the
undo-banner case** (making capture-loss impossible while leaving triage-discard
one-tap-unrecoverable is inconsistent). Not resolved — still owner's call at Slice 4.

Full doc: `docs/design/capture-and-triage-flows.md` §1. Related:
[[funnel-nav-constraint]], [[nav-model]], [[a11y-baseline]], [[native-feel-risks]].
