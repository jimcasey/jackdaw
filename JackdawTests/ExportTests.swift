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

    @Test func writing_interrupt_requeuesAsReasonlessPending() {
        // Startup recovery for a note stranded mid-write: back to pending, no reason.
        #expect(RetentionMachine.next(.writing, .interrupt) == .pending(nil))
    }

    @Test func illegalTransitions_areNoOps() {
        #expect(RetentionMachine.next(.kept, .confirm) == .kept)
        #expect(RetentionMachine.next(.writing, .commit) == .writing)          // no delete before confirm
        #expect(RetentionMachine.next(.confirmed, .fail(.writeFailed)) == .confirmed)
        #expect(RetentionMachine.next(.deleted, .beginWrite) == .deleted)      // terminal
        #expect(RetentionMachine.next(.kept, .interrupt) == .kept)             // interrupt only acts on writing
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
    /// Fires at the moment the destination is invoked — after the coordinator's
    /// pre-write save — so a test can inspect note state mid-flight.
    var onExport: (() -> Void)?

    init(outcomeFor: @escaping (SerializedNote) -> ExportOutcome = { .confirmed(id: $0.id) }) {
        self.outcomeFor = outcomeFor
    }

    func export(_ notes: [SerializedNote]) async -> [ExportOutcome] {
        received = notes
        onExport?()
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

    @Test func exportableCount_countsKeptAndPending_excludesEverythingElse() async throws {
        let context = try makeContext()
        keptNote("k", in: context)
        let p = Note(body: "p"); p.status = .pending; context.insert(p)
        let i = Note(body: "i"); context.insert(i)                 // inbox — excluded
        let s = Note(body: "s"); s.status = .snoozed; context.insert(s)   // excluded
        // In-flight / interrupted notes must be invisible to a fresh export run.
        let w = Note(body: "w"); w.status = .writing; context.insert(w)   // excluded
        let c = Note(body: "c"); c.status = .confirmed; context.insert(c) // excluded
        try context.save()

        let count = ExportCoordinator(destination: MockDestination()).exportableCount(in: context)
        #expect(count == 2)
    }

    /// The kill-safe guard: `export(_:)` must NOT advance/delete a stray un-triaged
    /// note, even though `Note.retentionState` maps inbox/snoozed → `.kept`.
    @Test func export_directCall_ignoresNonExportableNotes_neverDeletes() async throws {
        let context = try makeContext()
        let inbox = Note(body: "inbox"); context.insert(inbox)
        let snoozed = Note(body: "snoozed"); snoozed.status = .snoozed; context.insert(snoozed)
        try context.save()

        let mock = MockDestination()   // would confirm (→ delete) anything it received
        let confirmed = await ExportCoordinator(destination: mock).export([inbox, snoozed], in: context)

        #expect(confirmed == 0)
        #expect(mock.received.isEmpty)        // never even serialized
        #expect(try count(context) == 2)      // both captures survive intact
        #expect(inbox.status == .inbox)
        #expect(snoozed.status == .snoozed)
    }

    @Test func export_persistsWritingBeforeAwaitingDestination() async throws {
        // Kill-safety invariant: notes are marked (and saved) `.writing` BEFORE the
        // possibly-slow/interactive destination runs, so a mid-export kill is recoverable.
        let context = try makeContext()
        let a = keptNote("a", in: context)
        let b = keptNote("b", in: context)
        try context.save()

        let mock = MockDestination()
        var sawWritingAtExport = false
        mock.onExport = { sawWritingAtExport = (a.status == .writing && b.status == .writing) }

        _ = await ExportCoordinator(destination: mock).exportAll(in: context)

        #expect(sawWritingAtExport)
    }
}

// MARK: - ObsidianFolderDestination (the real Slice 7 destination) — batch fold

/// Covers the per-note write+verify fold that Slice 7 reuses verbatim. `writeBatch`
/// is split from the security-scope layer precisely so it's testable off-device
/// against a plain temp directory; the vault-level failure path is testable via a
/// `VaultAccess` with no saved bookmark (it throws before any scoping).
struct ObsidianFolderDestinationTests {
    private func tempFolder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jackdaw-obsidian-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func emptyVaultAccess() -> VaultAccess {
        VaultAccess(store: UserDefaultsVaultBookmarkStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    }
    private func item(_ markdown: String, fileName: String) -> SerializedNote {
        SerializedNote(id: UUID(), fileName: fileName, markdown: markdown)
    }

    @Test func writeBatch_allSucceed_writesEveryFileAndConfirms() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let dest = ObsidianFolderDestination(access: emptyVaultAccess())   // access unused by writeBatch
        let notes = [item("one", fileName: "a.md"), item("two", fileName: "b.md")]

        let outcomes = dest.writeBatch(notes, into: folder)

        #expect(outcomes == notes.map { .confirmed(id: $0.id) })
        #expect(try Data(contentsOf: folder.appendingPathComponent("a.md")) == Data("one".utf8))
        #expect(try Data(contentsOf: folder.appendingPathComponent("b.md")) == Data("two".utf8))
    }

    @Test func writeBatch_oneBadFilename_failsOnlyThatNote() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let dest = ObsidianFolderDestination(access: emptyVaultAccess())
        let good = item("ok", fileName: "good.md")
        let bad = item("nope", fileName: "missing-subdir/bad.md")   // parent dir absent → write fails

        let outcomes = dest.writeBatch([good, bad], into: folder)

        #expect(outcomes[0] == .confirmed(id: good.id))
        #expect(outcomes[1] == .failed(id: bad.id, reason: .writeFailed))
    }

    @MainActor
    @Test func export_noVaultConfigured_failsWholeBatch() async {
        let dest = ObsidianFolderDestination(access: emptyVaultAccess())
        let notes = [item("x", fileName: "x.md"), item("y", fileName: "y.md")]

        let outcomes = await dest.export(notes)

        #expect(outcomes == notes.map { .failed(id: $0.id, reason: .noVaultConfigured) })
    }
}

