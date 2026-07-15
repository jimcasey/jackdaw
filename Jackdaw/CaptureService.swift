import Foundation
import SwiftData

/// Shared capture core (ADR 0005). Owns `Note` construction, persistence, and —
/// from the Location slice — best-effort location attachment. Imports neither
/// SwiftUI nor AppIntents, so it is unit-testable off-device and reusable by the
/// deferred v1.x external `CaptureNoteIntent` front-end without re-architecture.
///
/// v1 uses only the primitives below, driven by the in-app live-draft
/// `CaptureViewModel`. The commented `commit(text:)` is the one-shot entry point
/// the external surface will add as a fast-follow.
struct CaptureService {
    /// Create and insert a new note row. (The Location slice attaches a best-effort
    /// fix here; external captures stay timestamp-only per ADR 0005.)
    func makeNote(body: String, in context: ModelContext) -> Note {
        let note = Note(body: body)
        context.insert(note)
        return note
    }

    func delete(_ note: Note, in context: ModelContext) {
        context.delete(note)
    }

    func persist(_ context: ModelContext) {
        try? context.save()
    }

    // v1.x fast-follow — external one-shot capture (ADR 0005):
    // func commit(text: String, in context: ModelContext) -> Note {
    //     let note = makeNote(body: text, in: context)
    //     persist(context)
    //     return note
    // }
}
