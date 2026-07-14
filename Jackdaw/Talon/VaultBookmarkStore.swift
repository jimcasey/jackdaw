import Foundation

/// Persists the single vault security-scoped bookmark (an opaque `Data` blob).
///
/// This is app-level *config* (which vault), not per-note *record* data, so it
/// stays `UserDefaults`-backed even after SwiftData arrives at Slice 2 (see the
/// Slice 1 spec §1). It is not a credential, so the Keychain would be unnecessary
/// ceremony.
protocol VaultBookmarkStore {
    func save(_ bookmark: Data)
    func load() -> Data?
    func clear()
}

struct UserDefaultsVaultBookmarkStore: VaultBookmarkStore {
    static let key = "vaultBookmark"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ bookmark: Data) { defaults.set(bookmark, forKey: Self.key) }
    func load() -> Data? { defaults.data(forKey: Self.key) }
    func clear() { defaults.removeObject(forKey: Self.key) }
}
