---
name: now-playing-and-v1x-wave
description: v1.x/v2 "context + external surfaces" wave — now-playing feasibility verdict (the wave's GPS-gate analog), surface taxonomy (parameter vs launcher surfaces), NoteType model recommendation, App Group deferral, slice order. Status = owner RULED 2026-07-23 (see "Owner rulings"); plan doc = docs/prd/capture-wave.md (PR #28).
metadata:
  type: project
---

# v1.x wave: note types + context + external surfaces (proposed 2026-07-23)

**Status: owner ruled on all decision points 2026-07-23; synthesis doc is
`docs/prd/capture-wave.md` (PR #28). Three ADRs to write (note-type model /
now-playing context / external-surface architecture).**

## Owner rulings (2026-07-23) — do not relitigate

- Two hardcoded types (Place, Listening) + extensibility ladder with four
  forward-compat commitments (string-tolerant `typeRaw`, verbatim `type:` emit
  *when present*, single `NoteTypeSpec` seam, AppEnum→AppEntity migration cost).
- Owner uses **Apple Podcasts, not Spotify** → Apple Music is the only live
  auto-context source; Spotify Web API route rejected; podcast metadata arrives
  only via the **share route** (Shortcut as share-sheet target → episode URL into
  the intent's media `@Parameter`s). Native Share Extension deferred with App Group.
- §7.3: `type:` **OMITTED for untyped notes** — my emit-always lean was
  **overruled**. Omission is serializer policy; enum keeps an untyped case.
  Adding `type: quick` later is serializer-additive but semantically breaking for
  vault queries keyed on key-absence — record that nuance in ADR 1.
- ADR 0004 auto-present flip lands in slice A. First tranche = S1 + A + B.
  Location cache: untyped external captures only, marked approximate
  (`location_source: cached`), no foregrounding intent.

## Verified during PR #28 review (2026-07-23)

- **Apple Podcasts timestamped share links are REAL (iOS 18+):** Now Playing
  share sheet's "From Start" block lets you pick the paused timestamp; transcript
  long-press gives "Share from [time]". Min target iOS 26 → no gate.
- **Shortcut as share-sheet target is REAL:** "Show in Share Sheet" + accepted
  input types (URL); shared item arrives as Shortcut Input; the shortcut can then
  Ask for Input and run our App Intent (same no-launch engine as any shortcut run).
  Apple Support: shortcuts guide apd163eb9f95 / apd7644168e1.
- **Unverified until slice D:** what Apple Podcasts actually puts in the shared
  payload — likely a bare URL, title NOT guaranteed. Share-route notes may carry
  `mediaURL` only. Use a View-Content-Graph probe shortcut to inspect.

## FEASIBILITY VERDICT — now-playing context (the wave's load-bearing gate)

- **Apple Music, in-app (foreground): YES.** `MPMusicPlayerController.systemMusicPlayer.nowPlayingItem`
  (MediaPlayer) or MusicKit `SystemMusicPlayer.shared.queue.currentEntry`. Reflects the
  **Music app only**. Requires `NSAppleMusicUsageDescription` (mandatory to access the
  media library — Apple bundle-resources doc) + media-library / MusicKit authorization.
- **Apple Music, from a no-launch intent (background): UNVERIFIED/flaky** — forum
  reports of nil/stale nowPlayingItem in background; MPMusicPlayerController unusable
  in extensions. Treat as foreground-only until the on-device spike says otherwise.
- **Apple Podcasts: DEAD.** No public API, no Shortcuts "current episode" action.
- **Overcast: YES via Shortcuts** — "Get Current Episode Info" action (title, URL,
  show notes, artwork) + timestamped URL. Podcast context is Shortcuts-surface-only.
- **System-wide (Spotify/anything): DEAD on-device.** `MPNowPlayingInfoCenter` is
  publish-only (a third-party app cannot read other apps' info); Control Center's view
  is a system privilege. MediaRemote = private framework — do not use (fragile, ToS).
- **Spotify workaround if ever needed:** Web API `GET /v1/me/player/currently-playing`
  (`user-read-currently-playing` scope, OAuth PKCE); works from background (network),
  covers Spotify podcasts via `additional_types=episode`. Adds OAuth+network to a
  local-only app — only if the owner actually uses Spotify.
- **Key architectural consequence: context-via-intent-parameters.** Shortcuts can pipe
  "Get Current Song" / Overcast episode INTO `CaptureNoteIntent` `@Parameter`s — the
  caller supplies context, sidestepping all background-read limits.

## Surface taxonomy (the wave's organizing idea)

1. **Parameter surfaces** (Shortcuts, Action button, Siri): run `CaptureNoteIntent`
   no-launch (`openAppWhenRun=false`), text via `requestValueDialog`, context piped in
   as parameters. Location = last-known cache only (GPS gate, ADR 0005).
2. **Launcher surfaces** (widget, Lock Screen widget, Control Center control): CANNOT
   collect text (no dialogs from widgets/controls) → deep-link/OpenIntent into the
   capture sheet with a preselected type. Foregrounds the app → **full ambient context
   (precise GPS + now-playing) comes back for free.** Widget/control extensions are
   separate processes; a pure launcher never touches SwiftData → **no App Group needed
   yet.** Adopt App Group + store migration only when a widget must READ store data.

## Data model recommendations

- **NoteType = fixed code-defined enum, raw-string backed** (`typeRaw: String` with
  default → additive lightweight migration; same pattern as `statusRaw`). NO
  user-defined @Model type entity (single user; types are code). Per-type context
  requirements live in a code descriptor (e.g. wantsLocation/wantsNowPlaying), not DB.
- **No generic ContextProvider protocol** — two concrete providers (`LocationProviding`,
  `NowPlayingProviding`) + a requirements value consulted by `CaptureService`. A
  registry/type-erased context system = the speculative plugin system we swore off.
- **Media context fields on Note: flat optional primitives** (mediaTitle, mediaArtist,
  mediaSourceRaw, mediaURL...) matching the location-fields pattern; frontmatter keys
  additive-only, omitted when absent (serializer contract stability for Obsidian).
- **Last-known-location cache:** store latest foreground fix + `fixedAt`; stamp
  external notes, mark approximate (e.g. `location_source: cached` in frontmatter);
  staleness threshold = product/design call.

## Proposed slice order (walking-skeleton: riskiest first)

S1 spike: on-device now-playing read (foreground + background from intent) →
Slice A: external skeleton (text-only CaptureNoteIntent + AppModelContainer.shared +
Action button/Shortcut, validates ADR 0005 deferred surface) →
Slice B: NoteType end-to-end (enum, picker, `type:` frontmatter, AppEnum @Parameter) →
Slice C: in-app now-playing context (Apple Music) →
Slice D: piped context via Shortcuts (song + Overcast episode) →
Slice E: launcher surfaces (widget / Lock Screen / Control Center deep-links) →
Slice F: last-known-location cache.

See [[capture-nav-and-external]] for the v1 GPS gate this builds on; sources cited in
the position paper (Apple forums threads 100187/809554/738477, WWDC refs, Overcast
MacStories review, Spotify Web API reference).
