import UIKit

/// The intermediate-milestone `ExportDestination` (build-order Slice 5): it hands
/// the Kept batch to the system **share sheet** (`UIActivityViewController`) so the
/// owner can drop it into Apple Notes. This is the *only* practical Apple Notes
/// write path — Apple Notes has no clean write API — and it is deliberately
/// scaffolding, not a trustworthy v1 destination (that is Obsidian, Slice 6).
///
/// **Retained on purpose, not stranded.** As of Slice 7 the app wires Triage to
/// `ObsidianFolderDestination` only, so this type is unreferenced by production. It
/// is kept as the seam's **second adapter** — living proof that `ExportDestination`
/// isn't hard-wired to Obsidian — NOT as a shipped destination. Don't delete it as
/// rot, and don't wire it back.
///
/// **DEGRADED confirm (ADR 0001, Candidate A), stated plainly:** the share sheet
/// **cannot** report whether "Save to Notes" actually succeeded — only whether the
/// user *completed* an action versus cancelled. So for this milestone we treat
/// **sheet completion as `confirmed`** for every note in the batch, and **cancel as
/// a retryable `writeFailed`**. That is acceptable precisely because the milestone's
/// job is to exercise the pipeline *above* the seam (serializer + retention machine
/// + batch UX), not to be a verifiable retention path.
///
/// The whole batch is shared as **one** activity — a single share sheet for the
/// Kept set, per the funnel's "clear the inbox in one action" ethos — with the
/// notes' markdown joined into one payload.
struct AppleNotesDestination: ExportDestination {
    @MainActor
    func export(_ notes: [SerializedNote]) async -> [ExportOutcome] {
        guard !notes.isEmpty else { return [] }
        let payload = notes.map(\.markdown).joined(separator: "\n\n---\n\n")
        let completed = await presentShareSheet(text: payload)
        return notes.map {
            completed ? .confirmed(id: $0.id) : .failed(id: $0.id, reason: .writeFailed)
        }
    }

    /// Present the share sheet from the top-most view controller and suspend until
    /// its completion handler fires. Returns whether the user completed an action.
    @MainActor
    private func presentShareSheet(text: String) async -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        return await withCheckedContinuation { continuation in
            let activity = UIActivityViewController(activityItems: [text],
                                                    applicationActivities: nil)
            activity.completionWithItemsHandler = { _, completed, _, _ in
                continuation.resume(returning: completed)
            }
            // iPad requires a popover anchor or the present() traps.
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                            y: presenter.view.bounds.midY,
                                            width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            presenter.present(activity, animated: true)
        }
    }

    /// Walk from the active window scene's root to the front-most presented
    /// controller, so the share sheet presents above the Triage stack (and above the
    /// Capture sheet, if it happens to be up).
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
