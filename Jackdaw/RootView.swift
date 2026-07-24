import SwiftUI

/// The app shell (ADR 0004, amended by ADR 0008): **Triage is the root, bare** —
/// the Capture sheet no longer auto-presents (flipped in capture-wave slice A,
/// now that the Action button seeds the inbox from outside). In-app capture is
/// the bottom-docked "New note" button. After the first capture, if location
/// hasn't been asked for yet, a one-time priming sheet explains why before the
/// system prompt.
struct RootView: View {
    @Environment(\.modelContext) private var context

    /// ADR 0004's endgame, ruled in the capture-wave plan §7.1: launch opens to
    /// the bare Triage root. Escape hatch on record: revert to `true` without
    /// debate if in-app capture is still dominant after ~2 weeks of real use,
    /// clocked from when the Action button is actually configured.
    @State private var showCapture = false
    @State private var showPriming = false

    var body: some View {
        NavigationStack {
            TriageRootView()
                // Primary capture chrome (design ruling, plan §7.1): a labeled,
                // 44pt+ bottom-docked button — not just a nav-bar glyph. Attached
                // to the stack's root so pushing the editor hides it; persists
                // over the empty state (screen-inventory 1a keeps its CTA).
                // TriageRootView's own bottom inset (undo banner / export bar)
                // stacks above it.
                .safeAreaInset(edge: .bottom) {
                    Button {
                        showCapture = true
                    } label: {
                        // "Capture", not "New note" — that label is reserved for
                        // the sheet's keyboard-toolbar delimiter (banks the
                        // thought and clears the field); reusing it on a control
                        // with different behavior is an interaction-vocabulary
                        // clash (design review, PR #41). One family: Capture
                        // (button) / "Capture Note" (App Shortcut).
                        Label("Capture", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .accessibilityHint("Opens the capture sheet")
                }
        }
        .sheet(isPresented: $showCapture, onDismiss: maybePrimeLocation) {
            CaptureView()
        }
        .sheet(isPresented: $showPriming) {
            LocationPrimingSheet()
        }
        .task {
            // Recover any note stranded mid-export by a prior app kill (writing →
            // pending), then silently drain any note kept just before the kill
            // (auto-export never ran). Neither presents a picker — a note with no
            // vault simply rests as pending(noVaultConfigured) and the Triage bar
            // invites setup.
            ExportReconciler.reconcileInterruptedWrites(in: context)
            let destination = ObsidianFolderDestination(access: VaultAccess(store: UserDefaultsVaultBookmarkStore()))
            await ExportCoordinator(destination: destination).autoExportKept(in: context)
        }
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
