import SwiftData

/// The single shared `ModelContainer` (ADR 0005/0008): built once, used by both
/// the SwiftUI scene and the App Intents front-end, so an external capture and
/// the in-app sheet write to the same store regardless of which comes up first.
/// A `static let` has no dependence on app-launch registration timing — the
/// reason this is preferred over App Intents' `@Dependency` for the container.
enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Note.self)
        } catch {
            // A store that fails to open is unrecoverable at launch (the schema
            // is additive-only per ADR 0003, so this is not a migration path);
            // fail fast rather than run storeless and silently drop captures.
            fatalError("Failed to open the Jackdaw store: \(error)")
        }
    }()
}
