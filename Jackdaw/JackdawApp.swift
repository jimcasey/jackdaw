import SwiftUI

// The @main attribute marks the app's entry point — the iOS equivalent of a
// `main()` function. `App` is a SwiftUI protocol; its `body` returns the scene
// graph. For a single-window iOS app you want exactly one `WindowGroup`.
@main
struct JackdawApp: App {
    var body: some Scene {
        WindowGroup {
            SkeletonView()
        }
    }
}
