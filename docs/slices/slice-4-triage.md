# Slice 4 — The real Triage inbox

> **Status:** Implementation spec, ready to build. **Date:** 2026-07-14.
> **Owner of spec:** tech-lead. **Implements:** build-order's Triage slice (the
> "real Triage" that grows `TriageRootView` from a read-only list into the inbox).
> **Prereq met:** the sheet-model capture rework is done and verified —
> Triage-root + auto-presented Capture sheet, `CaptureService` seam, 18 tests green.
> **Verify on:** Simulator is sufficient (no entitlement / device-only behavior).
>
> **Numbering note:** implementation numbering runs one ahead of the at-a-glance
> table in `docs/build-order.md` (the sheet-capture rework became its own slice).
> This is *the* Triage slice regardless of index; it precedes Location, Apple
> Notes, and Obsidian export.

`TriageRootView` **grows** into this — do not rewrite it. It is currently a
read-only `@Query` list (`Jackdaw/TriageRootView.swift`); this slice adds the
lifecycle `status`, swipe actions, the snooze model, light editing, and the empty
state.

---

## 1. Note model extension — the lifecycle `status`

Add the retention state **additively** (per ADR 0003's deferral plan: optional /
defaulted properties → SwiftData automatic lightweight migration; pre-release we
can also just reset the store). This slice adds three fields to `Note.swift`.

### The `status` enum shape (recommended)

```swift
/// Where a note sits in the funnel. This slice implements `inbox`, `snoozed`,
/// `kept`. The export slices EXTEND this enum with `pending`, `writing`,
/// `confirmed` (the ADR 0001 retention machine) — add cases there, do not fork a
/// second enum. Adding an enum case is not a schema change (the stored column is a
/// String), so it needs no migration.
enum NoteStatus: String, Codable, CaseIterable {
    case inbox      // un-triaged; in the batch
    case snoozed    // deferred; reappears a later calendar day (§3)
    case kept       // kept-for-export; awaits the export pipeline (export slices)
}
```

### The fields on `Note`

```swift
// --- added at the Triage slice (all defaulted/optional → lightweight migration) ---
private var statusRaw: String = NoteStatus.inbox.rawValue
var snoozedUntil: Date?          // absolute reappear boundary; nil unless snoozed
var snoozeCount: Int = 0

var status: NoteStatus {
    get { NoteStatus(rawValue: statusRaw) ?? .inbox }
    set { statusRaw = newValue.rawValue }
}
```

**Why store `statusRaw: String` + a computed `status`, not the enum directly**
(owner, new to iOS): SwiftData's `#Predicate` (used to drive the inbox query,
§6) compiles to a restricted expression form that reliably compares **stored
primitives** (String/Int/Date) but has historically been flaky with custom enum
types. Storing the raw String and comparing *that* in predicates is the robust,
well-trodden SwiftData pattern; app code still uses the typed `status`. Bonus: the
raw value is human-readable in the store when debugging. (On iOS 26 the direct-enum
form may work, but the raw approach removes the risk for zero cost.)

### Reconciliation with the export retention machine + `ExportFailure`

Two orthogonal axes — do not conflate them:
- **`status`** = *where* the note is: `inbox → snoozed → kept` (this slice) then
  `kept → pending → writing → confirmed → deleted` (export slices, ADR 0001).
- **`exportFailure: ExportFailure?`** (added at the **export** slice, not now) =
  *why* a `pending`/failed note is stuck, reusing the existing Talon enum
  (`Jackdaw/Talon/ExportDestination.swift`) — `noVaultConfigured` /`accessLost`
  /`writeFailed`/`verifyMismatch`, extended with `.offline` at export. This matches
  the design-lead's seam contract ("per-note state **and** a failure-reason") and
  the build-order "kept-but-no-destination is a pending *reason*, not an error
  state" (→ `ExportFailure.noVaultConfigured`).

So at export, a note is e.g. `status = .pending, exportFailure = .noVaultConfigured`.
Keeping reason separate from state is what lets the Settings/Status UI show
Retry vs. Re-grant vs. Set-up-vault correctly. **None of that is built this slice**
— we only establish `status` and stop at `.kept`.

> **`.kept` notes with no export yet:** Keep sets `status = .kept`; those notes
> leave the inbox and simply *accumulate* in `.kept` because the export pipeline
> doesn't exist yet. That is correct and expected — the export slice picks them up.
> They are held, not lost.

---

## 2. The three triage actions → transitions

Design-lead's Mail/Reminders swipe idiom (`capture-and-triage-flows.md` §2). Each
action is a `status` transition (or a delete):

