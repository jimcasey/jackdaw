import SwiftUI
import SwiftData

// The @main attribute marks the app's entry point — the iOS equivalent of a
// `main()` function. `App` is a SwiftUI protocol; its `body` returns the scene
// graph. For a single-window iOS app you want exactly one `WindowGroup`.
@main
struct JackdawApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Creates the SwiftData container (schema = Note), stores it in the app's
        // Application Support directory inside the sandbox, and injects a main
        // ModelContext into the environment. Unrelated to the Talon vault bookmark.
        .modelContainer(for: Note.self)
    }
}
