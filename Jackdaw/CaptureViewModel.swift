import Foundation
import Observation
import SwiftData

/// Owns the autosave-as-you-type lifecycle for Capture: create / update / prune.
///
/// Deliberately free of any SwiftUI import — it takes an injected `ModelContext`
/// per call so all of this logic is unit-testable off-device against an in-memory
/// container (see `CaptureViewModelTests`). Reads live in the View via `@Query`;
/// this type owns the *write commands* — the pragmatic MVVM the project asks for
/// (`docs/slices/slice-2-capture-swiftdata.md` §4).
@Observable
final class CaptureViewModel {
    /// The row currently being edited, if one exists yet. `nil` means no keystroke
    /// with content has happened since we last left Capture.
    private(set) var draft: Note?

    /// Called on every text change. In-memory only — disk persistence is handled by
    /// SwiftData's built-in autosave plus the `.background` flush in `finishEditing`.
    func edit(_ text: String, in context: ModelContext) {
        if draft == nil {
            // Rule 1: lazy create on the FIRST non-whitespace character.
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let note = Note(body: text)
            context.insert(note)
            draft = note
            // Slice 3 hook: kick off the async location request bound to THIS note
            // instance here, so the fix lands on the right row even after detach.
        } else {
            draft?.body = text   // mutate in place; SwiftData tracks it
        }
    }

    /// Commit the current note, or prune it if it is empty. Called when leaving
    /// Capture (tab switch / disappear), on `.background`, and on the explicit
    /// "New note" action. Idempotent — safe to call twice (guards on `draft`,
    /// detaches after) so overlapping `.onDisappear` + `scenePhase` fires are safe.
    func finishEditing(in context: ModelContext) {
        guard let note = draft else { return }
        if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(note)          // Rule 3: prune empty fragment
        }
        draft = nil                       // detach: next keystroke starts a fresh row
        try? context.save()               // Rule 2: durability guarantee
    }
}
