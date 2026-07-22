import Foundation
import Observation
import SwiftData

/// Owns the triage write-commands and the pure due-filter. Takes an injected
/// `ModelContext` per call and an injected clock/calendar, so the fiddly snooze and
/// undo logic is unit-testable off-device. Reads live in the View via `@Query`.
@Observable
final class TriageViewModel {
    private let now: () -> Date
    private let calendar: Calendar

    /// Optimistically-hidden discards awaiting either Undo or banner-expiry commit.
    private(set) var pendingDiscard: Set<UUID> = []
    /// Strong refs to held notes so a pending discard isn't lost before commit.
    private var held: [UUID: Note] = [:]

    init(now: @escaping () -> Date = { Date() }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    // MARK: - Actions

    func keep(_ note: Note, in context: ModelContext) {
        note.status = .kept
        try? context.save()
    }

    func snooze(_ note: Note, in context: ModelContext) {
        note.status = .snoozed
        note.snoozedUntil = SnoozeSchedule.reappearBoundary(snoozedAt: now(), calendar: calendar)
        note.snoozeCount += 1
        try? context.save()
    }

    /// Send a stuck (`pending`) note back to the un-triaged inbox, out of the export
    /// tail — the owner's escape hatch for a note they give up exporting. A plain
    /// status reset, NOT a `RetentionMachine` event: re-triage is outside the
    /// machine's kept…deleted domain. No-op on a non-`pending` note.
    func returnToInbox(_ note: Note, in context: ModelContext) {
        guard note.status == .pending else { return }
        note.status = .inbox
        note.exportFailureRaw = nil
        try? context.save()
    }

    /// Optimistically hide (do NOT delete yet). Delete is deferred to `commitDiscard`
    /// on banner expiry — kill-safe in the funnel's favor (a kill during the window
    /// leaves the note intact).
    func discard(_ note: Note) {
        pendingDiscard.insert(note.id)
        held[note.id] = note
    }

    func undoDiscard(_ id: UUID) {
        pendingDiscard.remove(id)
        held[id] = nil
    }

    func commitDiscard(_ id: UUID, in context: ModelContext) {
        guard let note = held[id] else { return }
        context.delete(note)
        try? context.save()
        pendingDiscard.remove(id)
        held[id] = nil
    }

    // MARK: - Pure filters (read `now()` fresh; recompute on Triage appearance)

    func visibleNotes(_ candidates: [Note]) -> [Note] {
        let n = now()
        return candidates.filter { note in
            if pendingDiscard.contains(note.id) { return false }
            switch note.status {
            case .inbox:   return true
            case .snoozed: return note.snoozedUntil.map { SnoozeSchedule.isDue(snoozedUntil: $0, now: n) } ?? true
            // kept + the export-tail states (pending/writing/confirmed) have left triage.
            case .kept, .pending, .writing, .confirmed: return false
            }
        }
    }

    /// Snoozed notes that are NOT yet due — surfaced only as a count on the empty
    /// state; never browsable.
    func snoozedNotDue(_ candidates: [Note]) -> [Note] {
        let n = now()
        return candidates.filter { note in
            guard !pendingDiscard.contains(note.id),
                  note.status == .snoozed,
                  let until = note.snoozedUntil else { return false }
            return !SnoozeSchedule.isDue(snoozedUntil: until, now: n)
        }
    }
}
