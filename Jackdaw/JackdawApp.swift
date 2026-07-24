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
        // The shared container (ADR 0005/0008): the same instance backs the
        // scene AND CaptureNoteIntent, so external captures and the in-app sheet
        // write to one store. Unrelated to the Talon vault bookmark.
        .modelContainer(AppModelContainer.shared)
    }
}
