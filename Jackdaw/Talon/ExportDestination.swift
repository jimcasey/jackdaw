import Foundation

/// The export seam (subsystem codename *Talon*, per ADR 0001).
///
/// The **note serializer** (`NoteSerializer`) and the **retention state machine**
/// (`RetentionMachine`, driven by `ExportCoordinator`) sit *above* this protocol;
/// everything below it is a swappable adapter — Apple Notes via the share sheet
/// (`AppleNotesDestination`, the intermediate milestone) and the Obsidian
/// folder-write (`ObsidianFolderDestination`, the real v1 destination). Standing up
/// two real adapters behind one seam is the proof the boundary is honest and not
/// hard-wired to Obsidian.
///
/// **Shape (evolved at the Apple Notes slice):** export is **batch**, **async**, and
/// returns a **per-note outcome**. Rationale:
/// - *Batch*, because an interactive destination (Apple Notes) presents the system
///   share sheet **once** for the whole Kept set — one user action, per the funnel's
///   "clear the inbox" ethos — while a file destination (Obsidian) simply loops and
///   writes each note as its own file. One shape serves both.
/// - *Async + `@MainActor`*, because the share sheet is presented on the main actor
///   and its completion is awaited. The main-actor confinement also sidesteps
///   `Sendable` friction across the seam; Obsidian's file I/O is light enough here
///   and can be offloaded when Slice 6 hardens the write path.
/// - *Per-note `ExportOutcome`*, because a batch can partially succeed (one file
///   writes, another hits a stale bookmark). The retention machine confirms/deletes
///   the winners and returns the losers to `pending` **with a reason** — the Slice 4
///   seam contract (offline / access-lost / write-error / no-destination-yet).
protocol ExportDestination {
    /// Export a batch of serialized notes in one user action. Never throws — a batch
    /// can partially fail, so failure is reported *per note* via `ExportOutcome`
    /// rather than as an all-or-nothing throw.
    @MainActor func export(_ notes: [SerializedNote]) async -> [ExportOutcome]
}

/// A note serialized for export: the destination writes `markdown` under `fileName`.
/// `id` is the originating `Note.id`, so `ExportCoordinator` maps each
/// `ExportOutcome` back onto the right row.
struct SerializedNote: Equatable, Identifiable {
    let id: UUID
    let fileName: String
    let markdown: String
}

/// The result of attempting to export one note in a batch.
enum ExportOutcome: Equatable {
    /// The write landed (for Apple Notes this is a *degraded* confirm — see
    /// `AppleNotesDestination`). The coordinator advances the note to `deleted`.
    case confirmed(id: UUID)
    /// The write failed; the coordinator returns the note to `pending` carrying
    /// `reason`, which the UI keys off for the right recovery affordance.
    case failed(id: UUID, reason: ExportFailure)

    /// The originating `Note.id`, whichever case.
    var id: UUID {
        switch self {
        case .confirmed(let id), .failed(let id, _): return id
        }
    }
}

/// Failure taxonomy for a single export attempt.
///
/// These cases are the failure-reason contract the design-lead surfaced for Slice 4
/// (offline / access-lost / write-error / no-destination-yet). String-backed so a
/// note's *reason* can be persisted alongside its `pending` status
/// (`Note.exportFailureRaw`) and survive relaunch. `offline` is not reachable in the
/// local-folder / share-sheet slices — it appears once network propagation enters
/// the picture — so it is intentionally absent here; add it, don't fork this enum.
enum ExportFailure: String, Error, Equatable {
    /// No vault bookmark saved yet. Maps to Slice 4's "no-destination-yet". → "Set up vault".
    case noVaultConfigured
    /// Bookmark unresolvable or the OS refused security-scoped access. → "Re-grant".
    case accessLost
    /// The coordinated write threw, or the interactive share was cancelled. → "Retry".
    case writeFailed
    /// Read-back bytes did not match what we wrote. → "Retry" (and investigate).
    case verifyMismatch
}
