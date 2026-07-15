# Slice 5 — Location context (in-app precise GPS)

> **Status:** Implementation spec, ready to build. **Date:** 2026-07-14.
> **Owner of spec:** tech-lead. **Implements:** build-order's Location slice — the
> last piece of the funnel's signature "context attached automatically."
> **Prereq met:** Triage done (27 tests green); `CaptureService` seam,
> `CaptureViewModel` lazy-create, `NoteEditorView` with a `// location row` hook,
> and `Note` all exist.
> **Scope:** **in-app precise GPS only.** External capture was deferred (ADR 0005);
> there is **no external-location dimension** to build. In-app capture runs in the
> **foreground**, where When-In-Use precise GPS works normally — unlike the
> no-launch App-Intent case that failed the feasibility gate
> (`docs/feasibility/external-capture-precise-gps.md`).
>
> **Numbering:** implementation numbering runs one ahead of `docs/build-order.md`'s
> table (the capture rework became its own slice). This is *the* Location slice; it
> precedes the Apple Notes and Obsidian export slices.

Owner-settled earlier: **precise (GPS), not coarse**; context = **time + location
only**. Honors design-lead's precise-location permission flow
(`docs/design/open-ux-threads.md` Thread 5), the editor's location row
(`capture-and-triage-flows.md` §Note editor), and the accessibility baseline.

---

## 1. `Note` model — location fields (additive, lightweight migration)

Add to `Note.swift` (all optional → SwiftData lightweight-migrates existing notes;
pre-release we can also reset the store):

```swift
// --- location (Location slice) — optional → lightweight migration ---
var latitude: Double?
var longitude: Double?
var horizontalAccuracy: Double?     // metres; lets us tell precise from reduced, and travels to frontmatter
var placeName: String?              // reverse-geocoded label, filled lazily AT DISPLAY (see §4) — nil if not resolved

var hasLocation: Bool { latitude != nil && longitude != nil }
```

**Recommendation: do NOT persist a `pending`/`denied` location-state enum.** The
build-order called `location: pending` a "steady state," but the right
representation is **nullable coordinates**, and here's the reasoning (a useful iOS
teaching point): *pending* is **transient** — it exists only in the few seconds
between a note being created and its fix arriving, and that in-flight-ness lives in
the location task's memory, not on disk. A **persisted** `pending` flag would go
**stale**: if the app is killed before the fix lands, the note would look
forever-pending. So:
- **`hasLocation == false` means "no location"** — full stop — whether the fix was
  never granted, was denied, or was lost to an early kill. At triage time (minutes/
  hours later) the capture-moment fix window is long gone, so nil coordinates are
  correctly terminal.
- The editor renders `hasLocation == false` as **"No location"** (§5); the export
  serializer (later slice) omits location or writes null.

Keep `horizontalAccuracy` (cheap, and it's how we distinguish a precise fix from a
reduced-accuracy one for the frontmatter and any future nudge). Do **not** put a
`CLLocationCoordinate2D` computed property on the `@Model` — keep `Note.swift`
free of the CoreLocation import; build the coordinate where it's needed in the
location layer.

---

## 2. `CaptureService` location attachment — honoring the seam contract

The seam contract (Slice 2 §4, build-order reconciliation): the note is created
**synchronously**; the location request is **kicked off bound to that specific
`Note` instance**; the fix is written onto it **asynchronously when it arrives,
even after the in-app draft has detached**; **capture never `await`s a fix.**

### Abstract the location source behind a protocol (mockable off-device)

Same discipline as `CaptureService`/`SnoozeSchedule` — the protocol is plain
(no CoreLocation), so tests inject a mock; only the concrete provider imports
CoreLocation.

```swift
struct LocationFix { let latitude, longitude, horizontalAccuracy: Double }

protocol LocationProviding {
    /// Best-effort one-shot fix. Returns nil on denied / unavailable / timeout.
    /// Never throws, never blocks capture — the caller does not await it inline.
    func currentFix() async -> LocationFix?

    var authorizationStatus: LocationAuthStatus { get }   // for priming / denied UI
    func requestWhenInUseAuthorization()
    func prewarm()                                        // start warming a fix (sheet appear)
}
```

