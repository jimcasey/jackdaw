# Slice 2 — Thin capture + SwiftData

> **Status:** Implementation spec, ready to build. **Revised 2026-07-14** after
> owner arbitration: capture is now **autosave-as-you-type** (not explicit-save),
> and the four Slice-2 calls are settled (see §7).
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
- The **Capture** screen: launch-to-capture, keyboard up, full-bleed editor, and
  **autosave-as-you-type** — lazy row creation on the first non-whitespace
  character, debounced autosave on change + on background, and prune-on-abandon of
  empty fragments (§4). No explicit Save button.
- The **two-tab `Capture | Triage` shell** (Triage is a deliberate throwaway stub
  this slice — see §3).
- Swap the app root off `VaultProofView` (park it — §3).

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
        // NOTE: external capture is DEFERRED from v1 (ADR 0005). If/when the
        // fast-follow CaptureNoteIntent is built, this moves to a shared
        // `AppModelContainer.shared` so the intent (running in the app process)
        // uses the SAME store. Not needed in v1.
    }
}
```

`.modelContainer(for:)` creates the container (schema = `Note`), stores it in the
default on-disk location (the app's Application Support directory, inside the
sandbox container), and injects a main-thread `ModelContext` into the SwiftUI
environment. Views read it via `@Environment(\.modelContext)`. No path
configuration needed — this is *our own* container, unrelated to the Talon vault
bookmark (that's a user-picked external folder; this store is internal).

### Nav model: Triage-root + auto-presented Capture sheet (REVISED 2026-07-14)

> **Owner pivoted the nav model.** The two-tab shell is **dropped**. **Triage is the
> app root; Capture is a modal sheet that auto-presents on launch** (user still
> lands ready to type; dismissing the sheet reveals Triage). See
> `docs/feasibility/external-capture-precise-gps.md` and `docs/build-order.md`
> (Slice 2′). This **supersedes** the two-tab decision in design nav doc §2 —
> recommend recording it as **ADR 0004**.

**Why this is better here (and what it fixes for free):**
- **The keyboard-covers-floating-tab-bar bug is fixed by construction.** A sheet
  owns its own keyboard and its own dismissal — there is no floating tab bar hiding
  behind the keyboard, and no "Done button to reveal the tab bar" handling needed.
  That whole wrinkle is **moot**.
- **"Leaving Capture" becomes a single, deterministic event** — the sheet's
  `onDismiss` — which **removes the earlier `.onDisappear`/tab-switch prune-trigger
  reliability risk** (§4). Prune now fires on sheet dismissal + `scenePhase`
  background.

```swift
struct RootView: View {
    @State private var showCapture = true          // auto-present on launch
    var body: some View {
        TriageRootView()                           // the app root (read-only list this slice)
            .sheet(isPresented: $showCapture, onDismiss: { /* Capture VM finishEditing runs in CaptureView */ }) {
                CaptureView()                      // sheet content; owns its keyboard
            }
    }
}
```

- **Auto-present on launch** (`showCapture = true` initially) → the user still lands
  ready to type. Endgame (owner, post-v1): once external capture surfaces exist
  (fast-follow, ADR 0005) to seed the inbox, **stop
  auto-presenting** → the app opens to a bare Triage root and Capture is reached
  deliberately. That toggle is a one-line change; keep it a single source of truth.
- `CaptureView` gains a dismiss affordance (grabber + a Cancel/Done); the autosave
  model (§4) is otherwise unchanged.

**`TriageRootView` (read-only this slice — becomes the real inbox at the Triage slice):**
also solves the verification gap. Capture shows no list by design (funnel ethos), so
the Triage root is where you *see* persistence: a `List` over
`@Query(sort: \Note.createdAt, order: .reverse)` showing body preview + relative
time. **No** swipe actions / editor / lifecycle yet — those arrive at the Triage slice,
which grows (not replaces) this view. Dismiss the Capture sheet → see the note in
Triage → relaunch → still there = the Slice-2′ acceptance check.

### The `VaultProofView` harness and the Talon core

- **`VaultProofView` is no longer the app root** (RootView replaces it).
  **Parked** (owner-confirmed): keep the file unreferenced as a manual on-device
  Talon probe until the Obsidian export slice builds the real vault-setup +
  export surface.
- **`Jackdaw/Talon/` is untouched by this slice.** Capture persists to SwiftData
  only; nothing here reads or writes the vault. Export/Talon re-enters at the
  export slices (Apple Notes / Obsidian).

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

### The autosave model (owner-confirmed — this replaces explicit-save)

Capture **autosaves as you type**. There is **no Save button**. Three rules, all
owned by the `CaptureViewModel`:

1. **Lazy row creation** — the `Note` row is created on the **first
   non-whitespace character**, *not* on field focus. Opening Capture and leaving
   without typing creates nothing.
2. **Autosave on change (debounced) + on background** — nothing is ever lost to a
   background/kill.
3. **Prune-on-abandon** — an empty/whitespace-only body when **leaving Capture**
   (tab switch, background, or the user clearing the field and leaving) deletes the
   row, so fragments never reach Triage.

### `CaptureViewModel` — owns the create / update / prune lifecycle

The view-model holds a reference to the **current draft note** and an injected
`ModelContext` per call. It never imports SwiftUI, so all of this logic is
off-device unit-testable (§6).

```swift
import Foundation
import SwiftData

