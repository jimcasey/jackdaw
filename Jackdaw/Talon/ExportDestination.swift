import Foundation

/// The export seam (subsystem codename *Talon*, per ADR 0001).
///
/// Slice 6's note serializer and retention state machine will sit *above* this
/// protocol; everything below it is a swappable adapter (Obsidian folder-write
/// today, git push as the sanctioned fallback). Keeping this boundary from Slice 1
/// is what lets later slices reuse the write path instead of rewriting it.
protocol ExportDestination {
    /// Write `markdown` to a file named `fileName` at the destination, and verify
    /// it landed. Throws `ExportFailure` on any failure.
    func export(fileName: String, markdown: String) throws
}

/// Failure taxonomy for a single export attempt.
///
/// These cases are the seed of the failure-reason contract the design-lead
/// surfaced for Slice 4 (offline / access-lost / write-error / no-destination-yet).
/// Slice 4/6 should extend this enum rather than invent a second one. `offline` is
/// not reachable in this local-folder slice — it appears once propagation/network
/// enters the picture — so it is intentionally absent here.
enum ExportFailure: Error, Equatable {
    /// No vault bookmark saved yet. Maps to Slice 4's "no-destination-yet".
    case noVaultConfigured
    /// Bookmark unresolvable or the OS refused security-scoped access. → "Re-grant".
    case accessLost
    /// The coordinated write threw. → "Retry".
    case writeFailed
    /// Read-back bytes did not match what we wrote. → "Retry" (and investigate).
    case verifyMismatch
}