| Action | Gesture (design) | Transition |
|--------|------------------|------------|
| **Keep** | leading full-swipe (green, checkmark) | `status = .kept` |
| **Snooze** | trailing swipe → amber `moon.zzz` | `status = .snoozed`; set `snoozedUntil`; `snoozeCount += 1` (§3) |
| **Discard** | trailing full-swipe (red, trash, destructive) | delete — **hard-delete** or **deferred-delete**, per §4 |

Plus (design): **tap row → editor** (§5); **long-press → context menu** with all
three (accessible fallback; swipe actions must also be mirrored as VoiceOver custom
actions). Color is never the only signal — icon + label on every action.

---

## 3. Snooze-session model — made concrete

Design-lead's model (`open-ux-threads.md` Thread 1): *snooze hides a note for the
rest of the current sitting; it reappears at the first Triage open on a **later
calendar day**.* Key realization: **the calendar-day boundary IS the session
boundary** — we need **no session-id field**. "Rest of this session" and "reappears
next calendar day" are the same rule.

### Data + logic (pure, injected-clock-testable)

Store an **absolute reappear boundary** (`snoozedUntil: Date`), computed once at
snooze time as the **start of the next local calendar day**. Querying then never
needs `Calendar` (which can't be called inside `#Predicate`).

```swift
enum SnoozeSchedule {
    /// The instant a note snoozed at `snoozedAt` becomes due again: the start of
    /// the NEXT local calendar day. Calendar is injectable for time-zone tests.
    static func reappearBoundary(snoozedAt: Date, calendar: Calendar = .current) -> Date {
        let startOfSnoozeDay = calendar.startOfDay(for: snoozedAt)
        return calendar.date(byAdding: .day, value: 1, to: startOfSnoozeDay)!
    }
    /// Due once we're at or past the boundary. Plain date compare (no calendar) so
    /// it is predicate-friendly and trivially testable.
    static func isDue(snoozedUntil: Date, now: Date) -> Bool { now >= snoozedUntil }
}
```

Worked example (local time): snooze a note **today at 3:00 pm** → boundary =
**start of tomorrow (00:00)**. Reopen Triage today at 11 pm → `now < boundary` →
still hidden (same sitting). Reopen **tomorrow 9 am** → `now >= boundary` → due,
reappears. Snoozed 3 days ago → long past boundary → due.

**Anti-graveyard nudge (design):** `snoozeCount` increments on each Snooze; the row
surfaces "snoozed N×" once `snoozeCount >= 3` (styling is design polish this slice
just needs to expose the count). Do **not** hard-disable Snooze.

**Known edge (accepted, from design):** snoozing at 11:58 pm returns the note ~2
min later. Negligible for a single user; the drop-in refinement if it ever grates
is a "next 4 am boundary, or ≥6h, whichever is later" rule — **not pre-built**.
Because it lives entirely in `reappearBoundary`, swapping the rule later touches one
pure function.

---

## 4. Discard-undo — the parked tech↔design fork (owner's call)

**The decision (owner):** does full-swipe Discard show a transient **"Note
discarded — Undo"** banner, or delete immediately?

### My recommendation: **adopt the undo banner.** (Framed as the owner's call.)

I previously resisted this as friction and extra state. **I've changed my position,
and here's the honest reason:** the objection was the *cost* (persistent tombstone
state, a purge policy). With the **delayed-delete** implementation below, that cost
evaporates — there is **no schema change and no persistent state**, only transient
in-memory VM state. Meanwhile design's consistency argument is sound: under
autosave, *every* note in Triage is real persisted data from its first character,
so a mis-tapped one-tap Discard destroys a genuine thought — the exact failure the
owner adopted autosave to make structurally impossible at the *capture* end.
Leaving it possible at the *triage* end is an inconsistency. Since the cost I
objected to is gone, I now support the banner. Still your call.

### If adopted — implementation: **deferred-delete in memory** (recommended over a soft-delete tombstone)

- On Discard: the note is **optimistically hidden** (added to a `pendingDiscard`
  set in the view-model) and the banner shows for a few seconds. **The row is not
  deleted from SwiftData yet.**
- **Undo** → remove it from `pendingDiscard`; the note reappears. No delete ever
  happened.
- **Banner expiry** → `context.delete(note)` + save. Now it's gone.

