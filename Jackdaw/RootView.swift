import SwiftUI

/// The app shell: the two-tab `Capture | Triage` navigation (design nav doc §2).
///
/// Capture is the first tab, so the app always launches to Capture — we do not
/// restore the last-used tab (funnel ethos: never open onto the pile).
struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("Capture", systemImage: "square.and.pencil") }
            TriageStubView()   // THROWAWAY — replaced by the real inbox at Slice 4
                .tabItem { Label("Triage", systemImage: "tray") }
        }
    }
}
