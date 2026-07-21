import Testing
import Foundation
import SwiftData
@testable import Jackdaw

// MARK: - NoteSerializer (pure value transform, no SwiftData)

struct NoteSerializerTests {
    private let serializer = NoteSerializer()

    // A fixed instant + id so filenames/frontmatter are exactly assertable.
    private let at = Date(timeIntervalSince1970: 1_800_000_000)
    private let id = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF0123456789")!

    private func snapshot(body: String = "the body",
                          lat: Double? = nil, lon: Double? = nil,
                          accuracy: Double? = nil, place: String? = nil) -> NoteSnapshot {
        NoteSnapshot(id: id, body: body, createdAt: at,
                     latitude: lat, longitude: lon, horizontalAccuracy: accuracy, placeName: place)
    }

    /// Mirror the serializer's UTC ISO-8601 so we assert the real value, not a guess.
    private var expectedISO: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: at)
    }

    @Test func markdown_hasFrontmatterCreatedAndBody() {
        let md = serializer.markdown(for: snapshot(body: "hello world"))
        #expect(md.hasPrefix("---\n"))
        #expect(md.contains("created: \(expectedISO)"))
        #expect(md.contains("\n---\n"))          // closing fence
        #expect(md.contains("hello world"))
    }

    @Test func markdown_omitsLocationKeys_whenNoLocation() {
        let md = serializer.markdown(for: snapshot())
        #expect(!md.contains("latitude:"))
        #expect(!md.contains("longitude:"))
        #expect(!md.contains("accuracy_m:"))
        #expect(!md.contains("place:"))
    }

    @Test func markdown_includesLocation_localeIndependentDecimals() {
        let md = serializer.markdown(for: snapshot(lat: 37.3349, lon: -122.009, accuracy: 5))
        // %.6f is locale-independent — a comma-decimal locale must not corrupt YAML.
        #expect(md.contains("latitude: 37.334900"))
        #expect(md.contains("longitude: -122.009000"))
        #expect(md.contains("accuracy_m: 5.000000"))
    }

    @Test func markdown_quotesPlaceName_andEscapesQuotes() {
        let plain = serializer.markdown(for: snapshot(lat: 1, lon: 2, place: "Apple Park"))
        #expect(plain.contains("place: \"Apple Park\""))

        let tricky = serializer.markdown(for: snapshot(lat: 1, lon: 2, place: "He said \"hi\""))
        #expect(tricky.contains("place: \"He said \\\"hi\\\"\""))
    }

    @Test func fileName_isUTCTimestampPlusIdSuffix_dotMd() {
        let name = serializer.fileName(for: snapshot())
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = TimeZone(identifier: "UTC")
        stamp.dateFormat = "yyyy-MM-dd-HHmmss"
        #expect(name.hasPrefix(stamp.string(from: at)))
        #expect(name.hasSuffix(".md"))
        #expect(name.contains("a1b2c3d4"))       // lowercased, dash-stripped id prefix
    }

    @Test func fileName_isUnique_forDistinctIdsSameInstant() {
        let a = NoteSnapshot(id: UUID(), body: "a", createdAt: at)
        let b = NoteSnapshot(id: UUID(), body: "b", createdAt: at)
        #expect(serializer.fileName(for: a) != serializer.fileName(for: b))
    }
}

// MARK: - RetentionMachine (pure, total transition function)

struct RetentionMachineTests {
    @Test func keptOrPending_beginWrite_goesToWriting() {
        #expect(RetentionMachine.next(.kept, .beginWrite) == .writing)
        #expect(RetentionMachine.next(.pending(nil), .beginWrite) == .writing)
        #expect(RetentionMachine.next(.pending(.writeFailed), .beginWrite) == .writing)
    }

    @Test func writing_confirm_goesToConfirmed() {
        #expect(RetentionMachine.next(.writing, .confirm) == .confirmed)
    }

    @Test func writing_fail_returnsToPendingWithReason() {
        #expect(RetentionMachine.next(.writing, .fail(.accessLost)) == .pending(.accessLost))
    }

    @Test func confirmed_commit_goesToDeleted() {
        #expect(RetentionMachine.next(.confirmed, .commit) == .deleted)
    }

    @Test func illegalTransitions_areNoOps() {
        #expect(RetentionMachine.next(.kept, .confirm) == .kept)
        #expect(RetentionMachine.next(.writing, .commit) == .writing)          // no delete before confirm
        #expect(RetentionMachine.next(.confirmed, .fail(.writeFailed)) == .confirmed)
        #expect(RetentionMachine.next(.deleted, .beginWrite) == .deleted)      // terminal
    }
}

// MARK: - Note export fields

struct NoteExportFieldsTests {
    @Test func exportStatusRawValues_matchQueryLiterals() {
        // The outbox @Query filters on these string literals.
        #expect(NoteStatus.kept.rawValue == "kept")
        #expect(NoteStatus.pending.rawValue == "pending")
        #expect(NoteStatus.writing.rawValue == "writing")
        #expect(NoteStatus.confirmed.rawValue == "confirmed")
    }

    @Test func exportFailure_roundTripsThroughRawString() {
        let note = Note(body: "x")
        note.exportFailure = .accessLost
        #expect(note.exportFailureRaw == "accessLost")
        #expect(note.exportFailure == .accessLost)
        note.exportFailure = nil
        #expect(note.exportFailureRaw == nil)
    }