```swift
// in TriageViewModel
private(set) var pendingDiscard: Set<UUID> = []
private var held: [UUID: Note] = [:]

func discard(_ note: Note) { pendingDiscard.insert(note.id); held[note.id] = note }   // hide only
func undoDiscard(_ id: UUID) { pendingDiscard.remove(id); held[id] = nil }             // restore
func commitDiscard(_ id: UUID, in context: ModelContext) {                            // banner elapsed
    guard let note = held[id] else { return }
    context.delete(note); try? context.save()
    pendingDiscard.remove(id); held[id] = nil
}
```

`visibleNotes` (§6) also filters out `pendingDiscard`.

**Why deferred-delete beats a `.discarded` soft-delete tombstone here:**
- No new persistent state, no `discardedAt`, **no purge policy** to design.
- **Kill-safe in the funnel's favor:** if the app is killed *during* the undo
  window, the delayed delete never fires → the note **survives**. For a funnel that
  promises "no lost thoughts," erring toward *keep* on an interrupted discard is the
  right failure mode. A tombstone would instead make the discard durable across a
  kill — the opposite bias.

**Discard *semantics* follow the decision:**
- **Undo adopted →** Discard is a **deferred hard-delete** (no tombstone, no
  `.discarded` status). Window ~3–5 s (owner-tunable).
- **Undo rejected →** Discard is an **immediate hard-delete**:
  `context.delete(note); try? context.save()`.

**A11y (design-owned, flagged):** iOS has no system snackbar, so the banner is a
**custom transient view** — system materials, respects safe areas, and **must be
announced to VoiceOver** (and offer the Undo as an accessible action). This is the
one non-stock component in Triage.

---

## 5. Light note editing (keep it minimal — do not grow a full editor)

Design: **tap a row → push a Note editor** onto the Triage nav stack (drill-in;
back returns to the list), with the three verbs in a bottom bar so you can act
right after editing.

**This slice ships:**
- **Body editing.** The same full-bleed `TextEditor` as Capture, pre-filled and
  editable, bound to `note.body`. SwiftData autosaves the mutation; a `save()` on
  disappear guarantees durability (same pattern as capture). **Plain text only** —
  no markdown/formatting affordances (PRD non-goal); this is a *light* edit, not a
  notepad.
- **The three verbs (Keep / Snooze / Discard) in a bottom bar**, calling the same
  `TriageViewModel` actions; acting pops back to the list.

**Time editing (recommended include — cheap; owner call):** `createdAt` already
exists, so a system `DatePicker` bound to it is a few lines and is explicitly
in-scope ("edit the attached context," PRD §4). I lean **include it**; if you'd
rather keep Slice 4 strictly to body, it's a clean deferral.

**Location editing — deferred to the Location slice.** Location fields don't exist
until then. Leave a **hook**: a `Context` section in the editor with the time row
now and a `// location row — Location slice` placeholder. Design's location row
(place name + static map thumbnail + Clear) lands with the fields.

**Edge:** unlike Capture, the editor does **not** prune an emptied body — if a user
clears a note to empty in Triage it simply remains (degenerate; they can Discard
it). Prune is a *capture-abandonment* rule only.

---

## 6. `TriageRootView` grows into the inbox

**MVVM/SwiftData split (consistent with capture):** reads via `@Query`; write/action
logic + the due-filter in a small `@Observable TriageViewModel` that takes an
injected `ModelContext` per call and an **injected clock** — so the fiddly bits are
unit-testable off-device.

- **`@Query` fetches the candidate set** (reactive): notes with `status ∈ {inbox,
  snoozed}` (excludes `.kept` and, later, the export states). This is the one
  predicate; keep it primitive:
  ```swift
  let inboxRaw = NoteStatus.inbox.rawValue
  let snoozedRaw = NoteStatus.snoozed.rawValue
  @Query(filter: #Predicate<Note> { $0.statusRaw == inboxRaw || $0.statusRaw == snoozedRaw },
         sort: \Note.createdAt, order: .reverse)
  private var candidates: [Note]
  ```
- **The due-filter is a pure VM function** (not in the predicate — this is
  deliberate, so the calendar/`now` logic is injectable and testable rather than
  frozen into a `@Query` at view-init):
  ```swift
  func visibleNotes(_ candidates: [Note]) -> [Note] {
      let n = now()
      return candidates.filter { note in
          if pendingDiscard.contains(note.id) { return false }   // §4 optimistic hide
          switch note.status {
          case .inbox:   return true
          case .snoozed: return note.snoozedUntil.map { SnoozeSchedule.isDue(snoozedUntil: $0, now: n) } ?? true
          case .kept:    return false
          }
      }
  }
  ```
  Recompute on Triage appearance (`.onAppear` / `scenePhase == .active`) by reading
  `now()` fresh — due-ness only changes at day rollover, so no live timer needed.
