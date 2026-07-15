import Foundation
import SwiftData

/// Shared capture core (ADR 0005). Owns `Note` construction, persistence, and
/// best-effort location attachment. Imports neither SwiftUI nor AppIntents, so it
/// is unit-testable off-device and reusable by the deferred v1.x external
/// `CaptureNoteIntent` front-end (which reuses `makeNote` WITHOUT location).
struct CaptureService {
    /// The location source; `nil` in tests that don't care and on the external path.
    let location: LocationProviding?

    init(location: LocationProviding? = nil) {
        self.location = location
    }

    /// Create and insert a new note row.
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

    // MARK: - Location (honors the seam contract: never awaited inline in capture)

    /// Fire-and-forget best-effort backfill, bound to `note`. The `Task` holds a
    /// strong ref to `note`, so the fix lands on the correct row even after the
    /// in-app draft has detached (`finishEditing` sets `draft = nil`).
    func attachLocation(to note: Note, in context: ModelContext) {
        guard let location else { return }
        Task { @MainActor in
            await resolveLocation(for: note, using: location, in: context)
        }
    }

    /// The awaitable core — tests call this directly with a mock provider.
    @MainActor
    func resolveLocation(for note: Note, using provider: LocationProviding, in context: ModelContext) async {
        let fix = await provider.currentFix()
        // GUARD: the note may have been pruned (captured-then-cleared-and-abandoned)
        // while the fix was in flight — don't resurrect a dead object.
        guard note.modelContext != nil else { return }
        apply(fix, to: note)
        try? context.save()
    }

    /// Pure — unit-testable with no provider at all. `nil` → leave timestamp-only.
    func apply(_ fix: LocationFix?, to note: Note) {
        guard let fix else { return }
        note.latitude = fix.latitude
        note.longitude = fix.longitude
        note.horizontalAccuracy = fix.horizontalAccuracy
    }
}
