# Slice 6 — Apple Notes export (intermediate de-risking milestone)

> **Status:** Implemented, pending on-device verify. **Date:** 2026-07-21.
> **Owner of spec:** tech-lead. **Implements:** build-order's **Slice 5 — Apple
> Notes export** (the intermediate export milestone). **Prereq met:** Triage +
> retention `kept` state done; the `ExportDestination` seam + `VaultAccess` +
> `FolderWriter` exist from Slice 1; `Note` carries `latitude/longitude/…`.
>
> **Numbering (read this — it is genuinely confusing):** implementation numbering
> runs **one ahead** of `docs/build-order.md`'s table (the capture rework became its
> own slice). So this is **build-order Slice 5 = implementation Slice 6**. The git
> branch (`claude/slice-5-…`) uses build-order numbering; this spec file uses
> implementation numbering to sit next to `slice-5-location.md`. Same slice, two
> numbers.
>
> **Not a shipped v1 destination** (PRD non-goal, explicit) — a build-order device
> sanctioned by owner arbitration (build-order §"Owner call — RESOLVED"). Its job is
> to de-risk *the export pipeline above the `ExportDestination` seam* against a
> trivial destination, and to prove the seam has **two real adapters**, before
> Slice 7 wires Obsidian's stale-bookmark / coordinator / re-grant complexity.

Owner-settled (build-order): retention is **hold-until-sync-confirmed** (delete only
after a confirmed write); the serializer + state machine built here are **reused
verbatim** by Obsidian (Slice 7).

---

## 0. What ships this slice

| Piece | File | Testable off-device? |
|---|---|---|
| Note **serializer** (markdown + YAML frontmatter) | `Talon/NoteSerializer.swift` | ✅ pure |
| **Retention state machine** (`kept→pending→writing→confirmed→deleted`) | `Talon/RetentionMachine.swift` | ✅ pure |
| **Export coordinator** (drives notes through the machine against a destination) | `Talon/ExportCoordinator.swift` | ✅ in-memory `ModelContext` + mock |
| **Seam evolution** (batch, async, per-note outcome) + `SerializedNote`/`ExportOutcome` | `Talon/ExportDestination.swift` | ✅ types |
| **`AppleNotesDestination`** (share-sheet adapter) | `Talon/AppleNotesDestination.swift` | ❌ device/sim only (UIKit) |
| `Note` export fields (`pending/writing/confirmed`, `exportFailureRaw`) | `Note.swift` | ✅ |
| **Batch-export UX** (outbox count + "Export N to Notes") | `TriageRootView.swift` | ❌ device/sim only |

The value that CI can actually verify is the **core** (serializer + machine +
coordinator). The two device-only pieces are kept deliberately **thin** — the same
discipline as `CoreLocationProvider`/views over `CaptureService`/`FolderWriter`.

---

## 1. The seam decision — why `ExportDestination` changed shape

Slice 1 proved a **synchronous, per-file** write (`ObsidianFolderDestination`). Apple
Notes does not fit that shape: its only practical write path is the **share sheet**
(`UIActivityViewController`), which is **interactive**, **async**, presented **once
for a batch**, and **cannot report** whether "Save to Notes" actually succeeded.
Forcing that through `export(fileName:markdown:) throws` would be dishonest (a
per-note synchronous "write" that neither writes nor confirms).

So the seam evolves — the protocol comment always anticipated the state machine
sitting *above* it — to:

```swift
protocol ExportDestination {
    @MainActor func export(_ notes: [SerializedNote]) async -> [ExportOutcome]
}
```

