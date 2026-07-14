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

**THE OPEN GATE (design position):** an App Intent running outside the foreground app
may not get a precise GPS fix → external captures could be **timestamp-only**, which
guts the "context attached automatically" promise. **Do NOT commit to external-
primary until tech-lead confirms location is obtainable AND on-device friction is
validated.** Tech-lead feasibility items: (1) no-launch text-capture intent; (2)
location from extension/background; (3) whether a Control Center control can surface
the text prompt itself.

Full doc: `docs/design/capture-and-triage-flows.md` §0. Related: [[nav-model]],
[[capture-model]], [[funnel-nav-constraint]].
