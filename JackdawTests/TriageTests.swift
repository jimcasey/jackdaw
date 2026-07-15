import Testing
import Foundation
import SwiftData
@testable import Jackdaw

/// Snooze scheduling — pure, deterministic (fixed dates + injected calendar, never
/// `Date()` in the assertion path).
struct SnoozeScheduleTests {
    private func utc() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // A fixed instant to anchor the day math.
    private let snoozedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func reappearBoundary_isStartOfNextLocalDay() {
        let cal = utc()
        let boundary = SnoozeSchedule.reappearBoundary(snoozedAt: snoozedAt, calendar: cal)
        let expected = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: snoozedAt))!
        #expect(boundary == expected)
        #expect(boundary > snoozedAt)
    }

    @Test func isDue_acrossDayRollover() {
        let cal = utc()
        let boundary = SnoozeSchedule.reappearBoundary(snoozedAt: snoozedAt, calendar: cal)
        // Same sitting (a few hours later, still before the next-day boundary): hidden.
        #expect(SnoozeSchedule.isDue(snoozedUntil: boundary, now: snoozedAt.addingTimeInterval(8 * 3600)) == false)
        // Just before the boundary: still hidden.
        #expect(SnoozeSchedule.isDue(snoozedUntil: boundary, now: boundary.addingTimeInterval(-1)) == false)
        // Exactly at the boundary: due.
        #expect(SnoozeSchedule.isDue(snoozedUntil: boundary, now: boundary) == true)
        // Next morning: due.
        #expect(SnoozeSchedule.isDue(snoozedUntil: boundary, now: boundary.addingTimeInterval(9 * 3600)) == true)
    }

    @Test func reappearBoundary_isLocalDay_perCalendar() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        for cal in [utc(), tokyo] {
            let b = SnoozeSchedule.reappearBoundary(snoozedAt: snoozedAt, calendar: cal)
            #expect(b == cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: snoozedAt))!)
        }
    }
}

/// Guards the `@Query` string literals against enum drift.
struct NoteStatusRawTests {
    @Test func rawValuesMatchQueryLiterals() {
        #expect(NoteStatus.inbox.rawValue == "inbox")
        #expect(NoteStatus.snoozed.rawValue == "snoozed")
        #expect(NoteStatus.kept.rawValue == "kept")
    }
}

@MainActor
struct TriageViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }
    private func noteCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<Note>()).count
    }
    private func utc() -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func keep_setsKept() throws {
        let context = try makeContext()
        let vm = TriageViewModel()
        let note = Note(body: "x"); context.insert(note)
        vm.keep(note, in: context)
        #expect(note.status == .kept)
    }

    @Test func snooze_setsBoundaryAndIncrementsCount() throws {
        let context = try makeContext()
        let vm = TriageViewModel(now: { self.fixedNow }, calendar: utc())
        let note = Note(body: "x"); context.insert(note)
        vm.snooze(note, in: context)
        #expect(note.status == .snoozed)
        #expect(note.snoozedUntil == SnoozeSchedule.reappearBoundary(snoozedAt: fixedNow, calendar: utc()))
        #expect(note.snoozeCount == 1)
        vm.snooze(note, in: context)
        #expect(note.snoozeCount == 2)
    }

    @Test func visibleNotes_showsInboxAndDueSnoozed_only() throws {
        let vm = TriageViewModel(now: { self.fixedNow })
        let inbox = Note(body: "i")
        let dueSnoozed = Note(body: "d"); dueSnoozed.status = .snoozed; dueSnoozed.snoozedUntil = fixedNow.addingTimeInterval(-100)
        let notDue = Note(body: "n"); notDue.status = .snoozed; notDue.snoozedUntil = fixedNow.addingTimeInterval(100)
        let kept = Note(body: "k"); kept.status = .kept
        let visible = vm.visibleNotes([inbox, dueSnoozed, notDue, kept])
        #expect(Set(visible.map(\.body)) == ["i", "d"])
        #expect(vm.snoozedNotDue([inbox, dueSnoozed, notDue, kept]).map(\.body) == ["n"])
    }

    @Test func discard_hidesButDoesNotDelete_thenUndoRestores() throws {
        let context = try makeContext()
        let vm = TriageViewModel()
        let note = Note(body: "x"); context.insert(note)
        vm.discard(note)
        #expect(vm.pendingDiscard.contains(note.id))
        #expect(vm.visibleNotes([note]).isEmpty)      // hidden
        #expect(try noteCount(context) == 1)           // NOT deleted
        vm.undoDiscard(note.id)
        #expect(vm.visibleNotes([note]).count == 1)    // restored
        #expect(try noteCount(context) == 1)
    }

    @Test func commitDiscard_deletes() throws {
        let context = try makeContext()
        let vm = TriageViewModel()
        let note = Note(body: "x"); context.insert(note)
        vm.discard(note)
        vm.commitDiscard(note.id, in: context)
        #expect(try noteCount(context) == 0)
    }
}
