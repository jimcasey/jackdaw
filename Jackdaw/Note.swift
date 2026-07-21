import Foundation
import SwiftData

/// Where a note sits in the funnel. Triage owns `inbox`, `snoozed`, `kept`; the
/// export pipeline (Apple Notes / Obsidian slices) owns the retention tail
/// `pending`/`writing`/`confirmed` (the ADR 0001 machine — see `RetentionMachine`).
/// `deleted` is not a case: a confirmed note is removed from the store outright.
/// Adding a case is not a schema change (the stored column is a String).
enum NoteStatus: String, Codable, CaseIterable {
    case inbox      // un-triaged; in the batch
    case snoozed    // deferred; reappears a later calendar day (SnoozeSchedule)
    case kept       // kept-for-export; awaits the next export run
    case pending    // in the export queue / a prior attempt failed (see exportFailure)
    case writing    // an export attempt is in flight
    case confirmed  // write confirmed; about to be deleted (transient)
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

    // --- location (Location slice) — optional → lightweight migration ---
    // No persisted pending/denied state: `hasLocation == false` is terminal (never
    // granted / denied / fix lost to an early kill all look the same). Keep this
    // file free of the CoreLocation import — build a coordinate in the location layer.
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?     // metres; distinguishes precise from reduced
    var placeName: String?              // reverse-geocoded lazily at display; nil if unresolved

    // --- export failure reason (export slices) — optional → lightweight migration ---
    /// Persisted reason for a `pending` export (offline / access-lost / write-error /
    /// no-destination-yet — the Slice 4 seam contract). `nil` unless a prior attempt
    /// failed; the UI keys off it for the right recovery affordance. Stored as the
    /// `ExportFailure` rawValue; app code uses `exportFailure`.
    var exportFailureRaw: String?

    var hasLocation: Bool { latitude != nil && longitude != nil }

    var status: NoteStatus {
        get { NoteStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    /// The failure reason behind a `pending` export, if any.
    var exportFailure: ExportFailure? {
        get { exportFailureRaw.flatMap(ExportFailure.init(rawValue:)) }
        set { exportFailureRaw = newValue?.rawValue }
    }

    /// The note's position in the export retention machine (`RetentionMachine`).
    /// Only meaningful for notes in the export tail; `inbox`/`snoozed` map to `.kept`
    /// as a harmless default (the `ExportCoordinator` never feeds them to the machine).
    var retentionState: RetentionState {
        switch status {
        case .pending:   return .pending(exportFailure)
        case .writing:   return .writing
        case .confirmed: return .confirmed
        case .kept, .inbox, .snoozed: return .kept
        }
    }

    init(id: UUID = UUID(), body: String, createdAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }
}
