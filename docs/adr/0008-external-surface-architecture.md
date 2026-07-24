# ADR 0008 — External capture surface architecture (parameter/launcher lanes, context-via-parameters)

> **Status:** Accepted — ratified via the capture-wave plan
> (`docs/prd/capture-wave.md`, PR #28, merged 2026-07-23; §3–§5, §7.1, §7.4,
> §8.3) and its checkpoint review.
> **Amends ADR 0004** (the auto-present endgame now ships in capture-wave
> slice A) **and ADR 0005** (external surfaces now scheduled; "no-launch = no
> location" stands, extended with an untyped-only last-known-location cache).
> **Refined 2026-07-23 by ADR 0009:** the context-via-parameters principle
> gains one verified exception — the no-launch Apple-Music read (S1 spike:
> works warm *and* cold) — used as best-effort enrichment; piped parameters
> still win when supplied.
> **Date:** 2026-07-23
> **Owner of decision:** tech-lead (architecture + feasibility), design-lead
> (surface UX), arbitrated by owner.

## Context

ADR 0005 built the `CaptureService` seam and deferred every external surface
to v1.x. The capture wave now builds them. Three platform facts shape the
architecture (research: `.claude/agent-memory/tech-lead/now-playing-and-v1x-wave.md`;
the GPS gate: `docs/feasibility/external-capture-precise-gps.md`):

1. **Widgets and Control Center controls cannot collect text.**
   `requestValueDialog` is a Shortcuts/Siri affordance; a widget button or
   control runs an intent with no dialog UI. A "capture" surface that stays
   background but can't take text is useless.
2. **Background context reads are dead or unreliable.** A no-launch intent
   gets no GPS (ADR 0005, unchanged). Now-playing: Apple Music is readable
   **in the foreground** (MediaPlayer/MusicKit, behind a media-library
   permission); Apple Podcasts exposes **no API at all**; system-wide
   now-playing (`MPNowPlayingInfoCenter`) is **publish-only**; MediaRemote is
   private (rejected). The owner uses Apple Podcasts and is not a Spotify
   user (rulings, plan §7.5), killing the piped-Overcast and Spotify-Web-API
   variants.
3. **Shortcuts can supply context as input.** "Get Current Song" exists; a
   Shortcut can be a **share-sheet target** receiving a shared URL (Apple
   Podcasts shares episode links, optionally timestamped) and then run our
   intent with parameters — all no-launch.

## Decision

### Two lanes, by construction

1. **Parameter surfaces — Action button, Shortcuts, Siri.** No-launch
   (`openAppWhenRun = false`): system text prompt / dictation → one-shot
   `CaptureService.commit`. Type arrives as an intent `@Parameter`
   (`NoteTypeAppEnum`); context arrives **as optional parameters supplied by
   the caller** — never read by us in the background. This is the speed
   lane; the Action button stays bound to the *untyped* capture.
2. **Launcher surfaces — widgets, Control Center, Lock Screen controls.**
   Deep-link into the app's Capture sheet with the type preapplied
   (`widgetURL` / `OpenIntent`). Launching foregrounds the app, so precise
   GPS and the Apple Music read return for free — launcher surfaces get
   *full* ambient context. **Place-typed capture is a launcher-surface
   story** (§7.4 ruling): its context is only real in the foreground.

**The organizing principle: external context is caller-supplied parameters,
not background reads.** Everything below follows from it.

### Intent placement & process model

- `CaptureNoteIntent` lives in the **app target** (app process — ADR 0005's
  shared `AppModelContainer.shared`, a static-let container). The Control
  Center control's intent needs dual-target membership and `OpenIntent`
  (no `UIApplication` in extensions).
- **No App Group this wave — recorded deferral.** Widget/control extensions
  are separate processes, but under the launcher architecture **no extension
  ever touches the SwiftData store** (they deep-link; the app writes). The
  day a widget *displays* store data (e.g. inbox count), we pay the toll:
  App Group entitlement on both targets, container URL change, and a
  one-time store-file move before container init — plus cross-process
  change-propagation handling. Deferred knowingly, not forgotten.

### Share-sheet route (amends the v1 non-goal, narrowly)

A Shortcut share-target receives a shared episode URL, prompts for the
thought (Ask for Input), and invokes the intent with the URL in the media
parameters. **Three guardrails:**

1. The shared URL lands in the **media parameters only — never the note
   body** (the body is the thought; the episode is context).
2. The share shortcut **hardcodes `listening`** — no type question in the
   flow (guardrail 1 of ADR 0007 applies to Shortcuts-authored flows).
3. A cancelled/empty Ask-for-Input **creates no note** (prune-on-abandon
   convention).

The amendment is scoped to the Listening *job*: media context into the
existing media parameters. Any non-media parameter serving shared content
(articles, links, places) is a *new* reopening of the "no share-sheet
ingest" non-goal and needs its own funnel argument. **Payload floor is a
bare URL** — title extraction is optional polish, never assumed. A **native
Share Extension is deferred** (separate process → the App Group toll, for UX
polish the Shortcut route covers).

### External location: cache, untyped-only

- Persist the **latest foreground fix** with a `fixedAt` timestamp
  (UserDefaults — single blob, app-process reader only; no App Group).
- **Untyped** external commits stamp cached coordinates + provenance;
  serializer emits `location_source: cached`; the editor marks it
  approximate. Staleness is decided at export/display, tunable without
  migration.
- **A cached fix never stamps a Place-typed note** — confidently-wrong
  poisons the export; Place routes through launcher surfaces (above).
- **No `openAppWhenRun = true` foregrounding capture intent** — launcher
  surfaces already cover foreground-with-full-context with better UX than a
  flash-then-return.

### The ADR 0004 flip

The Capture sheet **stops auto-presenting in capture-wave slice A** (the
Action button slice): bare Triage root, compose button as primary chrome
(bottom-docked, 44pt+, labeled), root empty state per screen-inventory 1a,
deep-linked captures present the sheet regardless of the flag. Escape hatch:
**revert without debate** if in-app capture is still dominant after ~2 weeks
of real use, **clocked from when the Action button is actually configured**
(week one is habit lag, not evidence).

## Consequences

**Positive**
- Every surface is the compliant platform shape *and* the right product
  shape: the speed lane stays zero-decision and no-launch; typed capture
  lands where its context actually exists (foreground).
- No App Group, no store migration, no second store-writer process this
  wave — the riskiest infrastructure is deferred until a surface genuinely
  needs it, with the cost recorded.
- Apple Podcasts metadata reaches notes at all (share route) despite the
  platform offering no read API.

**Negative / accepted**
- No-launch captures carry degraded context by design: timestamp +
  (untyped-only) approximate location, no live media read. The repair path
  is triage, where it belongs.
- The share gesture inverts capture (~4 taps starting in the source app) —
  accepted because the moment matches (the thought strikes at the player)
  and it is the only route to real episode metadata.
- Two owner-authored Shortcuts are configuration living outside the repo —
  documented in the slice specs, but not versionable.

## Related

- `docs/prd/capture-wave.md` — the ratified plan; this ADR records its §8.3.
- **ADR 0004** (amended by this ADR — flip timing) · **ADR 0005** (amended by
  this ADR — surfaces scheduled; location stance extended).
- ADR 0007 — the `NoteType` model whose `NoteTypeAppEnum` rides the intent.
- `docs/feasibility/external-capture-precise-gps.md` — the standing GPS gate.
- Slice issues: #29 (S1 spike), #30 (A), #33 (D), #34 (E), #35 (F).
