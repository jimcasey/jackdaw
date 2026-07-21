import Foundation

/// The single state the Triage bottom bar renders for the export "outbox" (kept +
/// pending notes). Pure — reads only in-memory `status`/`exportFailure`, so it's
/// unit-testable with hand-built notes and carries no SwiftData or UI.
///
/// Under the **hybrid** export model (Slice 7), kept notes auto-export and are
/// transient, so in steady state the outbox is the *stuck set* (pending). The bar is
/// silent for `.empty` and `.draining`; `.needsSetup`/`.stuck` are the actionable
/// states. Keeping this a pure classifier is what makes the surfacing UI inherently
/// act-on-stuck-only (never a browsable kept-list — the product-lead non-goal).
enum OutboxState: Equatable {
    case empty
    /// Dominant reason `noVaultConfigured` — the vault isn't set up yet → "Set up vault".
    case needsSetup(count: Int)
    /// A recoverable failure — `accessLost` → "Re-grant"; `writeFailed`/`verifyMismatch`
    /// → "Retry". `count` is the whole pending set; `reason` drives the bar label.
    case stuck(count: Int, reason: ExportFailure)
    /// Only freshly-kept notes remain — they auto-export; the bar stays silent.
    case draining(count: Int)
}

enum OutboxSummary {
    static func classify(_ outbox: [Note]) -> OutboxState {
        let pending = outbox.filter { $0.status == .pending }
        let keptCount = outbox.filter { $0.status == .kept }.count

        guard !pending.isEmpty else {
            return keptCount == 0 ? .empty : .draining(count: keptCount)
        }
        let reason = dominantReason(pending.compactMap(\.exportFailure))
        return reason == .noVaultConfigured
            ? .needsSetup(count: pending.count)
            : .stuck(count: pending.count, reason: reason)
    }

    /// Which single reason drives the bar when the batch failed for mixed reasons.
    /// Vault-level blockers win (nothing exports until the vault is fixed), then the
    /// per-note verify/write errors. Deterministic priority, not frequency. A pending
    /// note with no recorded reason (e.g. an interrupted write reconciled to
    /// `pending(nil)`) falls through to `.writeFailed` → a plain "Retry".
    private static func dominantReason(_ reasons: [ExportFailure]) -> ExportFailure {
        let priority: [ExportFailure] = [.noVaultConfigured, .accessLost, .verifyMismatch, .writeFailed]
        return priority.first(where: reasons.contains) ?? reasons.first ?? .writeFailed
    }
}