### The attach flow (fire-and-forget, bound to the note)

Keep `makeNote` unchanged (external one-shot commit reuses it *without* location —
ADR 0005). Add a separate `attachLocation` the **in-app** path calls:

```swift
struct CaptureService {
    let location: LocationProviding?      // nil in tests that don't care / external path

    func makeNote(body: String, in context: ModelContext) -> Note { /* unchanged */ }

    /// Fire-and-forget best-effort backfill, bound to `note`. Production wraps the
    /// async core in a detached Task so capture never awaits.
    func attachLocation(to note: Note, in context: ModelContext) {
        guard let location else { return }
        Task { @MainActor in
            await resolveLocation(for: note, using: location, in: context)
        }
    }

    /// The awaitable core — tests call this directly with a mock provider.
    @MainActor
    func resolveLocation(for note: Note, using provider: LocationProviding,
                         in context: ModelContext) async {
        let fix = await provider.currentFix()
        guard note.modelContext != nil else { return }   // GUARD: note was pruned/deleted — don't write to a dead object
        apply(fix, to: note)
        try? context.save()
    }

    /// Pure — unit-testable with no provider at all.
    func apply(_ fix: LocationFix?, to note: Note) {
        guard let fix else { return }        // nil → leave timestamp-only, no error
        note.latitude = fix.latitude
        note.longitude = fix.longitude
        note.horizontalAccuracy = fix.horizontalAccuracy
    }
}
```

Wired into the VM's lazy-create (the one place a note is born in-app):

```swift
// CaptureViewModel.edit, in the `draft == nil` branch, after makeNote:
let note = service.makeNote(body: text, in: context)
service.attachLocation(to: note, in: context)   // async backfill bound to `note`
draft = note
```

Because the `Task` holds a strong ref to `note`, the fix lands on the correct row
**after `finishEditing` sets `draft = nil`** — satisfying "even after the draft
detaches." The `modelContext != nil` guard makes the pruned-note race safe (a note
created on first keystroke, then cleared to empty and abandoned, is deleted; its
in-flight fix must not resurrect it).

- **`@MainActor`:** the SwiftData main `ModelContext` is main-actor-bound, so the
  mutation + save run on the main actor. `await currentFix()` suspends while
  CoreLocation works off-thread, then resumes on main to write.
- **Rapid multi-capture:** each note gets its own `attachLocation`. The concrete
  provider should **cache the most recent fix** (pre-warmed on sheet appear) and
  return it immediately, so three-in-a-row notes all get a fix without three cold
  GPS spins.

### One-shot fix API — recommendation

Use **`CLLocationManager` with `startUpdatingLocation`**, started on Capture-sheet
appear (pre-warm) with `desiredAccuracy = kCLLocationAccuracyBest`, caching the
latest fix; `currentFix()` returns the freshest cached fix (or awaits the next
delegate callback with a short timeout, else nil). Stop updating on sheet dismiss
to save battery.