// MARK: - ExportReconciler (startup recovery of stranded writing notes)

@MainActor
struct ExportReconcilerTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func reconcile_requeuesWritingAsReasonlessPending_leavesOthersUntouched() throws {
        let context = try makeContext()
        let stranded = Note(body: "stranded"); stranded.status = .writing
        let kept = Note(body: "kept"); kept.status = .kept
        let inbox = Note(body: "inbox")
        [stranded, kept, inbox].forEach { context.insert($0) }
        try context.save()

        let recovered = ExportReconciler.reconcileInterruptedWrites(in: context)

        #expect(recovered == 1)
        #expect(stranded.status == .pending)
        #expect(stranded.exportFailure == nil)   // interrupted, not failed — no reason
        #expect(kept.status == .kept)
        #expect(inbox.status == .inbox)
    }

    @Test func reconcile_isIdempotent() throws {
        let context = try makeContext()
        let w = Note(body: "w"); w.status = .writing; context.insert(w)
        try context.save()

        #expect(ExportReconciler.reconcileInterruptedWrites(in: context) == 1)  // recovered
        #expect(ExportReconciler.reconcileInterruptedWrites(in: context) == 0)  // nothing left
    }
}

// MARK: - OutboxSummary (the bottom-bar classifier — Slice 7)

struct OutboxSummaryTests {
    private func note(_ status: NoteStatus, _ reason: ExportFailure? = nil) -> Note {
        let n = Note(body: "x"); n.status = status; n.exportFailure = reason; return n
    }

    @Test func emptyOutbox_isEmpty() {
        #expect(OutboxSummary.classify([]) == .empty)
    }

    @Test func onlyKept_isDraining() {
        // Hybrid: kept notes are auto-exporting; the bar stays silent.
        #expect(OutboxSummary.classify([note(.kept), note(.kept)]) == .draining(count: 2))
    }

    @Test func allNoVault_isNeedsSetup() {
        let outbox = [note(.pending, .noVaultConfigured), note(.pending, .noVaultConfigured)]
        #expect(OutboxSummary.classify(outbox) == .needsSetup(count: 2))
    }

