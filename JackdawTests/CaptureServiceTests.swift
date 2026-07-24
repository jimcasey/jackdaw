import Testing
import Foundation
import SwiftData
@testable import Jackdaw

/// Direct tests for the shared capture core (ADR 0005). The autosave lifecycle is
/// covered separately in `CaptureViewModelTests`, which drives these primitives
/// through the in-app front-end.
@MainActor
struct CaptureServiceTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    private func noteCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }

    @Test func makeNote_insertsRowWithBody() throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "hello", in: context)
        #expect(note.body == "hello")
        #expect(try noteCount(context) == 1)
    }

    @Test func delete_removesRow() throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "bye", in: context)
        service.delete(note, in: context)
        #expect(try noteCount(context) == 0)
    }

    @Test func persist_savesWithoutThrowing() throws {
        let context = try makeContext()
        let service = CaptureService()
        _ = service.makeNote(body: "durable", in: context)
        service.persist(context)
        #expect(try noteCount(context) == 1)
    }

    // MARK: - One-shot commit (the external front-end's path, slice A)

    @Test func commit_insertsFinishedInboxNote() throws {
        let context = try makeContext()
        let note = CaptureService().commit(text: "from outside", in: context)
        #expect(note?.body == "from outside")
        #expect(note?.status == .inbox)
        #expect(try noteCount(context) == 1)
    }

    @Test func commit_trimsSurroundingWhitespace() throws {
        let context = try makeContext()
        let note = CaptureService().commit(text: "  padded thought \n", in: context)
        #expect(note?.body == "padded thought")
    }

    @Test func commit_whitespaceOnly_createsNothing() throws {
        let context = try makeContext()
        let note = CaptureService().commit(text: "   \n\t", in: context)
        #expect(note == nil)
        #expect(try noteCount(context) == 0)
    }

    @Test func commit_isTimestampOnly_noLocation() throws {
        let context = try makeContext()
        let note = CaptureService().commit(text: "external", in: context)
        #expect(note?.hasLocation == false)
    }

    /// Pins the synchronous save — reading through a SECOND context on the same
    /// container proves the note reached the store, not just the writer's
    /// in-memory graph (an inserted-but-unsaved object is visible to its own
    /// context, so same-context reads can't detect a missing `persist`).
    @Test func commit_savesSynchronously_visibleToSiblingContext() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        _ = CaptureService().commit(text: "durable externally", in: ModelContext(container))
        let reader = ModelContext(container)
        #expect(try reader.fetch(FetchDescriptor<Note>()).count == 1)
    }
}
