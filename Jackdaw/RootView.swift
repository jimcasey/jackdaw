import SwiftUI

/// The app shell (ADR 0004): **Triage is the root; Capture is a modal sheet that
/// auto-presents on launch.** The user still lands ready to type; dismissing the
/// sheet reveals Triage. A sheet owns its own keyboard and dismissal, so the
/// keyboard-covers-tab-bar bug of the old two-tab model is gone by construction.
struct RootView: View {
    /// Single source of truth for auto-present-on-launch. Post-v1, once external
    /// capture seeds the inbox (ADR 0005 fast-follow), flip the initial value to
    /// `false` so the app opens to a bare Triage root.
    @State private var showCapture = true

    var body: some View {
        NavigationStack {
            TriageRootView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Capture", systemImage: "square.and.pencil") {
                            showCapture = true
                        }
                    }
                }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView()
        }
    }
}
