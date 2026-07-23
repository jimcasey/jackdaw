---
name: types-and-context
description: v1.x design position — note types via surface-implies-type (untyped default, triage is the filing moment); context is expected-not-required (never block capture); no note content on widgets.
metadata:
  type: project
---

**Status: design-lead position for v1.x planning (2026-07-23), pending owner
ratification.** Governs note types, external surfaces, and song/podcast/place
context.

## Type model — "surface implies type; untyped default; triage files"
- **Capture never requires a type choice.** Untyped is a first-class, permanent
  default — not an error state. A mandatory in-sheet picker would be a filing
  decision and violates capture-in-seconds.
- **Type comes free from the trigger:** per-type widget buttons / per-type
  controls / per-type App Shortcuts deep-link into the Capture sheet with the
  type preapplied. Action button (fastest, no-launch) = always untyped.
- **In-sheet affordance:** one optional type chip (a `Menu`) in the sheet
  header — shows current type, tap to change, never focus-stealing, never
  blocks. Correction/assignment otherwise happens **in the Triage editor**.
- **Taxonomy discipline:** small fixed set (cap UI at ~6; start 3–4), type =
  SF Symbol + tint + label. **No type-manager settings UI** (taxonomy creep =
  filing creep). Symbols must be shape-distinct (widgets/controls render
  monochrome in vibrant/accented modes — color will be stripped).

## The load-bearing surface principle
**No-launch = untyped + timestamp-only. Typed = foreground.** Any surface that
implies a type deep-links into the app's Capture sheet (foreground → real GPS +
now-playing available), because typed captures are exactly the ones whose
context matters. The Action button's system prompt (`requestValueDialog`) is
the speed path, not the quality path — it is not our editor, has no New-note
rhythm, no context confirmation. Both are correct; don't blur them.
- Platform rules (verified 2026-07): widgets/controls **cannot host text
  input**; widget-button intents run with **no UI** (no dialogs); controls
  "cannot capture complex input" (HIG Controls page) — a control either runs a
  background intent or opens the app to a specific area. No-launch intent gets
  **no GPS** (docs/feasibility/external-capture-precise-gps.md).
- **No note content or previews on widgets** — a Home Screen pile is archive
  creep + privacy leak. Count-only at most.
- Skipped surfaces (recorded so we don't relitigate): systemLarge widget
  (nothing glanceable that isn't content), accessory Lock Screen widgets
  (controls cover it better on iOS 18+), Back Tap (user-config, nothing to
  build), StandBy-specific work.

## Context = "expected", never "required"
- Reframed the owner's "required context" as **context affinities** per type.
  **Recommendation: never block capture on missing context; no warning badges
  in triage rows; surface absence only in the editor's Context section**
  ("No location captured" + "Use current location" backfill button). Blocking
  violates the sacred constraint; row badges become alarm noise because
  podcast/now-playing detection will *often* legitimately fail.
- **Feasibility gate (tech-lead):** third-party now-playing is limited — Apple
  Music likely readable (MusicKit/system player, needs media-library
  permission → lazy, in-context priming like location), **Apple Podcasts /
  Spotify likely not readable**. Design assumes frequent absence by
  construction. A media-library permission ask must never front-load.
- **Stale last-known-location cache attached to a place-typed note is worse
  than no location** (confidently wrong data). If a cache is ever used it must
  be visibly marked approximate; I prefer routing typed captures through
  foreground instead.
- Display: capture sheet gets a thin **non-interactive context strip** (silent
  arrival, no spinners, no VoiceOver announcements per-arrival); triage row
  keeps ONE secondary context line (time first, then place, then media glyph);
  editor Context rows are **view + clear** for media — never a "pick a song"
  browser.

## ADR 0004 endgame
Flip the auto-present flag **in the same slice as the Action-button intent**;
owner validates on device; it's one flag to revert. Bare Triage root then needs
the prominent bottom compose button. Deep-linked captures (widget/control)
bypass the flag by definition.

Related: [[external-capture]], [[capture-model]], [[funnel-nav-constraint]],
[[a11y-baseline]]. Full position delivered 2026-07-23 (v1.x planning session).
