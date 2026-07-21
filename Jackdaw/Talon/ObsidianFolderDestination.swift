import Foundation

/// The Talon seed: composes `VaultAccess` (security scope) with `FolderWriter`
/// (write+verify) behind the `ExportDestination` seam. Slice 6 reuses this
/// verbatim as the real v1 destination; only the harness UI around it is throwaway.
///
/// The whole batch runs inside **one** `withVaultURL` — a single security-scope
/// claim for the Kept set, not one per note — and each note writes+verifies
/// independently, so a mid-batch write error fails only that note. If the vault
/// itself is unreachable (no bookmark yet, or the bookmark went stale), *every*
/// note fails with that reason, which the coordinator surfaces as
/// "Set up vault" / "Re-grant".
struct ObsidianFolderDestination: ExportDestination {
    let access: VaultAccess
    let writer = FolderWriter()

    @MainActor
    func export(_ notes: [SerializedNote]) async -> [ExportOutcome] {
        guard !notes.isEmpty else { return [] }
        do {
            return try access.withVaultURL { url in writeBatch(notes, into: url) }
        } catch let failure as ExportFailure {
            // Vault-level failure (noVaultConfigured / accessLost) fails the whole batch.
            return notes.map { .failed(id: $0.id, reason: failure) }
        } catch {
            return notes.map { .failed(id: $0.id, reason: .writeFailed) }
        }
    }

    /// The per-note write+verify fold, split from the security-scope layer so it is
    /// unit-testable against a plain temp directory (no bookmark, no
    /// `startAccessingSecurityScopedResource`). A single bad note fails only itself;
    /// the rest still land. **Reused verbatim by Slice 7** — it is the trustworthy
    /// write path, so it's the part that most earns coverage.
    func writeBatch(_ notes: [SerializedNote], into folder: URL) -> [ExportOutcome] {
        notes.map { note in
            do {
                try writer.writeAndVerify(fileName: note.fileName,
                                          data: Data(note.markdown.utf8),
                                          into: folder)
                return .confirmed(id: note.id)
            } catch let failure as ExportFailure {
                return .failed(id: note.id, reason: failure)
            } catch {
                return .failed(id: note.id, reason: .writeFailed)
            }
        }
    }
}
