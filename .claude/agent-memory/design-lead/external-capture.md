---
name: external-capture
description: External quick-capture analysis — one shared App Intent across Action button/Siri/Control Center; only no-launch typed path is the system text-prompt overlay; location fidelity is the open gate.
metadata:
  type: project
---

Owner is considering moving *primary* capture OUTSIDE the app (lightweight popup via
Shortcut / Control Center / Siri / App Intents), with the app opening to Triage.
Design analysis:

**Hard platform reality for TEXT:** iOS widgets and Control Center controls are
buttons/toggles — **they cannot host a text field.** The only way to enter free text
*without fully launching the app* is the **system text-prompt overlay** an App Intent
shows via `requestValueDialog` (or Shortcuts "Ask for Input"), with
`openAppWhenRun = false`. Siri offers the same via **dictation**. Everything else can
only trigger the intent or deep-link to the Capture sheet.

**Build once, surface everywhere:** one App Intent (`CaptureNoteIntent`) powers
Action button, Siri, Control Center, Lock Screen, Back Tap, Shortcuts widget — the
iOS 26 "one intent, many surfaces" idiom. Near-free breadth once the intent exists
(argue *for* breadth vs. product-lead's scope-cut instinct).

**Friction ranking (typed):** 1) Action button (1 press → prompt; Pro-only HW),
2) Siri dictation (0 taps, voice-only, a11y win), 3) Control Center (swipe+tap;
text-prompt-from-control needs tech-lead verify, else deep-link to sheet), 4) Lock
Screen / Back Tap, 5) home-screen quick action / Shortcuts widget, 6) in-app Capture
sheet (reliable baseline; for *typed* capture plausibly not slower than the prompt).
Excluded: Share Sheet (PRD non-goal), text-entry widgets (impossible).

**THE GATE — RESOLVED (ADR 0005 / docs/feasibility/external-capture-precise-gps.md):**
a no-launch App Intent **cannot** get a GPS fix (platform rule; When-In-Use +
backgrounded = no updates without a foreground-asserted session). External no-launch
captures are **timestamp-only by design**. v1 shipped in-app only; external surfaces
are v1.x over the built `CaptureService` seam. Remaining tech-lead verify item:
whether a Control Center control can surface the text prompt itself (HIG says
controls "cannot capture complex input" → assume no; fallback = control opens the
Capture sheet, which is *better* for typed/contextful captures anyway — see
[[types-and-context]]).

Full doc: `docs/design/capture-and-triage-flows.md` §0. Related: [[nav-model]],
[[capture-model]], [[funnel-nav-constraint]].
