# ADR 0004 — Navigation model: Triage-root + auto-presented Capture sheet

> **Status:** Accepted — app root is **Triage**; **Capture** is a modal sheet
> auto-presented on launch. **Supersedes** the two-tab `Capture | Triage` shell
> previously ratified in `docs/design/navigation-and-screen-inventory.md` §2.
> **Date:** 2026-07-14
> **Owner of decision:** design-lead + product-lead, feasibility-checked by
> tech-lead, arbitrated by owner.

## Context

The v1 navigation was previously ratified as a **two-tab tab bar** (`Capture` /
`Triage`), with Capture as the launch tab and the keyboard raised so the user lands
ready to type (design nav doc §2; design capture flow §1).

That design carried a known wrinkle, documented at the time as "one honest
wrinkle": at launch the keyboard is up on Capture, and iOS 26 renders the tab bar
as a **floating "Liquid Glass" surface** that sits **behind the keyboard**. On
device this proved worse than "honest": with the keyboard up and no obvious
dismiss affordance, the floating tab bar is **covered and untappable** — the user
cannot leave Capture for Triage without first knowing to swipe the keyboard down.
For an app whose entire first-run promise is "land ready to type," forcing a
keyboard-dismissal discovery step just to reach the other half of the app is a real
friction and discoverability defect.

Product and design reconsidered the information architecture in light of this and
of the funnel principle. The tab bar implies **two co-equal modes**. But Jackdaw's
governing principle is *Capture → Triage → Export as a funnel*: **capture is an
action you take, not a place you dwell**, and Triage is the one surface that holds
content. Modeling Capture as a peer "mode" over-weights it and invites the app to
open *onto* a persistent Capture screen rather than treating capture as a quick,
dismissible act.

A separate constraint reinforced the change: prune-on-abandon for the autosave
capture model (Slice 2′) needs a reliable "user left Capture" signal. Under the tab
bar that signal was `TabView` `.onDisappear` on tab switch, whose timing is
historically unreliable — a flagged risk.

## Decision

**The app root is `Triage`. `Capture` is a modal sheet that auto-presents on
launch.** Dismissing the sheet (swipe-down / Cancel) reveals the Triage root; the
user still lands ready to type because the sheet is presented immediately.

- `RootView` renders `TriageRootView` and presents `CaptureView` via
  `.sheet(isPresented:)`, initialized to present on launch.
- **Post-v1 endgame:** once external capture surfaces exist to seed the inbox
  (fast-follow — see ADR 0005), **stop auto-presenting** the sheet so the app opens
  to a bare Triage root and Capture is reached deliberately (a gear/compose
  affordance). This is a single-flag change; the auto-present boolean is the one
  source of truth.

This supersedes the two-tab shell. The Settings/Status surface remains a **sheet**
(unchanged from the nav doc); the app now has **no tab bar**.

## Consequences

**Positive**
- **Fixes the keyboard/tab-bar defect by construction.** A sheet owns its own
  keyboard and its own dismissal; there is no floating tab bar to be occluded and
  no "dismiss the keyboard to reveal the chrome" discovery step. The bug cannot
  recur under this model.
- **Eliminates the `.onDisappear` prune-reliability risk.** "Leaving Capture" is now
  the sheet's single, deterministic **`onDismiss`** callback (plus `scenePhase`
  background), which is exactly the signal the autosave prune-on-abandon needs — far
  more reliable than `TabView` tab-switch `.onDisappear`. (See Slice 2′ in
  `docs/build-order.md` and `docs/slices/slice-2-capture-swiftdata.md` §3–4.)
- **Better IA for the funnel.** Capture reads as an **action** (a sheet you invoke
  and dismiss), not a co-equal **mode**. The app opens onto Triage — the one place
  with content and the place the funnel wants the user to clear — while still
  landing ready to type on launch.
- **Simpler component set:** no tab bar to style/maintain; capture and its keyboard
  are self-contained.

**Negative / accepted**
- Reverses previously-ratified ground (the two-tab decision). Recorded here so the
  personas do not relitigate it; the design nav/capture docs are updated to match.
- A modally-presented Capture is slightly less "always one tap away" than a
  permanent tab while the app is open (you re-present the sheet rather than tapping a
  tab). Accepted: launch auto-presents it, and a compose affordance on the Triage
  root covers re-invocation — capture remains a one-tap action.

## Related
- Supersedes: `docs/design/navigation-and-screen-inventory.md` §2 (two-tab shell);
  design capture flow `docs/design/capture-and-triage-flows.md` §1.
- ADR 0005 (external capture seam; the deferred external surfaces are what enable
  the "stop auto-presenting" endgame).
- Build order Slice 2′: `docs/build-order.md`; spec:
  `docs/slices/slice-2-capture-swiftdata.md` §3.
- Feasibility context: `docs/feasibility/external-capture-precise-gps.md`.
