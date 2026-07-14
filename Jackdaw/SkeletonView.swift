import SwiftUI

/// Slice 0 walking-skeleton screen.
///
/// This view deliberately does almost nothing. Its only job is to prove that
/// *this* archive travelled the full path — sign → provision → archive →
/// App Store Connect → TestFlight → your device — and is the build you think
/// it is. It shows the marketing version and the build number so that when you
/// bump the build and re-upload, you can confirm on-device that the new bytes
/// actually landed (a surprisingly common thing to get wrong early).
struct SkeletonView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Jackdaw")
                .font(.largeTitle.bold())

            Text("walking skeleton")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v\(Self.marketingVersion) (\(Self.buildNumber))")
                .font(.system(.body, design: .monospaced))
                .padding(.top, 4)
        }
        .padding()
    }

    // Info.plist values Xcode populates from the target's Version / Build fields.
    // CFBundleShortVersionString is the user-facing "1.0"; CFBundleVersion is the
    // build counter you increment on every TestFlight upload.
    private static let marketingVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private static let buildNumber =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
}

#Preview {
    SkeletonView()
}
