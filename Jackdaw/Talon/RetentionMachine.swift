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
        default:
            return state
        }
    }
}