    @Test func writeFailures_areStuckRetry() {
        let outbox = [note(.pending, .writeFailed), note(.pending, .verifyMismatch)]
        // verifyMismatch outranks writeFailed in the dominant-reason priority.
        #expect(OutboxSummary.classify(outbox) == .stuck(count: 2, reason: .verifyMismatch))
    }

    @Test func mixedReasons_pickVaultLevelDominant() {
        // A vault-level blocker (accessLost) wins over a per-note writeFailed:
        // nothing exports until the vault is fixed. Count is the whole pending set.
        let outbox = [note(.pending, .writeFailed), note(.pending, .accessLost), note(.kept)]
        #expect(OutboxSummary.classify(outbox) == .stuck(count: 2, reason: .accessLost))
    }

    @Test func keptAlongsidePending_keptNeverReportedAsStuck() {
        // Invariant: a happily-kept note never inflates the stuck count.
        let outbox = [note(.kept), note(.pending, .accessLost)]
        #expect(OutboxSummary.classify(outbox) == .stuck(count: 1, reason: .accessLost))
    }

    @Test func reasonlessPending_fallsThroughToRetry() {
        // An interrupted write reconciled to pending(nil) reads as a plain Retry.
        #expect(OutboxSummary.classify([note(.pending, nil)]) == .stuck(count: 1, reason: .writeFailed))
    }
}

// MARK: - Return-to-inbox (stuck-note escape hatch — Slice 7)

@MainActor
struct ReturnToInboxTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func returnToInbox_resetsStatusAndClearsReason() throws {
        let context = try makeContext()
        let stuck = Note(body: "stuck"); stuck.status = .pending; stuck.exportFailure = .writeFailed
        let sibling = Note(body: "sib"); sibling.status = .pending; sibling.exportFailure = .accessLost
        [stuck, sibling].forEach { context.insert($0) }
        try context.save()

        TriageViewModel().returnToInbox(stuck, in: context)

        #expect(stuck.status == .inbox)
        #expect(stuck.exportFailure == nil)
        #expect(sibling.status == .pending)          // untouched
        #expect(sibling.exportFailure == .accessLost)
    }

    @Test func returnToInbox_onNonPending_isNoOp() throws {
        let context = try makeContext()
        let kept = Note(body: "k"); kept.status = .kept; context.insert(kept)
        try context.save()

        TriageViewModel().returnToInbox(kept, in: context)

        #expect(kept.status == .kept)               // guard held
    }
}

// MARK: - autoExportKept (hybrid auto-export path — Slice 7)

@MainActor
struct AutoExportKeptTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }
    private func count(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }

    @Test func autoExportKept_drainsKept_ignoresPending() async throws {
        let context = try makeContext()
        let kept = Note(body: "kept"); kept.status = .kept
        let failed = Note(body: "failed"); failed.status = .pending; failed.exportFailure = .writeFailed
        [kept, failed].forEach { context.insert($0) }
        try context.save()

        let mock = MockDestination()   // confirms → deletes
        let confirmed = await ExportCoordinator(destination: mock).autoExportKept(in: context)

        #expect(confirmed == 1)                          // only the kept note exported
        #expect(mock.received.count == 1)
        let remaining = try context.fetch(FetchDescriptor<Note>())
        #expect(remaining.map(\.body) == ["failed"])     // the pending note was NOT auto-retried
        #expect(remaining.first?.status == .pending)
    }

    @Test func autoExportKept_ignoresInFlightWriting() async throws {
        // Race-safety mechanism: a note already `.writing` (a concurrent run claimed
        // it) is never re-fetched, so it can't be double-claimed.
        let context = try makeContext()
        let inFlight = Note(body: "w"); inFlight.status = .writing; context.insert(inFlight)
        try context.save()

        let mock = MockDestination()
        let confirmed = await ExportCoordinator(destination: mock).autoExportKept(in: context)

        #expect(confirmed == 0)
        #expect(mock.received.isEmpty)
        #expect(try count(context) == 1)                 // the writing note is untouched
    }
}
