# Capture-wave slice A — External skeleton: `CaptureNoteIntent` + Action button + the ADR 0004 flip

> **Issue:** #30 · **Plan:** `docs/prd/capture-wave.md` §5 (A) · **ADRs:**
> 0005 (seam), 0008 (surface architecture + flip), 0009 (why this slice reads
> no media). The wave's walking skeleton: the no-launch capture → SwiftData
> round-trip that ADR 0005 explicitly deferred, validated on-device.

## What ships

- **`AppModelContainer.shared`** — one `ModelContainer` (`static let`) backing
  both the SwiftUI scene and the intent; `JackdawApp` switches from
  `.modelContainer(for:)` to it. No behavior change in-app.
- **`CaptureService.commit(text:in:)`** — the one-shot path (trim →
  whitespace-only creates nothing → insert + synchronous save). The in-app
  autosave lifecycle is untouched.
- **`CaptureNoteIntent`** — `openAppWhenRun = false`; text via
  `@Parameter`/`requestValueDialog` ("What's on your mind?"); commits through
  the seam; replies "Captured." / "Nothing to capture.". Untyped,
  timestamp-only by design (no GPS on no-launch — ADR 0005; media enrichment
  is Listening-scoped — ADR 0009, arrives with slice B's type parameter).
- **`JackdawShortcuts`** (`AppShortcutsProvider`) — zero-setup "Capture Note"
  App Shortcut: runnable from Shortcuts/Spotlight and directly assignable to
  the **Action button**, no manual assembly. (Learned on the S1 spike: a bare
  `AppIntent` only appears as an *action* to assemble; the provider is what
  makes it a ready-made shortcut.)
- **The ADR 0004 flip** — `RootView.showCapture` initial value `true → false`:
  launch opens to the bare Triage root. The nav-bar Capture glyph is replaced
  by the **bottom-docked "Capture" button** (labeled, ≥44pt,
  `.borderedProminent`, attached to the stack root so pushing the editor hides
  it; the empty state keeps it — screen-inventory 1a). "New note" stays
  reserved for the sheet's keyboard-toolbar delimiter (review F1: one label,
  one behavior). TriageRootView's undo-banner/export-bar inset stacks above it.

## Deliberately not in this slice

Type parameter (slice B) · media parameters + share shortcut (slice D) ·
launcher surfaces (slice E) · location cache (slice F) · any change to the
in-app capture sheet itself.

## Off-device verification

Five new `CaptureServiceTests` cover the commit path (finished inbox note,
trimming, whitespace-only → nothing, timestamp-only, and a sibling-context
read that pins the synchronous save). **Test count: 81.**
The intent itself is a thin adapter over the tested seam — its `perform()` is
not unit-tested (AppIntents runtime), by the same stance as the v1 view layer.

## On-device validation (owner — the slice's real "done")

1. **Round-trip:** run **"Capture Note"** from the Shortcuts app (it should
   appear ready-made, no assembly) with Jackdaw closed → type a thought →
   open Jackdaw → the note is in Triage, timestamped, no location.
2. **Action button:** Settings → Action Button → Shortcut → **Capture Note**.
   Press-and-hold from anywhere (lock screen included) → capture → verify it
   lands. *This starts the §7.1 escape-hatch clock (~2 weeks) — **record the
   date you configure it** (a comment on issue #30, or STATUS.md), or the
   window is unfalsifiable two weeks from now.*
3. **Warm case:** with Jackdaw **backgrounded (not quit)**, capture via the
   Action button → return via the app switcher → the note is in Triage
   **without relaunching**. (This is where the `mainContext` review fix
   lives — validate it even though it's fixed.)
4. **Cold case:** force-quit Jackdaw, capture via Action button, reopen —
   note present. (S1 already proved the process model; this proves the write.)
5. **Whitespace guard:** submit an empty/spaces-only prompt → "Nothing to
   capture." → no note in Triage.
6. **The flip:** launch Jackdaw → bare Triage root (no auto-sheet), the
   **Capture** button docked at the bottom, still present on the empty state
   and on the editor's dismissal; first-capture location priming still fires
   after a sheet capture. Check the bottom-chrome stack: undo banner / export
   bar sit **above** the Capture button, and the "Saved to Obsidian" toast
   doesn't collide with it.
7. **Accessibility pass:** (a) VoiceOver swipe-through order lands
   list → export bar → Capture, and the button reads "Capture, button, Opens
   the capture sheet"; (b) at AX5 Dynamic Type with the `needsSetup` bar up,
   both stacked buttons stay legible and the list stays usable.

## Revert lever

The flip is one line (`showCapture = false → true` in `RootView`); the intent
and shortcut are additive and stand regardless of the flip's fate.
