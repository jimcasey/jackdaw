import Foundation
import Observation
import SwiftData

/// The in-app live-draft front-end over `CaptureService` (ADR 0005): owns the
/// autosave-as-you-type lifecycle — create / update / prune.
///
/// Free of any SwiftUI import — it takes an injected `ModelContext` per call and
/// delegates note construction/persistence to `CaptureService`, so all of this
/// logic is unit-testable off-device against an in-memory container. Reads live in
/// the View via `@Query`; this type owns the *write commands*.
@Observable
final class CaptureViewModel {
    private let service: CaptureService

    /// The row currently being edited, if one exists yet. `nil` means no keystroke
    /// with content has happened since the sheet last committed/opened.
    private(set) var draft: Note?

    init(service: CaptureService = CaptureService()) {
        self.service = service
    }

    /// Called on every text change. In-memory mutation only — disk persistence is
    /// SwiftData's built-in autosave plus the flush in `finishEditing`.
    func edit(_ text: String, in context: ModelContext) {
        if draft == nil {
            // Rule 1: lazy create on the FIRST non-whitespace character.
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let note = service.makeNote(body: text, in: context)
            service.attachLocation(to: note, in: context)   // async backfill bound to `note`
            draft = note
        } else {
            draft?.body = text   // mutate in place; SwiftData tracks it
        }
    }

    /// Commit the current note, or prune it if empty. Called on sheet dismissal and
    /// on `.background`, and by the explicit "New note" action. Idempotent.
    func finishEditing(in context: ModelContext) {
        guard let note = draft else { return }
        if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            service.delete(note, in: context)   // Rule 3: prune empty fragment
        }
        draft = nil                             // detach: next keystroke = fresh row
        service.persist(context)                // Rule 2: durability guarantee
    }
}