Why not the alternatives (verified 2026-07-14):
- **`requestLocation()`** is the classic true one-shot but is **slow cold (~10 s on
  device)** — bad for a note that wants its fix within seconds.
  ([HackingWithSwift — requestLocation](https://www.hackingwithswift.com/example-code/location/how-to-request-a-users-location-only-once-using-requestlocation))
- **`CLLocationUpdate.liveUpdates`** (the modern async sequence) is fine for
  foreground but has **no `desiredAccuracy`/`distanceFilter`** (you filter the
  stream yourself), and the community guidance is to prefer `CLLocationManager` for
  accuracy control and reliability.
  ([Apple — liveUpdates](https://developer.apple.com/documentation/corelocation/cllocationupdate/liveupdates(_:)),
  [Core Location modern API tips](https://twocentstudios.com/2024/12/02/core-location-modern-api-tips/))
The protocol hides the choice, so we can swap to `liveUpdates` later without
touching `CaptureService`.

---

## 3. Permission flow + Info.plist

### Target change (state it exactly)

Add **one** required key to the target's Info.plist:
- **`NSLocationWhenInUseUsageDescription`** — e.g. *"Jackdaw attaches where you were
  to each note, so a fleeting thought keeps its context. Location stays on your
  notes and is sent only to your Obsidian vault."* Without this key the app
  **crashes** on the authorization request.

**Precise needs no separate entitlement.** Since iOS 14 the When-In-Use prompt
includes a **Precise: On** toggle (on by default); we request When-In-Use and set
`desiredAccuracy = kCLLocationAccuracyBest`. There is no "precise" capability to
enable. ([Apple — NSLocationWhenInUseUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationwheninuseusagedescription))

- **Authorization level: When-In-Use** (design Thread 5) — capture is always
  foreground; **Always** would be a heavier, creepier ask with zero benefit.
- **Add `NSLocationTemporaryUsageDescriptionDictionary` ONLY if** the reduced-
  accuracy nudge (§7) is adopted — it's the purpose-key dictionary that
  `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` displays. If the
  nudge is cut, this key is not needed.

### Priming + timing (design-lead owns the exact moment; we own the mechanism)

- **Never ask on first launch, never block the first capture.** The field is live
  immediately. Show a lightweight **location priming sheet** *before* the system
  dialog so the system prompt isn't a cold surprise; **Continue** →
  `provider.requestWhenInUseAuthorization()`.
- Mechanism: a **once-only gate** (persist a `hasPrimedLocation` flag in
  `UserDefaults`) fires the priming sheet at a **non-interrupting** moment — design
  Thread 5 proposes "when the owner banks their first note, or a beat after the
  sheet settles if idle." Under autosave, "banks their first note" = the first note
  is created; present the priming sheet when `authorizationStatus == .notDetermined`
  at that point, but **not mid-keystroke** (present on the New-note hand-off or on
  sheet dismiss to avoid interrupting typing). Exact trigger is design's call; the
  gate + "before the system prompt" ordering is the contract.
- If a note is banked **before** authorization is granted, it attaches **timestamp
  only** (honest); later notes get GPS once granted.

### Denied / reduced-accuracy behavior (capture must still work)

- **Denied / restricted →** `currentFix()` returns nil → note stays **timestamp-
  only**. **No error, no per-capture nag.** The denied status surfaces **once,
  calmly**, in the Settings sheet (a later slice) — not this slice's concern beyond
  degrading cleanly.
- **Reduced accuracy** (`accuracyAuthorization == .reducedAccuracy`): the fix is a
  real (coarse) coordinate — **apply it normally**; `horizontalAccuracy` records
  that it's coarse. Whether to nudge toward precise is an owner decision (§7); by
  default we accept the reduced fix and do not block.

---

## 4. Reverse geocoding for a place name — recommendation

**Do NOT geocode at capture. If names are wanted, reverse-geocode lazily AT
DISPLAY (in the editor), cached into `placeName`.**

Reasoning:
- **Capture is offline-first and must never depend on the network.** `CLGeocoder`
  is a network call; running it in the capture path would either fail offline or
  add a network dependency to the one path that must never have one. So capture
  **stores coordinates only**.
- The place **name is legibility sugar**, not the captured context — the
  **coordinates** are the real data (and what goes to frontmatter). The editor's
  **map thumbnail renders from coordinates alone**; it doesn't need a name.
- Triage happens later, in a sit-down (usually online), so a **lazy geocode at
  display** is an acceptable place for a network call. Cache the result into
  `placeName` so it's geocoded once; if offline/failed, show coordinates or nothing
  and leave `placeName` nil.

**My lean: include lazy-at-display place names** (design wants them and they're
cheap at display) — but this is the **most cuttable** piece; shipping just
coordinates + the map thumbnail is fully acceptable. Owner call (§7).

---

## 5. The editor's location row goes live

Replace the `// location row — Location slice` hook in `NoteEditorView`'s Context
section:

- **`note.hasLocation == true`:** a **small static map thumbnail** centered on the
  coordinate with a marker (a non-interactive `Map`, or a `MKMapSnapshotter` image),
  the **place name** if resolved (§4), and a **Clear location** button (sets
  `latitude/longitude/horizontalAccuracy/placeName = nil`, then saves).
- **`note.hasLocation == false`:** show **"No location"** — no broken/empty map.
- **Accessibility (design baseline):** the map thumbnail **must** carry a text
  alternative via `.accessibilityLabel` (the place name, else "Location:
  \<lat>, \<lon>"); Clear is a real ≥44 pt button; the "No location" state is plain
  text, already accessible.

**Ships this slice:** the row (map thumbnail from coordinates + "No location" +
Clear), and lazy place-name **if adopted**.
**Deferred polish (design already flagged as cut-candidates):** "drop a pin on a
map to correct/move the location" — **defer**; view + clear is the must-have.
Editing stays **light** — no pin-drop, no location search.

---

## 6. Testing plan

**Off-device (Swift Testing, in-memory `ModelContainer` + a mock `LocationProviding`).**
The awaitable `resolveLocation`/pure `apply` split is what makes the async
deterministic — tests `await resolveLocation(...)` with a mock that returns
immediately; no real GPS, no timers, no `Date()` nondeterminism.

- **Backfill lands on the correct note:** `makeNote` (nil coords) → `await
  resolveLocation` with a mock returning a fix → that note's `latitude/longitude/
  horizontalAccuracy` are set; a *different* note is untouched.
- **Permission-denied → timestamp-only:** mock `currentFix()` returns nil →
  `apply(nil, to:)` leaves coords nil; note is valid and timestamp-only.
- **Pending → resolved transition:** create note (assert `hasLocation == false`),
  resolve with a fix (assert `hasLocation == true`).
- **Pruned-note guard:** delete the note, then `resolveLocation` → no crash, no
  write (the `modelContext != nil` guard).
- **Reduced accuracy:** mock returns a large `horizontalAccuracy` fix → applied
  normally (coords set, accuracy recorded).
- **Place name (if adopted):** mock geocoder resolves → `placeName` set; mock
  fails/offline → `placeName` stays nil, coords unchanged.
- **`apply` purity:** unit-test `apply(fix:)` / `apply(nil:)` directly, no provider.

**Needs the simulator (or device):**
- The **actual permission prompt**: priming sheet → system dialog; grant, deny, and
  **Precise: Off** paths.
- **Simulated location** (Xcode → Features → Location, or a GPX route) → captured
  note gets coordinates.
- **Editor map thumbnail** renders for a located note; **"No location"** for a
  denied note; **Clear** empties it.
- Reduced accuracy end-to-end (toggle Precise Off in Settings).

---

## 7. Decisions — SETTLED (owner, 2026-07-14)

1. **Location-priming sheet — KEEP.** One-time, non-blocking rationale before the
   system prompt.
2. **Reduced-accuracy nudge — CUT for v1.** Accept a reduced fix as-is; drop the
   `requestTemporaryFullAccuracyAuthorization` plumbing and the
   `NSLocationTemporaryUsageDescriptionDictionary` Info.plist key entirely.
   Additive later if wanted.
3. **Reverse-geocode place names — INCLUDE, lazily at display.** Never at capture
   (offline-first); reverse-geocode when the editor shows the note, cache into
   `placeName`. Map thumbnail renders from coordinates regardless.

## Related
- Seam contract + CaptureService: `docs/slices/slice-2-capture-swiftdata.md` §4;
  `Jackdaw/CaptureService.swift`, `Jackdaw/CaptureViewModel.swift`
- Precise-location permission flow: `docs/design/open-ux-threads.md` Thread 5
- Editor location row + a11y: `docs/design/capture-and-triage-flows.md` §Note editor;
  `docs/design/accessibility-and-hig.md`; `Jackdaw/NoteEditorView.swift`
- GPS feasibility (why in-app foreground is fine): `docs/feasibility/external-capture-precise-gps.md`
- Persistence + additive migration: `docs/adr/0003-persistence-swiftdata.md`
- Grows: `Jackdaw/Note.swift`, `Jackdaw/NoteEditorView.swift`, `Jackdaw/CaptureService.swift`