    @Test func retentionState_mapsFromPersistedStatus() {
        let note = Note(body: "x")
        note.status = .kept;      #expect(note.retentionState == .kept)
        note.status = .writing;   #expect(note.retentionState == .writing)
        note.status = .confirmed; #expect(note.retentionState == .confirmed)
        note.status = .pending;   note.exportFailure = .writeFailed
        #expect(note.retentionState == .pending(.writeFailed))
    }
}

// MARK: - ExportCoordinator (SwiftData glue) with a mock destination

/// Records the batch it received and returns a scripted per-note outcome.
/// `@MainActor` mirrors `MockLocationProvider` — the seam is main-actor-confined.
@MainActor
final class MockDestination: ExportDestination {
    private(set) var received: [SerializedNote] = []
    var outcomeFor: (SerializedNote) -> ExportOutcome

    init(outcomeFor: @escaping (SerializedNote) -> ExportOutcome = { .confirmed(id: $0.id) }) {
        self.outcomeFor = outcomeFor
    }

    func export(_ notes: [SerializedNote]) async -> [ExportOutcome] {
        received = notes
        return notes.map(outcomeFor)
    }
}

@MainActor
struct ExportCoordinatorTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }
    private func count(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }
    @discardableResult
    private func keptNote(_ body: String, in context: ModelContext) -> Note {
        let note = Note(body: body)
        note.status = .kept
        context.insert(note)
        return note
    }

    @Test func exportAll_allConfirmed_deletesEveryNote() async throws {
        let context = try makeContext()
        keptNote("a", in: context)
        keptNote("b", in: context)
        try context.save()

        let mock = MockDestination()   // confirms all
        let confirmed = await ExportCoordinator(destination: mock).exportAll(in: context)

        #expect(confirmed == 2)
        #expect(try count(context) == 0)         // hold-until-confirmed → deleted only after confirm
        #expect(mock.received.count == 2)
    }

    @Test func exportAll_partialFailure_failedNoteStaysPendingWithReason() async throws {
        let context = try makeContext()
        keptNote("winner", in: context)
        let loser = keptNote("loser", in: context)
        try context.save()
        let loserID = loser.id

        let mock = MockDestination(outcomeFor: { item in
            item.id == loserID ? .failed(id: item.id, reason: .accessLost) : .confirmed(id: item.id)
        })
        let confirmed = await ExportCoordinator(destination: mock).exportAll(in: context)

        #expect(confirmed == 1)
        let remaining = try context.fetch(FetchDescriptor<Note>())
        #expect(remaining.count == 1)
        let survivor = try #require(remaining.first)
        #expect(survivor.id == loserID)
        #expect(survivor.status == .pending)            // NOT deleted
        #expect(survivor.exportFailure == .accessLost)  // reason preserved
    }

    @Test func exportAll_ignoresInboxAndSnoozedNotes() async throws {
        let context = try makeContext()
        let inbox = Note(body: "inbox"); context.insert(inbox)          // default .inbox
        let snoozed = Note(body: "snoozed"); snoozed.status = .snoozed; context.insert(snoozed)
        keptNote("kept", in: context)
        try context.save()

        let mock = MockDestination()
        let confirmed = await ExportCoordinator(destination: mock).exportAll(in: context)

        #expect(confirmed == 1)
        #expect(mock.received.count == 1)                    // only the kept note was serialized
        let remaining = try context.fetch(FetchDescriptor<Note>())
        #expect(Set(remaining.map(\.body)) == ["inbox", "snoozed"])   // both untouched
    }

    @Test func exportAll_reExportsPreviouslyFailedPendingNote() async throws {
        let context = try makeContext()
        let note = Note(body: "retry me")
        note.status = .pending
        note.exportFailure = .accessLost
        context.insert(note)
        try context.save()

        let mock = MockDestination()   // now succeeds
        let confirmed = await ExportCoordinator(destination: mock).exportAll(in: context)

        #expect(confirmed == 1)
        #expect(try count(context) == 0)
    }

    @Test func exportAll_emptyOutbox_isNoOp() async throws {
        let context = try makeContext()
        let mock = MockDestination()
        let confirmed = await ExportCoordinator(destination: mock).exportAll(in: context)
        #expect(confirmed == 0)
        #expect(mock.received.isEmpty)
    }

    @Test func exportAll_serializesBodyAndLocationIntoPayload() async throws {
        let context = try makeContext()
        let note = keptNote("hello world", in: context)
        note.latitude = 51.5; note.longitude = -0.12; note.horizontalAccuracy = 5
        try context.save()

        let mock = MockDestination()
        _ = await ExportCoordinator(destination: mock).exportAll(in: context)

        let payload = try #require(mock.received.first)
        #expect(payload.markdown.contains("hello world"))
        #expect(payload.markdown.contains("latitude: 51.500000"))
    }

    @Test func exportableCount_countsKeptAndPendingOnly() async throws {
        let context = try makeContext()
        keptNote("k", in: context)
        let p = Note(body: "p"); p.status = .pending; context.insert(p)
        let i = Note(body: "i"); context.insert(i)             // inbox — excluded
        try context.save()

        let count = ExportCoordinator(destination: MockDestination()).exportableCount(in: context)
        #expect(count == 2)
    }
}
