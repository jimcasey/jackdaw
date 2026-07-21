import SwiftUI

/// The app shell (ADR 0004): **Triage is the root; Capture is a modal sheet that
/// auto-presents on launch.** After the first capture, if location hasn't been
/// asked for yet, a one-time priming sheet explains why before the system prompt.
struct RootView: View {
    @Environment(\.modelContext) private var context

    /// Single source of truth for auto-present-on-launch. Post-v1, once external
    /// capture seeds the inbox (ADR 0005 fast-follow), flip the initial value to
    /// `false` so the app opens to a bare Triage root.
    @State private var showCapture = true
    @State private var showPriming = false

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
        .sheet(isPresented: $showCapture, onDismiss: maybePrimeLocation) {
            CaptureView()
        }
        .sheet(isPresented: $showPriming) {
            LocationPrimingSheet()
        }
        // Recover any note stranded mid-export by a prior app kill (writing → pending),
        // so it re-surfaces in the outbox instead of being invisible everywhere.
        .task { ExportReconciler.reconcileInterruptedWrites(in: context) }
    }

    /// Once-only, after the first Capture session ends and before any system
    /// prompt: explain why we'd like location. Never interrupts typing (fires on
    /// sheet dismiss). Design owns the exact trigger; the gate + ordering is the
    /// contract.
    private func maybePrimeLocation() {
        guard !LocationPrimer.hasPrimed,
              CoreLocationProvider.shared.authorizationStatus == .notDetermined
        else { return }
        LocationPrimer.hasPrimed = true
        showPriming = true
    }
}
