import Foundation
import SwiftData

/// Drives the Kept set through the `RetentionMachine` against an
/// `ExportDestination`. This is the layer *above* the seam: it serializes each
/// note, transitions it `→ writing`, hands the batch to the destination, and then —
/// per the returned `ExportOutcome`s — advances winners `→ confirmed → deleted` and
/// returns losers `→ pending` with their reason. **The only place a note is
/// deleted is on a confirmed write** (ADR 0001).
///
/// `@MainActor` because it mutates the main-actor `ModelContext` and awaits the
/// (main-actor) `ExportDestination`. Everything decision-shaped lives in the pure
/// `RetentionMachine`/`NoteSerializer`; this type is just the SwiftData-aware glue,
/// tested with an in-memory container and a mock destination.
@MainActor
struct ExportCoordinator {
    let destination: ExportDestination
    let serializer = NoteSerializer()

    /// Export every exportable note (`kept` or a previously-failed `pending`) in the
    /// store, in one batch. Returns the number confirmed (for a UI confirmation).
    @discardableResult
    func exportAll(in context: ModelContext) async -> Int {
        await export(exportable(in: context), in: context)
    }

    /// Export a specific set of notes. Only `kept`/`pending` notes are eligible;
    /// anything else is filtered out **before** the machine runs. This guard is
    /// load-bearing, not defensive nicety: `Note.retentionState` maps `inbox`/
    /// `snoozed` to `.kept`, so without it a stray un-triaged note would advance
    /// `writing → deleted` and a capture would be destroyed — the opposite of the
    /// funnel's kill-safe-toward-keep rule.
    @discardableResult
    func export(_ notes: [Note], in context: ModelContext) async -> Int {
        let notes = notes.filter { NoteStatus.exportable.contains($0.status) }
        guard !notes.isEmpty else { return 0 }

        // 1. kept/pending → writing, and persist that intent before the (possibly
        //    slow / interactive) write, so a mid-export kill leaves notes as
        //    `writing` — recoverable — never silently lost.
        for note in notes { apply(.beginWrite, to: note, in: context) }
        try? context.save()

        // 2. Serialize and hand the whole batch to the destination.
        let serialized = notes.map { serializer.serialize(NoteSnapshot($0)) }
        let outcomes = await destination.export(serialized)

        // 3. Fold each per-note outcome back through the machine.
        let byID = Dictionary(notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var confirmedCount = 0
        for outcome in outcomes {
            guard let note = byID[outcome.id] else { continue }
            switch outcome {
            case .confirmed:
                apply(.confirm, to: note, in: context)   // writing → confirmed
                apply(.commit, to: note, in: context)    // confirmed → deleted
                confirmedCount += 1
            case .failed(_, let reason):
                apply(.fail(reason), to: note, in: context)  // writing → pending(reason)
            }
        }
        try? context.save()
        return confirmedCount
    }

    /// Count of notes awaiting export — the "outbox" badge / funnel-honesty count
    /// (PRD success criterion). Drives the Export affordance's enabled state.
    func exportableCount(in context: ModelContext) -> Int {
        exportable(in: context).count
    }

    // MARK: - Private

    private func exportable(in context: ModelContext) -> [Note] {
        let kept = NoteStatus.kept.rawValue
        let pending = NoteStatus.pending.rawValue
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.statusRaw == kept || $0.statusRaw == pending },
            sortBy: [SortDescriptor(\Note.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fire one machine event and reflect the resulting `RetentionState` onto the
    /// persisted note (`.deleted` → an actual row delete).
    private func apply(_ event: ExportEvent, to note: Note, in context: ModelContext) {
        switch RetentionMachine.next(note.retentionState, event) {
        case .kept:
            note.status = .kept
            note.exportFailureRaw = nil
        case .pending(let reason):
            note.status = .pending
            note.exportFailureRaw = reason?.rawValue
        case .writing:
            note.status = .writing
            note.exportFailureRaw = nil
        case .confirmed:
            note.status = .confirmed
            note.exportFailureRaw = nil
        case .deleted:
            context.delete(note)
        }
    }
}