@Observable                       // Observation framework; no SwiftUI import.
final class CaptureViewModel {
    /// The row currently being edited, if one exists yet. `nil` = no keystroke
    /// with content has happened since the last time we left Capture.
    private(set) var draft: Note?

    /// Called on every text change (`.onChange(of: text)`). In-memory only —
    /// disk persistence is handled by SwiftData autosave + the background flush.
    func edit(_ text: String, in context: ModelContext) {
        if draft == nil {
            // Rule 1: lazy create on the FIRST non-whitespace character.
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            let note = Note(body: text)
            context.insert(note)
            draft = note
            // (Slice 3 hook: kick off the async location request bound to THIS
            //  note instance here — see the seam-contract note below.)
        } else {
            draft?.body = text        // mutate in place; SwiftData tracks it
        }
    }

    /// Called when leaving Capture (tab switch / disappear) AND on background.
    /// Rule 3: prune an empty draft; otherwise the note stays (committed to the
    /// inbox). Idempotent — safe to call twice (e.g. onDisappear + scenePhase).
    func finishEditing(in context: ModelContext) {
        guard let note = draft else { return }
        if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(note)                 // prune fragment
        }
        draft = nil                              // detach: next keystroke = fresh row
        try? context.save()                      // Rule 2: durability guarantee
    }
}
```

> **Factor note construction + persistence into a `CaptureService` (ADR 0005).**
> The `context.insert(Note(...))` / delete / save primitives above should live in a
> small **`CaptureService`** (no SwiftUI, no AppIntents imports) that
> `CaptureViewModel` calls — e.g. `service.insertNote(text:in:)`,
> `service.prune(_:in:)`. In v1 this is justified purely by **in-app** use: it keeps
> the SwiftData details in one testable place. It is *also* the shared core a
> **fast-follow** external `CaptureNoteIntent` will reuse (external capture is
> deferred entirely from v1 — ADR 0005), so building the seam now costs nothing extra
> and avoids a later re-architecture. Do **not** build any external front-end or
> App-Intent code in v1.

**Why `draft = nil` on leave (and what it means for the UX):** once you have typed
content and you leave Capture, that note is **committed to the inbox** (it will
appear in Triage), and returning to Capture gives you a **fresh empty field** —
the next keystroke starts a new row. This is the simplest model and it satisfies
"nothing is ever lost" (a non-empty note is saved, not discarded). Whether leaving
mid-edit should instead **resume the same draft** is a genuine UX fork that
**design-lead owns** — see §7. The view-model above implements *commit-and-fresh*;
if design specifies *resume-draft*, the change is localized (don't null `draft` on
a non-background leave) — flag it, don't silently diverge.

> **Seam contract still honored (build-order reconciliation + design flow §1 "GPS
> timing"):** the note is created **synchronously in `edit(...)`, before any GPS
> fix**, and we hold a reference to it. At Slice 3 the location request is kicked
> off **at the create step, bound to that specific `Note` instance**, and the fix
> is written onto *that* instance when it arrives — even if the user has already
> moved on and `draft` has detached. So backfill lands on the correct row with **no
> rewrite** of this path, and the capture path never `await`s location.

### Debounce vs. SwiftData autosave — the interaction to get right

This is the main new implementation subtlety. SwiftData's **main context autosaves
by default** (`autosaveEnabled == true`): mutating `note.body` marks the context
dirty and the framework coalesces disk writes for you. So:

- **Recommended: do NOT call `context.save()` on every keystroke.** Per-keystroke
  `save()` is disk I/O per character = jank, and it fights the built-in autosave.
  Rely on autosave for the "as-you-type" coalescing, and add **one explicit
  `try? context.save()` on the `.background` transition** as the hard durability
  guarantee (in `finishEditing`). That combination *is* the "debounced autosave +
  on background" the owner asked for, with the framework doing the debounce.
- **If** on-device testing shows autosave latency is too loose for comfort, add a
  lightweight explicit debounce (a cancel-and-reschedule `Task` that sleeps ~0.5s
  after the last keystroke, then `try? context.save()`), and **disable the built-in
  autosave** (`context.autosaveEnabled = false`) so the two mechanisms don't
  double-save and race. Pick one owner of the save cadence; do not run both
  hand-rolled and built-in autosave at once. Default to built-in; only reach for
  the manual debounce if needed.

### `CaptureView` — triggers wired to the view-model

Behavior per design flow §1 and nav inventory screen #1:

- **Launch to Capture, keyboard up.** `@FocusState` set `true` in a `.task { }`
  (not `.onAppear` — focusing immediately on appear is unreliably dropped; running
  it as a task after first layout is the robust pattern).
- **Full-bleed editor, no border, no card.** `TextEditor`, not a bordered
  `TextField` (design forbids the web `<textarea>` look). iOS gotcha: `TextEditor`
  has **no placeholder** — overlay a `Text` ("What's on your mind?") shown only
  when empty.
- **Return inserts a newline** (default `TextEditor` behavior; do not remap).
- **No Save button.** The triggers instead:
  - `.onChange(of: text)` → `vm.edit(text, in: context)` (create/update).
  - `.onChange(of: scenePhase)` where new phase `== .background` →
    `vm.finishEditing(in: context)` (durability save + prune). Swipe-kill from the
    app switcher happens *after* `.background`, so this flush covers it.
  - **Leaving Capture = the sheet is dismissed** (swipe-down or Cancel/Done). Fire
    `vm.finishEditing(in: context)` from the sheet's **`onDismiss`** callback (and
    clear `text`). Under the revised nav model (§3) this is a **single deterministic
    event** — the earlier `TabView` `.onDisappear` reliability concern is gone. (If
    `CaptureView` needs to self-trigger before the sheet animates away, `.onDisappear`
    on the sheet content also works; `finishEditing` is idempotent, so both firing is
    safe.)

Sketch of the essentials (not the full view):

```swift
struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var vm = CaptureViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        // full-bleed TextEditor bound to $text + empty-state placeholder overlay
        //   .focused($focused)
        //   .onChange(of: text)      { _, new in vm.edit(new, in: context) }
        //   .onChange(of: scenePhase){ _, p  in if p == .background { vm.finishEditing(in: context) } }
        //   .onDisappear             { vm.finishEditing(in: context); text = "" }
        //   .task                    { focused = true }
    }
}
```

> No explicit "field clears + haptic confirmation on save" step anymore — with
> autosave there is no discrete save event to confirm. The field only clears when
> you *leave and return* (commit-and-fresh). Rapid multi-capture in a single
> Capture session is now "type a thought, and it's saved" continuously; if design
> wants a per-thought separator gesture (e.g. a "new note" affordance to split one
> Capture session into multiple notes without leaving), that is a design call
> (§7) — the current model treats one continuous Capture session as one note.

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

The autosave lifecycle is deterministic and lives entirely in the view-model, so
it tests cleanly by driving `edit` / `finishEditing` against an in-memory context
and fetching with a `FetchDescriptor<Note>`:

- **Lazy create (Rule 1):** `edit("")` and `edit("   ")` → **zero** rows inserted,
  `draft == nil`. `edit("h")` → **one** row, `draft != nil`, `body == "h"`.
- **Whitespace-then-content:** `edit(" ")` (no row) → `edit(" a")` → exactly one
  row created (first non-whitespace char triggers it).
- **Update in place:** `edit("h")` then `edit("hello")` → still **one** row, its
  `body == "hello"` (not a second row).
- **Prune-on-abandon (Rule 3):** `edit("h")` then `edit("")` then
  `finishEditing()` → **zero** rows (empty draft pruned), `draft == nil`.
- **Commit non-empty:** `edit("keep me")` then `finishEditing()` → **one** row
  survives, `draft == nil` (detached / committed).
- **Idempotent finish:** calling `finishEditing()` twice in a row does not crash
  and does not double-delete (guards on `draft`).
- **Fresh session after commit:** `edit("one")`, `finishEditing()`, then
  `edit("two")`, `finishEditing()` → **two** distinct rows with distinct `id`s.

### Needs the simulator (manual / UI)

Only what genuinely depends on the running UI or the on-disk store:
- **Keyboard-up-on-launch**, focus behavior, the full-bleed editor feel, the
  placeholder overlay showing/hiding.
- **Autosave durability across relaunch** — the real proof SwiftData wrote to disk
  *without* an explicit save: type a note → **do not** do anything else → send the
  app to background (Home / app switcher) → **stop and relaunch** → switch to the
  Triage stub → confirm the note is listed. Then repeat but **swipe-kill** from the
  app switcher to confirm the `.background` flush caught it.
- **Prune-on-abandon** — type a character then delete it back to empty → switch to
  Triage → confirm **no** empty row appears. And: type content, switch to Triage,
  switch back → confirm a **fresh** field and the note is in Triage (commit-and-fresh).
- Unlike Slice 1's bookmark, none of this needs a physical device — no
  sandbox-crossing or entitlement, it's all our own container, so the **simulator
  is sufficient**.

---

## 7. Settled decisions & the design-alignment items

**Owner-arbitrated 2026-07-14 (the four Slice-2 calls — now settled, not open):**
1. **Two-tab `Capture | Triage` shell is built now**, Triage a throwaway stub that
   doubles as the persistence-verification list. (§3)
2. **Location (Slice 3) and status (Slice 4) fields are deferred** — Note stays
   minimal; rely on additive lightweight migration + pre-release store reset. (§2)
3. **`VaultProofView` is parked** (unreferenced; Talon core untouched). (§3)
4. **Capture is autosave-as-you-type**, replacing the explicit-save model:
   lazy row creation on first non-whitespace char, debounced autosave + background
   flush, prune-on-abandon of empty fragments. (§4)

**Design-alignment items (design-lead is updating its capture-flow doc in
parallel; the save-path mechanics depend on these UX calls — align to design, flag
disagreement, do not silently diverge):**

- **Rapid multi-capture within one session** (design flow §1.5: "throw in three
  thoughts in a row"). The autosave model as specified treats **one continuous
  Capture session as one note** — the field only resets on leave-and-return. If the
  owner/design still want three-in-a-row *without leaving Capture*, we need an
  **in-session "new note" trigger** (e.g. a small "+"/new affordance, or a
  double-return convention). This is the sharpest interaction change the autosave
  override introduces vs. the current design doc; it needs a design ruling. The
  view-model supports it trivially (call `finishEditing` then clear the field on
  that gesture) — but the *gesture* is design's to define.
- **Leave-mid-edit semantics:** *commit-and-fresh* (implemented) vs. *resume the
  same draft* on return. (§4 "Why `draft = nil` on leave".)
- **Prune trigger reliability:** the exact leave events that must prune
  (tab-switch, background, field-cleared-then-leave). If design's updated flow adds
  or removes a leave path, the `finishEditing` call sites must match it. The
  `.onDisappear` vs. `selection`-binding choice (§4) is an implementation detail
  under whatever leave-set design specifies.
- **Discard-undo fork (Slice 4, still parked):** unaffected mechanically by this
  slice, but note the autosave model *strengthens* the "nothing is lost" posture at
  capture, which is adjacent to the undo-banner debate at triage. Still an owner
  call at Slice 4.

## Related
- Design capture flow: `docs/design/capture-and-triage-flows.md` §1
- Design nav + screens: `docs/design/navigation-and-screen-inventory.md` §2–3
- ADR 0003 (SwiftData): `docs/adr/0003-persistence-swiftdata.md`
- Build order (Slice 2 in sequence): `docs/build-order.md`
- Talon core (untouched here): `Jackdaw/Talon/`
