import Testing
import Foundation
import SwiftData
@testable import Jackdaw

@MainActor
final class MockLocationProvider: LocationProviding {
    var fix: LocationFix?
    var authorizationStatus: LocationAuthStatus

    init(fix: LocationFix?, status: LocationAuthStatus = .authorized) {
        self.fix = fix
        self.authorizationStatus = status
    }

    func currentFix() async -> LocationFix? { fix }
    func requestWhenInUseAuthorization() {}
    func prewarm() {}
    func stopPrewarm() {}
}

@MainActor
struct LocationTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }
    private func count(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }

    @Test func resolveLocation_backfillsCorrectNote_leavesOthersUntouched() async throws {
        let context = try makeContext()
        let service = CaptureService()
        let target = service.makeNote(body: "target", in: context)
        let other = service.makeNote(body: "other", in: context)
        let provider = MockLocationProvider(fix: LocationFix(latitude: 51.5, longitude: -0.12, horizontalAccuracy: 5))

        await service.resolveLocation(for: target, using: provider, in: context)

        #expect(target.latitude == 51.5)
        #expect(target.longitude == -0.12)
        #expect(target.horizontalAccuracy == 5)
        #expect(other.hasLocation == false)
    }

    @Test func resolveLocation_deniedNilFix_leavesTimestampOnly() async throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "n", in: context)
        let provider = MockLocationProvider(fix: nil, status: .denied)

        await service.resolveLocation(for: note, using: provider, in: context)

        #expect(note.hasLocation == false)
    }

    @Test func resolveLocation_pendingThenResolved() async throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "n", in: context)
        #expect(note.hasLocation == false)   // pending
        let provider = MockLocationProvider(fix: LocationFix(latitude: 1, longitude: 2, horizontalAccuracy: 10))

        await service.resolveLocation(for: note, using: provider, in: context)

        #expect(note.hasLocation == true)    // resolved
    }

    @Test func resolveLocation_prunedNote_noWriteNoCrash() async throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "n", in: context)
        context.delete(note)
        try? context.save()
        let provider = MockLocationProvider(fix: LocationFix(latitude: 1, longitude: 2, horizontalAccuracy: 5))

        await service.resolveLocation(for: note, using: provider, in: context)   // guard returns early

        #expect(try count(context) == 0)     // not resurrected
    }

    @Test func reducedAccuracy_appliedNormally() throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "n", in: context)
        service.apply(LocationFix(latitude: 1, longitude: 2, horizontalAccuracy: 3000), to: note)
        #expect(note.hasLocation == true)
        #expect(note.horizontalAccuracy == 3000)
    }

    @Test func apply_nil_leavesCoordinatesNil() throws {
        let context = try makeContext()
        let service = CaptureService()
        let note = service.makeNote(body: "n", in: context)
        service.apply(nil, to: note)
        #expect(note.hasLocation == false)
    }
}