- **Batch** — Apple Notes presents **one** share sheet for the whole Kept set (the
  funnel's "clear the inbox in one action"); Obsidian just loops and writes each
  file. One shape, both adapters.
- **Async + `@MainActor`** — the share sheet is presented on the main actor and its
  completion awaited; main-actor confinement also sidesteps `Sendable` friction
  across the seam. (Obsidian's file I/O runs on main here too — acceptable for this
  milestone; Slice 7 can offload it if profiling says so.)
- **Per-note `ExportOutcome`** (`.confirmed(id:)` / `.failed(id:, reason:)`) — a
  batch can **partially** succeed (one file lands, another hits a stale bookmark).
  The coordinator confirms/deletes the winners and returns the losers to `pending`
  **with a reason**, honoring the Slice 4 failure-reason contract.

`ObsidianFolderDestination` is updated to conform (one `withVaultURL` for the batch,
`writeAndVerify` per note) — **reusing `VaultAccess`/`FolderWriter` verbatim**. The
parked Slice 1 harness (`VaultProofView`) is updated to the new call; it remains
throwaway (deleted at Slice 7).

`ExportFailure` becomes `String`-backed so a note's failure **reason** can be
persisted (`Note.exportFailureRaw`) and survive relaunch.

---

## 2. The serializer — `NoteSerializer` (pure, reused by Obsidian)

Turns a `NoteSnapshot` (a plain, SwiftData-free copy of the note fields — keeps the
serializer trivially testable and free of the SwiftData import) into a
`SerializedNote { id, fileName, markdown }`.

**Markdown = YAML frontmatter + blank line + raw body:**

```
---
created: 2027-01-15T08:00:00Z
latitude: 51.500000
longitude: -0.120000
accuracy_m: 5.000000
place: "Primrose Hill"
---

<the note body>
```

- `created` is **ISO-8601, UTC** (`withInternetDateTime`).
- Location keys are **omitted entirely** when the note has no coordinate (a
  timestamp-only note stays clean — matches the Location slice's "omit or null").
- Coordinates use `String(format: "%.6f", …)` — **locale-independent**, so a
  comma-decimal device can't emit `-0,120000` and corrupt the YAML.
- `place` (the lazily-geocoded name, if present) is **always double-quoted and
  escaped**, so a `:` / `#` / leading `-` in a place name can't break the frontmatter.

**Filename:** `yyyy-MM-dd-HHmmss-<8-hex-of-id>.md` (UTC). The timestamp reads/sorts
naturally in Obsidian; the id suffix **guarantees uniqueness** so two notes captured
in the same second don't overwrite each other (the atomic write would otherwise
clobber the first — real data loss).

All formatters are fixed (`en_US_POSIX`, UTC) → deterministic output, directly
assertable in tests, stable across CI machines.

---

## 3. The retention machine — `RetentionMachine` (pure, reused by Obsidian)

```
kept → pending → writing → confirmed → deleted
         ▲          │
         └──────────┘  (any failure → pending, carrying a reason)
```

A **pure, total** transition function (`next(state, event) -> state`) kept **distinct
from the flat persisted `NoteStatus`** so the transitions are exhaustive and testable
with zero SwiftData. Illegal `(state, event)` pairs are **no-ops** — a caller can't
corrupt a note by firing events out of order.

**Cardinal rule (ADR 0001):** a note is deleted **only** out of `.confirmed`. Every
failure routes back to `.pending`, so a thought is never lost — kill-safe toward
*keep*. `.pending` carries an optional `ExportFailure` reason (nil = simply queued).

`Note` maps persistence ↔ machine: `status ∈ {kept, pending, writing, confirmed}`
plus `exportFailureRaw`, exposed as `note.retentionState`.

---

## 4. The coordinator — `ExportCoordinator` (SwiftData glue)

`@MainActor` (mutates the main `ModelContext`, awaits the main-actor destination).
`exportAll(in:)`:

1. **Fetch** exportable notes: `status == kept || status == pending` (a prior failure
   is retried automatically). `inbox`/`snoozed` are never touched.
2. `kept/pending → writing` for each, **and save before the write** — a mid-export
   kill leaves notes as `writing` (recoverable), never silently lost.
3. **Serialize** the batch and hand it to `destination.export(_:)`.
4. Fold each `ExportOutcome` back through the machine:
   - `.confirmed` → `confirm` → `commit` → **row deleted**; count it.
   - `.failed(reason)` → `fail(reason)` → back to `pending`, **reason persisted**.
5. Save; return the confirmed count.

`exportableCount(in:)` backs the outbox badge.

The pre-write `save()` is do/`catch`, not `try?`: if it fails, the kill-safety
guarantee is void, so the coordinator rolls back the `.writing` marks (leaving the
notes `.kept` and exportable) and aborts rather than exporting un-persisted notes.

> **Transient states — now reconciled at launch (follow-up to the original slice).**
> Only `.writing` can survive a kill: `.confirmed` never does, because confirm →
> commit → delete all happen inside one `save()`, so a `.confirmed` row is gone in the
> same transaction it appears. A note killed mid-`writing` (the Apple Notes share sheet
> can sit open indefinitely) would otherwise be **invisible on every surface** —
> excluded from the outbox (`kept||pending`) *and* Triage (`inbox||snoozed`), not
> merely "invisible in the outbox." `ExportReconciler.reconcileInterruptedWrites`,
> called once from `RootView` at launch, requeues any such note `writing → pending(nil)`
> (the machine's `.interrupt` transition — a reason-less recovery, not a failure) so it
> reappears in the outbox. Reused by Slice 7 on the verifiable Obsidian path.

---

## 5. `AppleNotesDestination` — the share-sheet adapter (device/sim only)

Joins the batch's markdown into one payload and presents `UIActivityViewController`
from the top-most view controller, suspending on a continuation until its completion
handler fires.

**DEGRADED confirm — stated plainly (ADR 0001, Candidate A):** the share sheet
reports only *completed vs cancelled*, not *did Notes actually save*. So for this
milestone **completion = `confirmed`** for every note, **cancel = retryable
`writeFailed`**. That is acceptable *because the milestone's purpose is to exercise
the pipeline and the seam*, not to be a trustworthy retention path. **Apple Notes is
scaffolding; Obsidian (Slice 7) is the verifiable path** (write-then-read-back).

---

## 6. Batch-export UX (`TriageRootView`, device/sim only)

- A second `@Query` (the **outbox**: `kept || pending`) drives a leading toolbar
  button **"Export N to Notes"** (`square.and.arrow.up`), shown only when N > 0 —
  when the funnel is clear the affordance disappears (on-brand: empty and honest).
- Tap → `ExportCoordinator(destination: AppleNotesDestination()).exportAll` →
  confirmed notes leave the app; any failures **stay in the outbox** (their count
  persists — honest). A VoiceOver announcement reports the confirmed count.
- Any in-flight discard is committed first, so it isn't stranded behind the sheet.

---

## 7. Testing plan

**Off-device (Swift Testing) — `JackdawTests/ExportTests.swift`:**
- **Serializer:** frontmatter has `created` + body; location keys **omitted** when
  absent and **present + locale-independent** when set; `place` quoted/escaped;
  filename is `stamp-<id8>.md` and **unique** for distinct ids at the same instant.
- **Machine:** every legal transition; illegal pairs are no-ops (esp. **no delete
  before confirm**).
- **Coordinator** (in-memory container + `MockDestination`): all-confirmed → all
  deleted; **partial failure** → failed note stays `pending` **with reason**, others
  deleted; `inbox`/`snoozed` ignored; a prior `pending` note is **retried**; empty
  outbox is a no-op; body+location reach the serialized payload; `exportableCount`.
- **`Note`:** new status rawValues match the `@Query` literals; `exportFailure`
  round-trips through `exportFailureRaw`; `retentionState` maps from status.
- **Reconciler** (post-merge follow-up): a `.writing` note is requeued `→ pending`
  (reason-less) while others are untouched; idempotent. Machine `.interrupt`:
  `writing → pending(nil)`. Coordinator ordering: notes are persisted `.writing`
  **before** the destination is awaited.
- **`ObsidianFolderDestination`** (Slice 7's real path, off-device): `writeBatch`
  all-success and one-bad-filename partial (temp dir + real `FolderWriter`);
  no-vault → whole batch `.failed(.noVaultConfigured)`.

**Needs the simulator / device (owner checks):**
- The **share sheet** actually presents from Triage; picking Notes creates a note;
  **cancel** leaves the batch in the outbox (all `pending`).
- A frontmatter'd note (time + GPS) lands in Notes; a timestamp-only note has no
  location keys.
- The outbox badge count updates as notes are kept and as they export/leave.

---

## 8. Decisions — SETTLED

1. **Seam shape = batch / async / per-note outcome** (§1). The honest fit for an
   interactive batch destination *and* a per-file one; Obsidian reuses it.
2. **Degraded confirm for Apple Notes** (§5) — completion = confirmed. Milestone
   scaffolding only; the real confirm is Obsidian's read-back (Slice 7).
3. **Apple Notes wired directly** (no destination picker) — it's the one destination
   this slice ships. Slice 7 swaps `AppleNotesDestination` → `ObsidianDestination`
   behind the same coordinator, unchanged.

**Landed as a post-merge tech-lead-review follow-up (this PR):** startup `writing →
pending` reconciliation (`ExportReconciler`, §4); off-device tests for
`ObsidianFolderDestination.writeBatch` (Slice 7's real path); the pre-write `save()`
is do/`catch` with rollback instead of a silent `try?`; and the machine gained the
`.interrupt` transition + a shared `Note.setRetention` mapping.

**Still deferred to Slice 7 (Obsidian):** lazy vault setup at first Keep;
stale-bookmark re-grant; per-note failure **surfacing** UI (Retry / Re-grant /
Set-up) — this slice only *stores* the reason; possibly offloading Obsidian file I/O
off the main actor.

**Still noted for Slice 7 (fold in when the surfacing UI lands):**
- A share-sheet **cancel** currently persists `pending(.writeFailed)` — no note is
  lost, but "write failed / Retry" misreads a plain cancel. Give cancel a distinct
  non-error signal (a `cancelled` reason or `pending(nil)`) once the reason is shown.
- `AppleNotesDestination` joins the whole batch into **one** Apple Note (its `---`
  separators collide with each note's frontmatter fences). Device-only, acceptable
  for throwaway scaffolding; don't be surprised by it in the on-device check.

## Related
- Export decision + verification gates: `docs/adr/0001-obsidian-write-mechanism.md`
- Seam + write/verify (reused): `Jackdaw/Talon/{ExportDestination,VaultAccess,FolderWriter}.swift`
- Failure-reason contract: `docs/slices/slice-4-triage.md`; `.claude/agent-memory/design-lead/export-status-surfaces.md`
- Build order + numbering: `docs/build-order.md` §"Slice 5 — Apple Notes export"
- Next: Slice 7 — Obsidian export (real v1 destination)
