import SwiftUI

/// Persists the once-only "we've shown the location rationale" gate.
enum LocationPrimer {
    private static let key = "hasPrimedLocation"
    static var hasPrimed: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// A one-time rationale shown before the system location prompt, so the system
/// dialog isn't a cold surprise. Continue → request When-In-Use authorization.
struct LocationPrimingSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Keep the context")
                .font(.title2.bold())
            Text("Jackdaw can attach where you were to each note, so a fleeting thought keeps its context. Location stays on your notes and is sent only to your Obsidian vault.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                CoreLocationProvider.shared.requestWhenInUseAuthorization()
                dismiss()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button("Not now") { dismiss() }
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
