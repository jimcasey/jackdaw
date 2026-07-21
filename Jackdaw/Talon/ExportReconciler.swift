import Foundation
import SwiftData

/// One-shot startup recovery for the retention machine.
///
/// A note persisted as `.writing` when the app was killed mid-export — e.g. the
/// Apple Notes share sheet sat open and iOS reclaimed the app — is otherwise
/// **invisible on every surface**: excluded from the outbox (`kept || pending`)
/// *and* from Triage (`inbox || snoozed`). Nothing is lost (the row and its content
/// persist), but the owner can no longer see or act on that captured thought.
///
/// Run once at launch (`RootView`), this returns any such note to `.pending` via the
/// machine's `.interrupt` transition — a clean, reason-less requeue, *not* a failure —
/// so it reappears in the outbox for another attempt. Idempotent: a run with no
/// stranded notes is a no-op.
///
/// Only `.writing` can strand. `.confirmed` needs no recovery: confirm → commit →
/// delete all happen inside a single `save()`, so a `.confirmed` row never survives a
/// relaunch to be found here.
@MainActor
enum ExportReconciler {
    /// Requeue every `.writing` note as `.pending`. Returns how many were recovered.
    @discardableResult
    static func reconcileInterruptedWrites(in context: ModelContext) -> Int {
        let writing = NoteStatus.writing.rawValue
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.statusRaw == writing })
        guard let stranded = try? context.fetch(descriptor), !stranded.isEmpty else { return 0 }
        for note in stranded {
            note.setRetention(RetentionMachine.next(note.retentionState, .interrupt))  // writing → pending(nil)
        }
        try? context.save()   // best-effort; if it fails, the next launch retries
        return stranded.count
    }
}
