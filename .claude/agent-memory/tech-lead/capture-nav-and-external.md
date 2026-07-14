---
name: capture-nav-and-external
description: The 2026-07-14 capture-UX pivot — RATIFIED as ADR 0004 (nav flip to Triage-root + auto Capture sheet) and ADR 0005 (shared CaptureService seam; external capture DEFERRED ENTIRELY from v1). Hard finding: no-launch App Intent can't get precise GPS → external would be timestamp-only.
metadata:
  type: project
---

**Owner-ratified capture-UX pivot (2026-07-14), now RATIFIED IN ADRs.** ADR 0004 = nav flip; ADR 0005 = CaptureService seam + external DEFERRED. Feasibility research in `docs/feasibility/external-capture-precise-gps.md`; final v1 order in `docs/build-order.md`; nav in `docs/slices/slice-2-capture-swiftdata.md` §3.

**FINAL OWNER DECISIONS (2026-07-14): (1) external capture DEFERRED ENTIRELY from v1; (2) both ADRs written.**
- **ADR 0004 (Accepted)** `docs/adr/0004-navigation-triage-root-capture-sheet.md` — Triage=app root, Capture=modal sheet auto-presented on launch; supersedes the two-tab shell.
- **ADR 0005 (Accepted)** `docs/adr/0005-external-capture-service-seam.md` — build shared `CaptureService` in v1 (justified by IN-APP use), ship/validate NO external surface in v1; `CaptureNoteIntent` + all external surfaces = fast-follow v1.x. Driving consequence = the GPS gate below.

**FINAL v1 SLICE SEQUENCE:** 0 skeleton ✅ · 1 bookmark/T2 ✅ · **2** in-app Capture sheet + Triage-root + SwiftData (incl. `CaptureService` seam) ▶ · **3** real Triage · **4** Location (in-app precise GPS only) · **5** Apple Notes export · **6** Obsidian export (v1 complete). External-capture validation slice REMOVED → fast-follow. Location returned to its natural post-Triage spot (in-app only; no external dimension). `CaptureService` seam stays INSIDE Slice 2.

**FEASIBILITY GATE VERDICT — precise GPS from a no-launch App Intent = NO** (narrow, undependable yes-with-caveats). A `CaptureNoteIntent` with `openAppWhenRun=false` fired from the Action button while the app is NOT foregrounded cannot reliably get ANY location fix under When-In-Use.
- **Rule (WWDC24 "What's new in location authorization"):** Core Location does NOT deliver updates to a whenInUse app that is backgrounded unless a `CLBackgroundActivitySession`/LiveActivity is ALREADY in effect, and such a session can only be asserted while the app was in the FOREGROUND. Always-auth doesn't rescue it (Always is only effective via a session you can also only start in foreground). Real-world App-Intent report confirms timeouts when the app was force-quit/not recently run.
- **Product consequence (explicit):** EXTERNAL (no-launch) captures = **timestamp-only**, no location. IN-APP capture (the Capture sheet, foreground) keeps precise GPS via plain When-In-Use, unaffected — signature auto-context intact on the primary surface. Second independent reason external=timestamp-only: the intent's process may suspend the instant `perform()` returns, so no async backfill either.
- If location on external capture ever becomes essential: only reliable route is `openAppWhenRun=true` (briefly FOREGROUNDS the app to grab a fix — screen flashes; spike separately, NOT default). Cheaper: last-known-location cache (approximate). Neither is v1.
- **Validate the Action button around:** (1) no-launch capture→SwiftData round-trip via the shared seam, (2) clean timestamp-only degradation. Do NOT architect external capture around a live GPS fix.

**NAV FLIP (supersedes the ratified two-tab shell):** DROP two-tab `Capture|Triage`. **Triage = app root; Capture = modal sheet auto-presented on launch** (`RootView` shows `TriageRootView` with `.sheet(isPresented: $showCapture=true)` presenting `CaptureView`). User still lands ready to type; dismiss reveals Triage. Endgame: once external capture validated, STOP auto-presenting → bare Triage-root (one-line toggle). Wins: **fixes the keyboard-covers-floating-tab-bar bug BY CONSTRUCTION** (sheet owns its keyboard+dismiss); and "leaving Capture" = sheet `onDismiss` (single deterministic event) → **removes the earlier `.onDisappear`/tab-switch prune-trigger reliability risk**. Prune now fires on sheet onDismiss + scenePhase background.

**`CaptureNoteIntent` SEAM — one shared core, two front-ends:**
- `CaptureService` (the seam; imports NEITHER SwiftUI NOR AppIntents → off-device unit-testable): `insertNote(text:createdAt:in:)->Note`, `commit(text:in:)->Note` (one-shot), `attachLocation(to:)` (best-effort). Shared `Note` construction + SwiftData persistence.
- IN-APP front-end = `CaptureView`+`CaptureViewModel` LIVE-DRAFT autosave (lazy create/mutate/prune; async location backfill onto the live instance — app stays alive).
- EXTERNAL front-end = `CaptureNoteIntent` (`openAppWhenRun=false`) ONE-SHOT commit: text already complete → NO draft/autosave/prune. Text via `@Parameter` + `requestValueDialog` prompt on no-launch. Calls `CaptureService.commit` once → finished Note, timestamp-only.
- **ModelContext from the intent:** intent runs in the app process → use a SHARED `AppModelContainer.shared` (`static let`) used by BOTH `JackdawApp` (`.modelContainer(AppModelContainer.shared)`) and the intent — prefer this over App Intents `@Dependency` for the container to avoid cold-launch ordering issues.
- Deferred external surfaces (Action button, Shortcuts, Control Center, Siri, widget, Lock Screen) reuse the same intent/service with no new capture logic. ALL fast-follow v1.x.

**BUILT IN v1 (Slice 2):** the `CaptureService` seam ONLY, justified by IN-APP use (keeps SwiftData details in one testable place). `CaptureViewModel` calls it (`insertNote(text:in:)`, `prune(_:in:)`). **NOT built in v1:** the `CaptureNoteIntent` front-end, `@Parameter`/`requestValueDialog`, `AppModelContainer.shared`, any external surface — all fast-follow.

**ADRs WRITTEN (both Accepted 2026-07-14):** ADR 0004 (`docs/adr/0004-navigation-triage-root-capture-sheet.md`), ADR 0005 (`docs/adr/0005-external-capture-service-seam.md`). No separate GPS ADR (folded into 0005 as the driving consequence). All prior owner-decision-pending items are now RESOLVED.

See [[slice-2-spec]] (autosave capture, now sheet content), [[build-order]] (final v1 order 0–6), [[stack-recommendations]] (SwiftData).
