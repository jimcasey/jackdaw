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
}
