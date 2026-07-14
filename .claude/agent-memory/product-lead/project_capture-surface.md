---
name: project_capture-surface
description: Ruling on external capture (App Intents/Control Center/Siri) and open-to-Triage vs. funnel principle; v1 capture-surface scope
metadata:
  type: project
---

**RATIFIED (2026-07-14).** Owner adopted the direction below after product +
design-lead evaluation. See [[project_v1_scope]] and [[project_funnel-principle]].

**Ratified launch model:** app **root is Triage**; the **Capture sheet
auto-presents on launch** (user still lands ready to type; dismissing reveals
Triage). Capture is a **presented modal sheet, not a tab/mode**. This is NOT
"Capture-first" (my earlier framing) and NOT "open onto the pile": funnel
invariant is that home is never a growing browsable library — Triage drains to
empty (a to-do list, not an archive).

**Ratified v1 capture surfaces:** required = in-app sheet. Build ONE shared
`CaptureNoteIntent` seam; validate a SINGLE external surface (**Action button**)
+ the **precise-GPS-from-intent feasibility gate** (tech-lead). All other
external surfaces (Control Center control, Siri-as-primary, widget, Lock Screen,
home-screen quick actions) are v1.x fast-follow. External capture does NOT gate
v1. Funnel non-goals (no browsing/search/history) kept — they keep the
Triage-root model honest.

---
Original evaluation reasoning (prompted by keyboard covering the floating tab
bar in the tab-based Slice 2 build):

**Ruling — open-to-Triage vs. funnel:** The launch destination is *downstream*
of the capture-surface decision, not independent. "Funnel not archive" is about
what the app retains/encourages (drive-to-zero processing), not which screen
loads first. Opening to Triage is compatible with the funnel **IF AND ONLY IF
external capture is a genuine, reliable, shipped primary path** — then the app
legitimately becomes the *processing* station and capture lives at the system
edge. If capture is still mostly in-app, launching to Triage demotes capture to
a second-class button behind the pile → archive-drift risk AND worse capture
friction. So: do not flip to Triage-first until external capture is actually the
shipped primary surface. For v1 (in-app capture primary), **keep Capture-first.**

**The keyboard/nav friction is a LAYOUT bug, not a launch-destination problem.**
Fix it by presenting Capture full-screen/modal (keyboard doesn't fight the tab
bar). Do not conflate "keyboard covers nav" with "we must open to Triage."

**v1 capture-surface scope:**
- REQUIRED v1: solid in-app capture, presented full-screen. Always-works path +
  walking-skeleton path.
- STRETCH v1 (only if tech-lead confirms genuinely low-cost): ONE App Intent for
  text capture surfaced via Shortcuts/Siri — no bespoke popup UI. App Intents is
  the foundation the Action button / Control Center / Siri all build on, so one
  clean intent yields many surfaces cheaply. Treat as stretch, not a gate.
- FAST-FOLLOW / v1.x: bespoke Control Center control, custom capture popup UI,
  Share Sheet ingest, widget, home-screen quick actions.

**External capture does NOT gate v1.** Ship in-app capture (keyboard fixed),
make external the #1 fast-follow. Rationale: the unproven risk is the
capture→triage→export-to-Obsidian *loop* and the deployment path (walking
skeleton), not capture friction. Friction is an optimization of a loop that must
first exist and be trusted. Guard against the owner's "add an extra hook before
v1" instinct — that is feature-creep on an unproven loop. Compromise held: keep
the capture path callable behind a clean App-Intent seam (consistent with the
"clean internal boundaries" ruling) so fast-follow is cheap, without building the
surfaces now.

**Dependency flagged:** Control Center controls need iOS 18; Action button needs
iOS 17+/specific hardware. Any external-capture commitment forces the still-open
min-iOS-target decision.

**Expected pushback:** design-lead likely favors launch-to-Triage + native
external triggers (App Intents/Control Center are native-UX catnip) and may want
a custom popup + Control Center control in v1. Tech-lead (held) likely: bare
text-param App Intent is cheap, but a UI-presenting popup / Control Center
control is not, and it forces min-iOS.
