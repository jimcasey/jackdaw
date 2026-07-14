# ADR 0005 — Shared `CaptureService` seam; external capture surfaces deferred to v1.x

> **Status:** Accepted — build the shared `CaptureService` core in v1 (justified by
> in-app capture); **ship and validate NO external capture surface in v1**. All
> external surfaces (Action button, Shortcuts, Control Center, Siri, widget, Lock
> Screen) and the `CaptureNoteIntent` front-end are **fast-follow (v1.x)**.
> **Date:** 2026-07-14
> **Owner of decision:** tech-lead (feasibility + architecture), arbitrated by owner.

## Context

The owner wanted low-friction **external capture** — the ability to jot a thought
without first opening Jackdaw (Action button, a Shortcut, Control Center, Siri, a
widget, the Lock Screen). The natural iOS mechanism is an **App Intent**
(`CaptureNoteIntent`) with `openAppWhenRun = false`, invoked from those surfaces,
sharing the app's capture→persistence path.

Two findings shaped the decision:

1. **The GPS feasibility gate failed (the decisive one).** A no-launch App Intent
   (`openAppWhenRun = false`), invoked while Jackdaw is **not foregrounded**,
   **cannot obtain a precise — or any — GPS fix** under When-In-Use authorization.
   This is a platform rule, not a tuning problem: Core Location does not deliver
   updates to a When-In-Use app that is backgrounded unless a
   `CLBackgroundActivitySession`/Live Activity is **already in effect**, and such a
   session can only be asserted **while the app is in the foreground** (Always
   authorization does not rescue the cold case and is an oversized privacy ask).
   Full research, verdict, and citations:
   `docs/feasibility/external-capture-precise-gps.md`.

   Therefore external captures would be **timestamp-only** (no location) — and
   location is Jackdaw's **signature ambient auto-context**. An external capture that
   silently drops the differentiator is a degraded, potentially confusing product
   surface.

2. **The seam has real, non-speculative in-app value.** Regardless of external
   surfaces, the in-app Capture sheet needs a clean core that constructs a `Note`,
   persists it to SwiftData, and attaches best-effort location. Factoring that into a
   `CaptureService` is good hygiene the in-app path pays for on its own.

The project's standing stance (PRD): **clean internal boundaries only — no
speculative plugin systems, no building/testing UI for hypothetical extension
points.** Building an *external surface* now would be speculative investment ahead
of the core loop being proven, for timestamp-only value.

## Decision

**Build the shared `CaptureService` seam in v1; defer every external surface to
v1.x.**

- **In v1 (built):** `CaptureService` — a plain type that owns `Note` construction,
  SwiftData persistence, and best-effort location attachment. It imports **neither
  SwiftUI nor AppIntents**, so it is unit-testable off-device against an in-memory
  `ModelContext`. The **in-app** Capture sheet (`CaptureView` + `CaptureViewModel`,
  the autosave live-draft front-end) sits on top of it. The seam is justified
  **entirely by in-app use**.
- **Deferred to v1.x (not built, not shipped, not validated in v1):** the
  `CaptureNoteIntent` App-Intent front-end and all external surfaces. When built,
  they become a **second thin front-end** over the *same* `CaptureService`
  (a one-shot commit: text via `@Parameter`/`requestValueDialog`, no autosave draft),
  reaching SwiftData through a shared `AppModelContainer`. External captures will be
  **timestamp-only** by the platform constraint above; a foregrounding variant
  (`openAppWhenRun = true`) or a last-known-location cache are the only routes to any
  external location and are themselves fast-follow spikes, not v1.

External capture **does not gate v1**. V1 ships in-app capture only.

## Consequences

**Positive**
- **No v1 investment in a degraded surface.** We do not ship a timestamp-only
  external capture whose value is unproven before the core capture→triage→export
  loop even exists.
- **The seam still lands in v1**, so the fast-follow is a *front-end add*, not a
  re-architecture: when external capture is built, `CaptureService` is already the
  shared core and the intent is a thin adapter.
- **Consistent with the "clean boundaries, no speculative extensibility" stance** —
  we build the boundary the in-app code needs, not a plugin system for hypothetical
  callers.
- Unblocks the ADR 0004 endgame: once external surfaces exist to seed the inbox, the
  Capture sheet can stop auto-presenting.

**Negative / accepted**
- The signature low-friction "capture without opening the app" experience is **not
  in v1**. Accepted: it is timestamp-only anyway (no differentiating auto-context),
  and the owner is the sole user — capture-by-opening-the-app is acceptable until the
  loop is proven.
- If external capture is later deemed essential *with* location, it requires either
  briefly foregrounding the app (`openAppWhenRun = true`, a UX tradeoff) or a
  last-known-location cache — both fast-follow investigations, recorded here so the
  constraint is not rediscovered.

## Related
- Decisive feasibility input (GPS gate + seam architecture):
  `docs/feasibility/external-capture-precise-gps.md`.
- ADR 0004 (nav model; the deferred external surfaces enable its endgame).
- Build order: `docs/build-order.md` (seam in Slice 2′; external surfaces in the
  fast-follow / v1.x section).
- PRD scope stance on seams / non-goals: `docs/prd/mvp-scope.md` §4–5.
