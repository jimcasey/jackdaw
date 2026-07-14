import SwiftUI

// The @main attribute marks the app's entry point — the iOS equivalent of a
// `main()` function. `App` is a SwiftUI protocol; its `body` returns the scene
// graph. For a single-window iOS app you want exactly one `WindowGroup`.
@main
struct JackdawApp: App {
    var body: some Scene {
        WindowGroup {
            // Slice 1: the app shows the vault-proof harness while we retire the
            // bookmark write+verify risk. Swap back / move to a real root at Slice 6.
            VaultProofView()
        }
    }
}
