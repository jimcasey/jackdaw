---
name: nav-model
description: Jackdaw nav model — REVISED to Triage-root + Capture-as-sheet (no tab bar) after the two-tab model shipped a keyboard-vs-tab-bar defect on device. External capture is a proposal.
metadata:
  type: project
---

**REVISED (supersedes the earlier two-tab tab bar).** Status: the in-app change is
recommended outright; external-capture-primary is a proposal pending owner
ratification + tech-lead feasibility.

**Recommended in-app model:** **Triage is the root** (`NavigationStack` list of
un-triaged notes). **Capture is a modal sheet** (own keyboard, own `Done`/drag
dismiss) invoked from a prominent capture button on Triage. Settings/Status stays a
sheet from a gear. Note editor still a **push** within Triage. **No tab bar.**

**Why the change — the defect I own:** the original two-tab model launched keyboard-
up on a Capture *tab*; the always-up keyboard covered the iOS 26 floating tab bar
with no reachable dismiss. I had documented this as an acceptable "wrinkle" — on
hardware it was a trap. Root cause: persistent tab bar + persistent keyboard fighting
for the bottom edge. A sheet fixes it *by construction* (no tab bar underneath;
standard compose-sheet + keyboard; always a `Done`). Also better IA: if capture is a
quick action (esp. external), in-app capture is an *action* (button→sheet), not a
*mode* (tab).

**Launch destination — SHIPPED (A), capture-wave slice A / PR #41:** bare Triage
root; Capture sheet no longer auto-presents. Escape hatch stands: revert without
debate if in-app capture still dominates ~2 weeks after the Action button is
actually configured (capture-wave.md §7.1).

**Compose chrome (ratified in PR #41 review):** ONE affordance — bottom-docked,
full-width, labeled `.borderedProminent` button in a `safeAreaInset` on the stack
root. Nav-bar glyph removed; ratified (no duplicate chrome). Hides when the editor
pushes (intended — editor is a triage context). Inset stacking order: TriageRootView's
undo-banner/export-bar inset sits ABOVE the compose button (transient/residue chrome
above persistent primary chrome — correct, keep). **Naming rule:** root button says
**"Capture"** — "New note" is reserved for the in-sheet keyboard-toolbar delimiter
([[capture-model]]); never reuse one label for two different actions. Vocabulary
family: Capture (button) / "Capture Note" (App Shortcut) / "Capture a note in
Jackdaw" (Siri phrase). **Queued refinement (filed, not blocking):** iOS 26
Notes/Reminders/Journal put the primary action as a prominent glass glyph in a
bottom toolbar; migrate the whole bottom-chrome family (compose + export bar) to
that idiom in a polish pass after the flip survives its 2-week clock — the
full-width CTA is mildly web-shaped but consistent and ruling-conformant for now.

**§7.1 clause still owed to slice E:** any launcher surface that opens the app must
present the Capture sheet regardless of the flip flag — no deep-link path exists
yet, so the clause is unexercised; don't lose it.

**External capture (proposed):** one shared App Intent surfaced on Action button /
Siri / Control Center / Lock Screen. See [[external-capture]].

**Where I pushed back:** don't make external capture *primary* until (1) on-device
friction is validated and (2) tech-lead confirms an external intent can get a precise
GPS fix — else external captures degrade to timestamp-only, gutting the ambient-
context promise.

Full doc: `docs/design/navigation-and-screen-inventory.md` §2. Related:
[[funnel-nav-constraint]], [[capture-model]], [[external-capture]],
[[native-feel-risks]].
