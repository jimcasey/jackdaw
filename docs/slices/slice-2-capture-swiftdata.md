# Slice 2 — Thin capture + SwiftData

> **Status:** Implementation spec, ready to build. **Date:** 2026-07-14.
> **Owner of spec:** tech-lead. **Implements:** build-order Slice 2; introduces
> the persistence layer per ADR 0003 (SwiftData).
> **Prereq met:** Slice 1 PASSED on-device — T2 ratified, ADR 0001 proven. The
> Talon core lives in `Jackdaw/Talon/` (untouched by this slice).
> **Verify on:** iOS Simulator is sufficient for this slice (no entitlement, no
> sandbox-crossing, no device-only behavior — contrast Slice 1).

This is where the app becomes itself: capture a text note with a timestamp,
near-zero friction, persisted locally. Honors design-lead's capture flow
(`docs/design/capture-and-triage-flows.md` §1) and the two-tab shell
(`docs/design/navigation-and-screen-inventory.md` §2).

---

## 1. Scope & non-scope

**In scope:**
- A SwiftData `Note` `@Model` (body + timestamp + id) and the app-level
  `ModelContainer`.
- The **Capture** screen: launch-to-capture, keyboard up, full-bleed editor,
  explicit Save, field clears and stays. Persist locally, immediately.
- The **two-tab `Capture | Triage` shell** (Triage is a deliberate throwaway stub
  this slice — see §3).
- Swap the app root off `VaultProofView`.

**Out of scope (arrives at its own slice — do NOT build here):**
- **Location** (Slice 3). No `CLLocationManager`, no location fields *yet* — but
  the save path is architected so location backfill slots in without a rewrite
  (§4).
- **Retention lifecycle / triage actions / export** (Slice 4+). The Triage tab is
  a stub, not the real inbox.
- **Note editing** (Slice 4 note editor). Capture only creates notes.
- Any network / sync / reachability code (§5).

---

## 2. The SwiftData `Note` model

```swift
import Foundation
import SwiftData

@Model
final class Note {
    // A stable identity independent of SwiftData's PersistentIdentifier.
    // We'll want this when a note flows through export/retention and, later,
    // becomes a filename. Assign once at creation.
    var id: UUID
    var body: String
    var createdAt: Date

    init(id: UUID = UUID(), body: String, createdAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }
}
```

**Why `@Model` is a `final class`, not a struct** (owner, new to iOS): SwiftData
tracks objects by *reference identity* so it can observe mutations and write them
back to the store — that requires a class. The `@Model` macro rewrites this class
at compile time to add persistence (think of it as the framework generating the
ORM mapping for you). `final` because SwiftData models aren't meant to be
subclassed and it helps the compiler.

### Decision: add location + lifecycle status **at their own slices (b), not now**

The forward-compat question was: include nullable location + a status enum now
(a), or add them when their slices land (b). **Call: (b) — defer, with the
migration-safety guidance below.** Reasoning:

- **A field with no code to populate it is dead weight and an audit hazard.** For
  an owner learning to read Swift, a `status` enum that nothing sets, or
  `latitude`/`longitude` that nothing writes, invite "what drives this?" confusion
  during review. Each slice should carry only what it uses.
- **The change is cheap because it is *additive*.** SwiftData performs
  **automatic lightweight migration** for additive changes — adding an **optional**
  property, or a property **with a default value** — with no migration code. So:
  - Slice 3 adds `var latitude: Double?` / `var longitude: Double?` /
    `var locationResolved: Bool` (**optional / defaulted** → lightweight).
  - Slice 4 adds `var status: NoteStatus` with a **default** (e.g. `.inbox`) →
    lightweight; existing captured notes migrate to the default automatically.
- **We are pre-release, single-user, with zero shipped data.** Even a
  *non-lightweight* change is a non-event right now: we just **reset the local
  store** (delete the app from the simulator/device, which wipes its container) and
  relaunch. There is no user data to preserve. **We do not write a
  `SchemaMigrationPlan` until there is real data worth migrating** — which, for a
  single-user tool, first matters only once the owner is in daily use
  (post-Slice-6). Building migration machinery now is speculative.

