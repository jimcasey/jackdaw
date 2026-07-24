import AppIntents
import SwiftData

/// The external capture front-end (capture-wave slice A; ADR 0005/0008): a
/// no-launch, one-shot commit over the same `CaptureService` seam as the in-app
/// sheet. Invoked from Shortcuts, Spotlight, Siri, or the Action button; the
/// system prompts for the text via `requestValueDialog`, and the note lands in
/// the Triage inbox indistinguishable from an in-app capture.
///
/// Deliberately **untyped and timestamp-only**: a no-launch intent gets no GPS
/// (ADR 0005 — the platform rule), and media enrichment is scoped to
/// Listening-typed captures (ADR 0009), which arrive with the type parameter in
/// slice B. The intent process may be suspended the moment `perform()` returns,
/// so everything here is synchronous — no async backfill on this path.
///
/// NOTE (ITMS-90626): App Intents-visible strings — title, description, App
/// Shortcut phrases — must not contain "apple" or the TestFlight upload is
/// rejected at delivery validation.
struct CaptureNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Note"
    static let description = IntentDescription(
        "Saves a fleeting note straight into the Jackdaw inbox without opening the app."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Note", requestValueDialog: "What's on your mind?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The scene's own context (legal here: perform() is @MainActor, and
        // mainContext is @MainActor-isolated). Writing on it makes the Triage
        // @Query refresh guaranteed-by-construction in the warm-app case —
        // a sibling ModelContext's save reaching @Query without relaunch is
        // undocumented merge behavior with a flaky history (tech-lead review,
        // PR #41). Cold case is a fresh fetch at next launch either way.
        let context = AppModelContainer.shared.mainContext
        guard CaptureService().commit(text: text, in: context) != nil else {
            // Whitespace-only input creates no note (the prune-on-abandon
            // convention, applied up front on the one-shot path).
            return .result(dialog: "Nothing to capture.")
        }
        return .result(dialog: "Captured.")
    }
}

/// Zero-setup App Shortcut: makes "Capture Note" immediately runnable from the
/// Shortcuts app and Spotlight, and directly assignable to the Action button —
/// no manual shortcut assembly. Phrases must embed the application-name token
/// (system requirement) and avoid "apple" (ITMS-90626).
struct JackdawShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureNoteIntent(),
            phrases: [
                "Capture a note in \(.applicationName)",
                "New \(.applicationName) note"
            ],
            shortTitle: "Capture Note",
            systemImageName: "square.and.pencil"
        )
    }
}
