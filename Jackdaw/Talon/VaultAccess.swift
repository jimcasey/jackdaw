import Foundation

/// Result of resolving the saved bookmark, for the harness status line.
enum VaultResolveStatus {
    case noVault
    case resolved(folderName: String, path: String)
    case resolvedStaleRecreated(folderName: String, path: String)
    case resolveFailed(String)
}

/// The on-device, security-scope layer: turns the saved bookmark into a URL you
/// can actually write to, handling staleness and the start/stop access dance.
///
/// This is deliberately separate from `FolderWriter` so the write+verify logic
/// stays unit-testable off-device (this layer needs a real picker-vended URL and
/// cannot be exercised in CI).
struct VaultAccess {
    let store: VaultBookmarkStore

    /// Create and persist a bookmark from a freshly picked folder URL.
    ///
    /// The picker URL is security-scoped, so we must claim access *before* calling
    /// `bookmarkData`. On iOS the bookmark is created with `options: []` — the
    /// `.withSecurityScope` option is macOS-only and a real trap here (ADR 0001).
    func setVault(pickedURL url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else { throw ExportFailure.accessLost }
        defer { url.stopAccessingSecurityScopedResource() }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        store.save(data)
    }

    /// Resolve the saved bookmark for display, without performing a write. Used by
    /// the harness on launch — reading this after a cold relaunch is the
    /// persistence proof.
    func status() -> VaultResolveStatus {
        guard store.load() != nil else { return .noVault }
        do {
            let (url, wasStale) = try resolve()
            if wasStale {
                recreateBookmark(from: url)
                return .resolvedStaleRecreated(folderName: url.lastPathComponent, path: url.path)
            }
            return .resolved(folderName: url.lastPathComponent, path: url.path)
        } catch {
            return .resolveFailed(String(describing: error))
        }
    }

    /// Resolve the bookmark, start access, run `body` with the folder URL, and stop
    /// access on exit. Recreates the bookmark if the OS reports it stale.
    func withVaultURL<T>(_ body: (URL) throws -> T) throws -> T {
        let (url, wasStale) = try resolve()
        guard url.startAccessingSecurityScopedResource() else { throw ExportFailure.accessLost }
        defer { url.stopAccessingSecurityScopedResource() }
        if wasStale { recreateBookmarkWhileAccessing(url) }
        return try body(url)
    }

    // MARK: - Private

    private func resolve() throws -> (url: URL, wasStale: Bool) {
        guard let data = store.load() else { throw ExportFailure.noVaultConfigured }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: [],            // NOT .withSecurityScope (macOS-only)
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            return (url, isStale)
        } catch {
            throw ExportFailure.accessLost
        }
    }

    /// Recreate a stale bookmark; acquires access briefly since `bookmarkData`
    /// needs the resource to be accessible.
    private func recreateBookmark(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        recreateBookmarkWhileAccessing(url)
    }

    /// Recreate assuming access is already held by the caller.
    private func recreateBookmarkWhileAccessing(_ url: URL) {
        if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            store.save(fresh)
        }
    }
}
