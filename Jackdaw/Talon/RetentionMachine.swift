import Foundation

/// The export half of a note's lifecycle — the retention state machine tail from
/// ADR 0001 and the Slice 4 build-order:
///
/// ```
/// kept → pending → writing → confirmed → deleted
///          ▲          │
///          └──────────┘  (any failure returns to pending, carrying a reason)
/// ```
///
/// It is a distinct value type from the flat, persisted `NoteStatus` on purpose:
/// keeping the transitions pure and exhaustive here makes them unit-testable with
/// zero SwiftData, and `ExportCoordinator` is the one place that maps the
/// non-terminal states back onto `Note.status` + `Note.exportFailureRaw` (and maps
/// `.deleted` onto an actual row delete).
///
/// **The cardinal rule (ADR 0001, hold-until-sync-confirmed): a note is deleted
/// ONLY out of `.confirmed`.** Any write failure routes back to `.pending` so the
/// thought is never lost — the funnel is kill-safe toward *keep*.
enum RetentionState: Equatable {
    case kept
    /// Resting / failed / awaiting-setup. `reason` is nil when simply queued and no
    /// attempt has failed yet; otherwise it carries *why* (drives the recovery UI).
    case pending(ExportFailure?)
    case writing
    case confirmed
    case deleted
}

/// The events that drive `RetentionState`.
enum ExportEvent: Equatable {
    /// Enqueued for a write attempt: `kept`/`pending` → `writing`.
    case beginWrite
    /// The destination confirmed the write: `writing` → `confirmed`.
    case confirm
    /// The write failed: `writing` → `pending(reason)`.
    case fail(ExportFailure)
    /// The confirmed note has been persisted-as-gone: `confirmed` → `deleted`.
    case commit
    /// Startup recovery for a note stranded mid-write by an app kill: `writing` →
    /// `pending(nil)`. Not a failure — the attempt was merely interrupted, so it
    /// carries no reason and returns cleanly to the outbox. See `ExportReconciler`.
    case interrupt
}

/// Pure, total transition function. Reused verbatim by the Obsidian slice.
enum RetentionMachine {
    /// Advance `state` by `event`. Illegal `(state, event)` pairs are **no-ops**
    /// (return `state` unchanged) — defensive, so a caller can't corrupt a note by
    /// firing an event out of order, and callers needn't guard every pair.
    static func next(_ state: RetentionState, _ event: ExportEvent) -> RetentionState {
        switch (state, event) {
        case (.kept, .beginWrite), (.pending, .beginWrite):
            return .writing
        case (.writing, .confirm):
            return .confirmed
        case (.writing, .fail(let reason)):
            return .pending(reason)
        case (.confirmed, .commit):
            return .deleted
        case (.writing, .interrupt):
            return .pending(nil)
        default:
            return state
        }
    }
}

extension Note {
    /// Persist a non-terminal `RetentionState` onto this note — the write-side
    /// counterpart to `Note.retentionState`. `.deleted` is intentionally a no-op:
    /// deleting the row needs the `ModelContext`, so the caller (`ExportCoordinator`)
    /// handles that case. Centralising the mapping here keeps `ExportCoordinator` and
    /// `ExportReconciler` from each re-deriving it.
    func setRetention(_ state: RetentionState) {
        switch state {
        case .kept:            status = .kept;      exportFailureRaw = nil
        case .pending(let r):  status = .pending;   exportFailureRaw = r?.rawValue
        case .writing:         status = .writing;   exportFailureRaw = nil
        case .confirmed:       status = .confirmed; exportFailureRaw = nil
        case .deleted:         break   // row deletion is the caller's job (needs ModelContext)
        }
    }
}
