# Feasibility: precise GPS from a no-launch App Intent + the `CaptureNoteIntent` seam

> **Status:** Tech-lead feasibility finding for owner. **Date:** 2026-07-14.
> **Triggered by:** owner-ratified capture-UX pivot (Triage-root + auto-presented
> Capture sheet; one shared `CaptureNoteIntent`; validate the Action button as the
> single external surface; external capture does **not** gate v1).
> **Companion:** revised slice order in `docs/build-order.md`; nav change reflected
> in `docs/slices/slice-2-capture-swiftdata.md` §3.

---

## 1. THE FEASIBILITY GATE — can a no-launch App Intent get a precise GPS fix?

### Verdict: **NO for the real no-launch case** (narrow, undependable yes-with-caveats).

A `CaptureNoteIntent` with `openAppWhenRun = false`, fired from the Action button
while Jackdaw is **not foregrounded**, **cannot reliably obtain a GPS fix at all**
(precise or coarse) under **When-In-Use** authorization. This is a platform rule,
not a tuning problem.

### Why — the load-bearing platform rule

From Apple's WWDC24 *"What's new in location authorization"*: Core Location **does
not deliver updates to a When-In-Use app that is backgrounded** unless a
`CLBackgroundActivitySession` (or a Live Activity) **is already in effect**, and
that session must have been asserted **while the app was in the foreground**:

- *"Core Location does not generate or deliver updates for which an app is not
  authorized, for example due to having `.whenInUse` authorization, and being
  backgrounded without a LiveActivity or `CLBackgroundActivitySession` in effect."*
- *"`liveUpdates` and `CLMonitor.events` won't yield results when it is not in use,
  unless a session which was started **in the foreground**, or while another one
  was in effect, asserts that continued interest."*
