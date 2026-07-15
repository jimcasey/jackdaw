import Foundation
import SwiftData

/// Where a note sits in the funnel. This slice implements `inbox`, `snoozed`,
/// `kept`. The export slices EXTEND this enum with `pending`/`writing`/`confirmed`
/// (the ADR 0001 retention machine) — add cases there, don't fork a second enum.
/// Adding a case is not a schema change (the stored column is a String).
enum NoteStatus: String, Codable, CaseIterable {
    case inbox      // un-triaged; in the batch
    case snoozed    // deferred; reappears a later calendar day (SnoozeSchedule)
    case kept       // kept-for-export; awaits the export pipeline (export slices)
}

/// A captured note.
///
/// `@Model` must be a `final class`: SwiftData tracks objects by reference
/// identity to observe mutations and persist them. Location (Location slice) and
/// the export failure-reason (export slice) are still added additively later;
/// SwiftData lightweight-migrates optional/defaulted properties.
@Model
final class Note {
    /// Stable identity independent of SwiftData's `PersistentIdentifier` (used for
    /// the discard-undo held set, and later the export filename).
    var id: UUID
    var body: String
    var createdAt: Date

    // --- lifecycle (Triage slice) — all defaulted/optional → lightweight migration ---

    /// Persisted backing for `status`. Internal (not private) so the Triage
    /// `@Query` `#Predicate` can filter on it — SwiftData predicates are reliable
    /// on stored primitives but flaky on custom enum types. App code uses `status`.
    var statusRaw: String = NoteStatus.inbox.rawValue

    /// Absolute reappear boundary; `nil` unless snoozed (see `SnoozeSchedule`).
    var snoozedUntil: Date?

    /// Times this note has been snoozed; drives the "snoozed N×" anti-graveyard hint.
    var snoozeCount: Int = 0

    var status: NoteStatus {
        get { NoteStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), body: String, createdAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }
}
