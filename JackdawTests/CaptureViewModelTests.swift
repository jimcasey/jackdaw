import Testing
import Foundation
import SwiftData
@testable import Jackdaw

/// Off-device tests for the autosave lifecycle. The logic lives entirely in
/// `CaptureViewModel`, so it tests fast against an in-memory SwiftData container —
/// no simulator, no disk. (Slice 2 spec §6.)
@MainActor
struct CaptureViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    private func noteCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }

    @Test func edit_emptyOrWhitespace_createsNoRow() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("", in: context)
        vm.edit("   ", in: context)
        #expect(try noteCount(context) == 0)
        #expect(vm.draft == nil)
    }

    @Test func edit_firstNonWhitespaceChar_createsOneRow() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("h", in: context)
        #expect(try noteCount(context) == 1)
        #expect(vm.draft?.body == "h")
    }

    @Test func edit_whitespaceThenContent_createsExactlyOneRow() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit(" ", in: context)
        #expect(try noteCount(context) == 0)
        vm.edit(" a", in: context)
        #expect(try noteCount(context) == 1)
    }

    @Test func edit_updatesInPlace_noSecondRow() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("h", in: context)
        vm.edit("hello", in: context)
        #expect(try noteCount(context) == 1)
        #expect(vm.draft?.body == "hello")
    }

    @Test func finishEditing_emptyDraft_prunes() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("h", in: context)
        vm.edit("", in: context)          // cleared back to empty, same draft
        vm.finishEditing(in: context)
        #expect(try noteCount(context) == 0)
        #expect(vm.draft == nil)
    }

    @Test func finishEditing_nonEmpty_commitsAndDetaches() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("keep me", in: context)
        vm.finishEditing(in: context)
        #expect(try noteCount(context) == 1)
        #expect(vm.draft == nil)
    }

    @Test func finishEditing_calledTwice_isIdempotent() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("keep me", in: context)
        vm.finishEditing(in: context)
        vm.finishEditing(in: context)     // no crash, no double delete
        #expect(try noteCount(context) == 1)
    }

    @Test func freshSessionAfterCommit_makesDistinctRows() throws {
        let context = try makeContext()
        let vm = CaptureViewModel()
        vm.edit("one", in: context)
        vm.finishEditing(in: context)
        vm.edit("two", in: context)
        vm.finishEditing(in: context)
        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 2)
        #expect(Set(notes.map(\.id)).count == 2)
    }
}