- Even upgrading to **Always** does not rescue the cold case: *"Always authorization
  will only be effective when you hold one of these [sessions], and you can only
  start holding one when your app is in the foreground."*
  ([WWDC24 — location authorization](https://developer.apple.com/videos/play/wwdc2024/10212/))

A no-launch App Intent invocation is, by definition, a **background execution** of
an app that was not foregrounded (often terminated). There is no
foreground-established session in effect, so Core Location has nothing to deliver.
This is corroborated by a real-world App-Intent report: location **works in the
foreground but times out when the app was force-quit or not run recently**, even
with `allowsBackgroundLocationUpdates = true` — the delegate never fires.
([Apple forum — Core Location in App Intent](https://developer.apple.com/forums/thread/737733),
[openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun),
[CLBackgroundActivitySession](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3))

### The narrow "yes-with-caveats" (do not depend on it)

If the app happens to be **warm** (recently foreground) **and** is already holding a
`CLBackgroundActivitySession`, a fix may be obtainable for a limited window. We
cannot rely on that state for a capture-anytime feature — the whole point of
external capture is that it works when the app is *not* open. Requiring **Always**
authorization is both insufficient (same cold-launch limitation) and a badly
oversized privacy ask for a note app. Neither is worth pursuing for v1.

### Product implication — stated explicitly

- **External (no-launch) captures degrade to timestamp-only.** They cannot carry
  the product's signature precise-GPS auto-context. The note is committed with a
  capture **timestamp** and **no location**; the user can add/correct location
  later at triage (the note editor already supports editing/clearing location per
  the design flow).
- **In-app capture is unaffected.** The Capture sheet runs in the **foreground**,
  where plain **When-In-Use** gives precise GPS normally. So the signature
  auto-context is fully intact on the **primary** capture surface — only the
  fast-follow external surfaces lose live location.
- **If location on external capture is later deemed essential**, the only reliable
  route is an `openAppWhenRun = true` variant that **briefly foregrounds** the app
  to grab a fix — a UX tradeoff (the screen flashes to Jackdaw) to spike
  separately, not the default. A secondary, cheaper option is a **last-known-location
  cache** (stamp external notes with the most recent foreground fix, clearly marked
  approximate) — an enhancement, not v1.

### What this means for the "validate one surface (Action button)" plan

Validate the Action button around what is actually provable and valuable:
1. **The no-launch capture → SwiftData round-trip** through the shared seam (this
   is the real thing to retire).
2. **Graceful degradation to timestamp-only** location — confirm the note commits
   cleanly with no location and surfaces in Triage.
Do **not** architect external capture around a live GPS fix. Treat "external note
has no location" as the expected, designed behavior.

---

## 2. The `CaptureNoteIntent` seam architecture

**One shared capture core; two front-ends.** Both the in-app Capture sheet and the
external App Intent funnel into a single persistence primitive, so the SwiftData
write, `id`/`createdAt` stamping, and (where available) location attachment are
identical. What differs is only the **input-collection lifecycle**.

```
        In-app front-end                     External front-end
   ┌────────────────────────┐          ┌───────────────────────────┐
   │ CaptureView (sheet)     │          │ CaptureNoteIntent          │
   │  + CaptureViewModel      │          │  openAppWhenRun = false    │
   │  live autosave draft:    │          │  @Parameter text +         │
   │  edit()/finishEditing()  │          │  requestValueDialog prompt │
   └───────────┬─────────────┘          └──────────────┬────────────┘
               │ (lazy create + mutate + prune)         │ (one-shot commit)
               ▼                                         ▼
        ┌──────────────────────────────────────────────────────┐
        │ CaptureService  (the seam — no SwiftUI, no AppIntents) │
        │  • insertNote(text:createdAt:in:) -> Note              │
        │  • commit(text:in:) -> Note        (one-shot)          │
        │  • attachLocation(to:)             (best-effort async) │
        └───────────────────────┬──────────────────────────────┘
                                 ▼
                    shared SwiftData ModelContainer
                     (AppModelContainer.shared)
```

**Reconciling the two lifecycles (the key reconciliation with autosave):**
- **In-app = live draft.** `CaptureViewModel` keeps its autosave model: lazy row
  creation on first non-whitespace keystroke, mutate-in-place, prune-on-abandon.
  It builds the `Note` incrementally and can **async-backfill** location onto the
  live instance because the app/sheet stays alive.
- **External = one-shot commit.** `CaptureNoteIntent.perform()` already has the
  *complete* text, so there is **no draft, no autosave, no pruning**. It calls
  `CaptureService.commit(text:in:)` once, which inserts a **finished** `Note` and
  saves. **No async location backfill** for external — the intent's process may be
  suspended the instant `perform()` returns, so any location must be obtained
  synchronously within the intent, which (per §1) yields nothing on no-launch →
  timestamp-only. This is the second, independent reason external = timestamp-only.
- Both paths share `insertNote(...)` so a note created externally is
  indistinguishable in the store from one created in-app (same fields, same Triage
  handling).

**Intent mechanics:**
- `static var openAppWhenRun = false` — stay in context, no app launch (the whole
  point of the Action button). This is exactly the mode that forfeits GPS (§1).
- **Text input on no-launch:** declare `@Parameter var text: String`; when invoked
  without a value, App Intents prompts for it via the system Shortcuts/Action-button
  UI using the parameter's `requestValueDialog` (e.g. *"What's on your mind?"*). The
  user dictates/types; `perform()` receives the resolved string.
- **ModelContext access from the intent:** the intent runs in the app's process, so
  it uses a **shared `ModelContainer`**. Recommend a single
  `AppModelContainer.shared` (a `static let` container built once) used by **both**
  `JackdawApp` (`.modelContainer(AppModelContainer.shared)`) and the intent —
  rather than App Intents' `@Dependency` for the container, to avoid cold-launch
  ordering questions (a static lazy container has no dependence on app-launch
  registration timing).
- `perform()` returns a lightweight confirmation (`.result(dialog: "Captured.")`).

**Clean-seam properties:** `CaptureService` imports neither SwiftUI nor AppIntents,
so it is unit-testable off-device against an in-memory `ModelContext` (same harness
as Slice 2). The intent and the view are thin adapters over it. This keeps external
capture a *swappable front-end*, consistent with the PRD's "clean internal
boundaries only" stance, and lets the deferred surfaces (Control Center, Siri,
widget, Lock Screen) reuse the same `CaptureNoteIntent`/`CaptureService` with no new
capture logic.

---

## 3. ADR recommendations

Two decisions here reverse or extend previously-ratified ground and should be
recorded so the personas don't relitigate. **Recommend writing both; not written
yet** (flagging per instruction):

- **ADR 0004 — Navigation model: Triage-root + auto-presented Capture sheet
  (supersedes the two-tab shell).** This **reverses** the ratified two-tab
  `Capture | Triage` decision (design nav doc §2, build-order). One decision per
  file → it deserves its own ADR, noting the by-construction fix of the
  keyboard-covers-tab-bar bug and the "stop auto-presenting once external capture
  is validated → bare Triage-root" endgame.
- **ADR 0005 — External capture via the shared `CaptureNoteIntent` seam, and the
  precise-GPS-from-no-launch-intent constraint.** Records the seam architecture
  (§2) **and** the load-bearing constraint from §1 as its driving consequence:
  external captures are **timestamp-only**. The GPS finding is not a separate
  decision so much as *the constraint that shapes the seam* — fold it in here
  rather than a third ADR, citing this feasibility note for the research/verdict.

The feasibility research itself (verdict + citations) lives in **this note**; the
ADRs record the *decisions* that follow from it.

---

## 4. What needs an owner decision before implementation

1. **Accept external = timestamp-only for v1?** (Recommended — §1.) Confirm we do
   *not* pursue the foregrounding (`openAppWhenRun = true`) or Always-auth routes
   for external location in v1.
2. **Write ADR 0004 + ADR 0005 now?** (Recommended.) Say go and I'll draft them.
3. **Where external capture sits in the order** — proposed after the real Triage
   loop and before location (see `docs/build-order.md` revision). Confirm, or pull
   it later since it does not gate v1.