- **List + swipe actions** on `visibleNotes`: leading full-swipe Keep; trailing
  Snooze + Discard (Discard = destructive full-swipe); long-press context menu with
  all three; row → `NavigationLink` to the editor (§5). Rows show body preview +
  relative time (+ "snoozed N×" when `snoozeCount >= 3`).
- **Wrap in a `NavigationStack`** (Triage is the nav-stack root per the nav doc; the
  editor pushes; a later gear → Settings sheet). `RootView` presents
  `TriageRootView` as today.
- **Title / count** = actionable count = `visibleNotes.count` (excludes not-yet-due
  snoozed), matching design's "badge excludes not-yet-due snoozed."
- **Empty state** (grow the existing `ContentUnavailableView`): when
  `visibleNotes.isEmpty`, show **"Inbox clear."** If there are snoozed-not-due
  notes, add design's quiet count-only line — *"N will return in a later session"* —
  with **no** affordance to open them (snoozed notes are never browsable).

---

## 7. Testing plan

**Off-device (Swift Testing, in-memory `ModelContainer` — the keeper tests).** The
capture pattern already established the in-memory-container harness; reuse it.

- **Status transitions:** `keep` → `.kept`; `snooze` → `.snoozed`, `snoozedUntil`
  set to the next-day boundary, `snoozeCount` incremented (and incremented again on
  a second snooze).
- **Snooze due-logic — inject the clock and calendar; never call `Date()` in the
  assertion path** (that's the nondeterminism trap the coordinator flagged):
  - `reappearBoundary(snoozedAt:)` returns the correct start-of-next-day for a fixed
    input date.
  - `isDue` across a **day rollover**: snoozed at a fixed `T` (3 pm) → not due at
    `T+8h` (11 pm same day); **due** at `T+18h` (9 am next day).
  - **Boundary:** not due one second before the boundary; due exactly at it.
  - **Time zone:** run `reappearBoundary` with an injected `Calendar` in two zones
    to confirm "local day" behavior.
- **Inbox filter:** a mixed set (an `.inbox`, a due `.snoozed`, a not-yet-due
  `.snoozed`, a `.kept`) → `visibleNotes(now:)` returns exactly the inbox + the
  due-snoozed.
- **Undo/discard (if adopted):** `discard` hides but does **not** delete (fetch
  still finds the row; `visibleNotes` excludes it); `undoDiscard` restores it;
  `commitDiscard` deletes it (fetch no longer finds it). **Test `commit`/`undo` as
  directly-callable functions — do not test the wall-clock timer** (structure the
  banner so expiry just calls `commitDiscard`).
- **Discard (if not adopted):** `discard` deletes immediately.

**Simulator acceptance:**
- Capture a few notes (sheet) → land on Triage → they list.
- **Keep** (leading full-swipe) → row leaves; **Discard** (trailing full-swipe) →
  row leaves, undo banner shows, **Undo** restores it; let it expire → gone.
- **Snooze** → row leaves; verify reappearance by **injecting/advancing the device
  date** to the next day and reopening Triage (the day-rollover path can't be waited
  out live — advancing the clock is the manual check).
- **Tap a row** → editor; edit body → back → preview reflects the edit → relaunch →
  persisted.
- Clear the inbox → **"Inbox clear."**; snoozed-not-due notes show the count-only
  line.

---

## Open decisions needing the owner before implementation

1. **Discard-undo banner: adopt or not?** I recommend **adopt** (§4) — with the
   delayed-delete implementation the cost I originally objected to is gone, and the
   autosave consistency argument holds. This determines Discard **semantics**
   (deferred hard-delete vs. immediate hard-delete). Owner's call.
2. **Time editing in the note editor this slice?** Recommend **include** (cheap,
   in-scope); OK to defer to keep the slice tight.
3. **Snooze-count nudge:** confirm surfacing "snoozed N×" at `N ≥ 3` (design
   proposal; product-lead may want it cut). Low cost; recommend keep.

## Related
- Design triage flow: `docs/design/capture-and-triage-flows.md` §2
- Snooze-session model: `docs/design/open-ux-threads.md` Thread 1
- Retention machine + failure taxonomy: `docs/adr/0001-obsidian-write-mechanism.md`,
  `Jackdaw/Talon/ExportDestination.swift`
- Persistence + additive migration: `docs/adr/0003-persistence-swiftdata.md`,
  `docs/slices/slice-2-capture-swiftdata.md` §2
- Grows: `Jackdaw/TriageRootView.swift`, `Jackdaw/Note.swift`
