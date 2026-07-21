# Slice 6 — Apple Notes export (spec + implementation notes)

Spec: `docs/slices/slice-6-apple-notes-export.md`. **Build-order Slice 5 =
implementation Slice 6** (numbering runs one ahead; the branch `claude/slice-5-…`
uses build-order numbering). Implemented on that branch; **authored in a no-Xcode
sandbox → not compiled/tested there**, `PR CI` is the gate.

## The load-bearing decision: the seam changed shape

Slice 1 proved a **synchronous per-file** write. Apple Notes doesn't fit — its only
write path is the **share sheet** (`UIActivityViewController`): interactive, async,
**one sheet per batch**, and it **can't confirm** the save. Rather than fake a
per-note synchronous "write," I evolved `ExportDestination` to:

```swift
@MainActor func export(_ notes: [SerializedNote]) async -> [ExportOutcome]
```

- **batch** (one share sheet for the Kept set; Obsidian loops files),
- **async + @MainActor** (share sheet is main-actor; also dodges `Sendable`),
- **per-note `ExportOutcome`** = `.confirmed(id:)` / `.failed(id:, reason:)` so a
  batch can partially succeed and losers return to `pending` **with a reason** (the
  Slice 4 contract).

`ObsidianFolderDestination` updated to conform (one `withVaultURL`, `writeAndVerify`
per note) — **reuses `VaultAccess`/`FolderWriter` verbatim**, so Slice 7 inherits it.
`ExportFailure` is now `String`-backed so the reason persists on the `Note`.

## What's above the seam (pure → CI-verifiable, reused verbatim by Obsidian)

- `NoteSerializer` — markdown + YAML frontmatter; **NoteSnapshot** decouples it from
  SwiftData; **deterministic** formatters (ISO-8601 UTC; `%.6f` locale-independent
  coords — a comma-decimal locale would otherwise corrupt YAML); filename
  `yyyy-MM-dd-HHmmss-<id8>.md` — the id suffix prevents same-second **overwrite/data
  loss** under `.atomic`.
- `RetentionMachine` — pure total `next(state,event)`; illegal pairs are no-ops.
  **Cardinal rule (ADR 0001): delete ONLY out of `.confirmed`; any failure → pending.**
- `ExportCoordinator` (@MainActor) — fetch `kept||pending` → `writing` (+save before
  the write, so a mid-export kill leaves `writing`, never lost) → `destination.export`
  → fold outcomes (`confirmed→commit→delete`, `failed→pending+reason`).

## Honest gaps (scaffolding, by design)

- **Degraded confirm:** share-sheet *completion* = `confirmed` (it can't prove Notes
  saved). Fine — this milestone exists to exercise the pipeline/seam, not to be a
  trustworthy retention path. Obsidian (Slice 7) is the verifiable one (read-back).
- ~~No reconciliation of a killed `writing` note~~ **— FIXED (post-merge follow-up).**
  `ExportReconciler.reconcileInterruptedWrites` runs once at launch (`RootView.task`)
  and requeues `writing → pending(nil)` via the new machine `.interrupt` transition.
  Same follow-up: `ObsidianFolderDestination.writeBatch` split out + tested off-device;
  pre-write `save()` is do/`catch`+rollback, not `try?`; shared `Note.setRetention`.
- Obsidian file I/O currently runs on `@MainActor` via the seam — acceptable now;
  offload if Slice 7 profiling says so.

## Slice 7 (Obsidian) inherits, unchanged

Swap `AppleNotesDestination` → `ObsidianDestination` behind the *same*
`ExportCoordinator`; reuse serializer + machine verbatim + Slice-1 write/verify. Then
add: lazy vault setup at first Keep, stale-bookmark re-grant (`accessLost` →
Re-grant), and the pending/failed **surfacing** UI (this slice only *stores* the
reason via `Note.exportFailureRaw` / `exportFailure`).