**Guidance to keep future changes lightweight (so we never *need* a migration
plan pre-release):** when location and status land, add them as **optional** or
**with a default value**, never as a bare non-optional with no default. If we ever
must make a breaking change before daily use, prefer **reset the store** over
authoring a migration.

> Net rule to prevent drift: *Slice 2 ships `Note { id, body, createdAt }`. Slice 3
> and Slice 4 extend it additively. No migration plan before real data exists.*

---

## 3. App wiring, the tab shell, and the harness

### `modelContainer` setup

Attach the container **once, at the app scene**, so a `ModelContext` is available
throughout the environment:

```swift
@main
struct JackdawApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Note.self)   // default on-disk store in App Support
    }
}
```

`.modelContainer(for:)` creates the container (schema = `Note`), stores it in the
default on-disk location (the app's Application Support directory, inside the
sandbox container), and injects a main-thread `ModelContext` into the SwiftUI
environment. Views read it via `@Environment(\.modelContext)`. No path
configuration needed — this is *our own* container, unrelated to the Talon vault
bookmark (that's a user-picked external folder; this store is internal).

### Decision: introduce the two-tab shell **now**, Triage as a throwaway stub

**Call: build the real `TabView` shell this slice.** Reasoning:
- The two-tab `Capture | Triage` navigation is already specced and ratified
  (design nav doc §2). Building `CaptureView` into its **real home** now avoids a
  re-wire at Slice 4.
- The stub **solves this slice's verification gap.** The Capture screen shows *no
  list* by design (funnel ethos — capture never opens onto the pile). So there is
  no in-app way to *see* that a note persisted. The stubbed Triage tab becomes a
  **temporary persistence probe**: a `@Query`-backed list/count of captured notes.
  Capture a note → switch to Triage → see it → relaunch → still there. That is the
  Slice-2 acceptance check, and it exercises the reads-in-view policy (§4) in a
  low-stakes place before the real inbox at Slice 4.

```swift
struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("Capture", systemImage: "square.and.pencil") }
            TriageStubView()            // THROWAWAY — replaced by the real inbox at Slice 4
                .tabItem { Label("Triage", systemImage: "tray") }
        }
    }
}
```

> Design notes to honor but not solve here: always **launch to Capture** (TabView's
> default first tab is Capture, and we do **not** restore last-used tab). The
> keyboard-occludes-floating-tab-bar wrinkle (nav doc §2 "One honest wrinkle") is
> expected and intentional — dismiss keyboard to reveal the tab bar. No code needed
> to "fix" it.

**`TriageStubView` (throwaway):** minimal — a `List` over `@Query`
sorted-by-`createdAt` notes showing body preview + relative time, and the count.
Mark it clearly in-file as temporary. It has **no** swipe actions, editor, or
lifecycle — those are Slice 4, which *replaces* this file.

### The `VaultProofView` harness and the Talon core

- **`VaultProofView` is no longer the app root.** Recommendation: **park it** —
  remove it from the view tree (RootView replaces it) but **keep the file in the
  repo, unreferenced**, as a manual on-device Talon probe until Slice 6 builds the
  real vault-setup + export surface. (Deleting is also defensible since git
  preserves it; parking is lower-friction because Slice 6 reuses the exact
  pick→bookmark→write pattern. Owner's call — see §7.)
- **`Jackdaw/Talon/` is untouched by this slice.** Capture persists to SwiftData
  only; nothing here reads or writes the vault. Export/Talon re-enters at Slice 5/6.

---

## 4. Capture flow architecture (honoring the design spec)

### The MVVM ↔ SwiftData reconciliation — the real architectural call

**The tension (teach the owner):** SwiftData's ergonomic entry points — `@Query`
(a live fetch) and `@Environment(\.modelContext)` — are **SwiftUI property
wrappers that only work inside a `View`**. `@Query` in particular hooks into
SwiftUI's dependency-tracking so the view re-renders when the data changes — it is
the moral equivalent of a live `useQuery`/`useLiveQuery` hook wired into the
framework's render loop. You **cannot** hoist `@Query` into a plain view-model
object without losing that reactivity and re-implementing observation by hand.
Strict "all data access lives in the ViewModel" MVVM therefore *fights the
framework* here.

**Recommendation — "views own reads; a thin view-model owns write commands":**
this is the pragmatic MVVM that CLAUDE.md actually asks for (MVVM as the
*pragmatic* default, defer heavier patterns), not a cargo-culted one.

1. **Reads stay in the View via `@Query`.** The Triage list (Slice 4; the stub
   this slice) declares `@Query(sort: \Note.createdAt, order: .reverse) var notes`.
   Do not launder reads through a VM — that discards SwiftData's automatic
   invalidation and adds boilerplate and bugs. This is the Apple-idiomatic path.
2. **Writes/business logic go through a small, testable view-model** that is
   **not** SwiftUI-coupled. It receives a `ModelContext` (injected, not reached
   from the environment) and owns *how* a note is built and validated — the logic
   worth unit-testing, and where Slice 3's location orchestration will live.
3. **`modelContext` injection:** the View reads `@Environment(\.modelContext)` and
   hands it to the view-model per call. The view-model never imports SwiftUI /
   never touches the environment → it stays a plain, off-device-testable type.

Why this respects MVVM's *intent* (separation + testability) without the dogma:
business logic (validation, note construction, later async location backfill) is
isolated in a plain type you can test; the View holds only transient UI state and
the framework-native read. This is the least-boilerplate arrangement that keeps
logic auditable.

### `CaptureViewModel`

```swift
import Foundation
import SwiftData

@Observable        // Observation framework; no SwiftUI import needed here.
final class CaptureViewModel {
    /// Persists a note immediately. Returns the inserted note so callers
    /// (Slice 3) can enrich it asynchronously. Does NOT block on anything.
    @discardableResult
    func save(text: String, in context: ModelContext) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }      // no blank notes
        let note = Note(body: trimmed)
        context.insert(note)
        // No explicit save() call needed for the happy path: SwiftData autosaves
        // the main context. (If we want a hard guarantee, `try? context.save()`.)
        return note
    }
}
```

> **Seam contract honored (build-order reconciliation + design flow §1 "GPS
> timing"):** `save` persists the note **synchronously, before any GPS fix**, and
> **returns the note**. At Slice 3, capture will (a) call `save(...)`, then (b)
> kick off an async location fetch and set `note.latitude/longitude` on the *same*
> context when the fix arrives — the note is never blocked on location. The
> signature is shaped for that now; **do not** add an `await` in the capture path.

### `CaptureView`

Behavior, per design flow §1 and nav inventory screen #1:

- **Launch to Capture, keyboard up.** Use `@FocusState` and set it `true` on
  appear. iOS gotcha to expect: focusing *immediately* in `.onAppear` is sometimes
  dropped; the reliable pattern is to set focus in a `.task { }` (or a
  `DispatchQueue.main.async`) so it runs after the first layout. Note it so it
  doesn't read as flaky.
- **Full-bleed editor, no border, no card.** Use `TextEditor` (not a bordered
  `TextField`). Design is explicit: this must **not** look like a web `<textarea>`
  + submit. iOS gotcha: **`TextEditor` has no placeholder** — overlay a `Text`
  ("What's on your mind?") shown only when the body is empty.
- **Return inserts a newline** (default `TextEditor` behavior — do **not** remap
  Return to save; multi-line notes need line breaks).
- **Save is an explicit primary button** in the top bar (a `Save` / up-chevron),
  **disabled while empty** (`text.trimmed.isEmpty`). Not Return, not auto-save.
- **On Save:** call `viewModel.save(text:in:context)`; then **clear the field**,
  **keep focus** (ready for the next thought — rapid multi-capture is first-class),
  and give a **quiet confirmation** (subtle checkmark and/or a light save haptic
  via `UINotificationFeedbackGenerator`/`.sensoryFeedback`). **Stay on Capture** —
  do not navigate to Triage.

Sketch of the essentials (not the full view):

```swift
struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var viewModel = CaptureViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        // full-bleed TextEditor + empty-state placeholder overlay,
        // toolbar Save button: disabled(text.trimmed.isEmpty),
        // action: { viewModel.save(text: text, in: context); text = ""; focused = true }
        // .task { focused = true }
    }
}
```

**Uncommitted text is intentionally not persisted** on background/kill (design
chose explicit save; no draft-autosave in v1). Flagging so it's a *decision*, not
an oversight — if the owner wants crash-safety for in-progress text later, that's a
separate, additive feature.

---

## 5. "Works offline / queues locally" — what it actually means here

**Almost nothing to build — and that's correct.** SwiftData is **local-first**:
the store is an on-device file inside the app container. The capture write path
**touches no network at all**, so "works offline" is satisfied *by construction* —
there is no connectivity check, no reachability monitor, no retry, because there is
nothing here that could fail on the network.

"Queues locally" at this slice = notes simply accumulate as rows in the local
store. The *queue that involves the network* (the export queue: `kept → pending →
writing → confirmed`) is a **Slice 5/6 concern** and is explicitly not here.

**Do not over-build:** no `NWPathMonitor`, no offline banner, no sync scaffolding.
The only thing to *preserve* is that the capture path never introduces a network
dependency (it doesn't). Offline needs no special test beyond confirming capture
works with the simulator offline (it will, trivially).

---

## 6. Testing plan

**Keeper vs. throwaway discipline:** `Note`, `CaptureViewModel`, and `CaptureView`
are keepers. `TriageStubView` is throwaway (replaced Slice 4). `VaultProofView`
parked.

### Unit-testable off-device (Swift Testing — the keeper tests)

Use an **in-memory SwiftData container** so model + save logic run fast, on any
machine, without the simulator UI or touching disk:

```swift
func makeInMemoryContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Note.self, configurations: config)
    return ModelContext(container)
}
```

Tests worth writing:
- **`CaptureViewModel.save` happy path:** non-empty text → exactly one `Note`
  inserted; `body` equals the trimmed text; `createdAt` is ~`.now`; `id` is set.
  (Fetch with a `FetchDescriptor<Note>` and assert count == 1.)
- **Empty/whitespace guard:** `"   \n"` → returns `nil`, inserts nothing.
- **Trimming:** leading/trailing whitespace is stripped from the stored `body`.
- **Multiple saves accumulate:** three saves → three distinct notes with distinct
  `id`s.

### Needs the simulator (manual / UI)

Only what genuinely depends on the running UI or the on-disk store:
- **Keyboard-up-on-launch**, focus behavior, the full-bleed editor feel, Save
  enable/disable, field-clears-and-refocuses, the confirmation haptic/checkmark.
- **Persistence across relaunch** — the real proof SwiftData wrote to disk:
  capture a note → (via the Triage stub) confirm it's listed → **stop and relaunch
  the app** → confirm it's still listed. Unlike Slice 1's bookmark, this needs no
  physical device — there's no sandbox-crossing or entitlement, it's all in our own
  container, so the **simulator is sufficient**.

---

## 7. Open confirmations before implementation

1. **Tab shell now?** I recommend **yes** (real `Capture | Triage` shell with a
   throwaway Triage stub that doubles as the persistence probe). Confirm, or say
   "capture-only until Slice 4" if you'd rather stay minimal.
2. **Model fields — defer location + status to their slices?** I recommend **yes**
   (§2), relying on SwiftData additive lightweight migration + store-reset
   pre-release. Confirm you're comfortable *not* pre-adding those fields.
3. **`VaultProofView`:** park (keep unreferenced) vs. delete. I recommend **park**
   until Slice 6 supersedes it. Either is fine.
4. **Uncommitted capture text is intentionally not draft-saved** on background/kill
   (design's explicit-save choice). Confirm that's acceptable for v1.

## Related
- Design capture flow: `docs/design/capture-and-triage-flows.md` §1
- Design nav + screens: `docs/design/navigation-and-screen-inventory.md` §2–3
- ADR 0003 (SwiftData): `docs/adr/0003-persistence-swiftdata.md`
- Build order (Slice 2 in sequence): `docs/build-order.md`
- Talon core (untouched here): `Jackdaw/Talon/`
