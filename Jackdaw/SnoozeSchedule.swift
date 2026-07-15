import Foundation

/// The snooze-session model (design `open-ux-threads.md` Thread 1), made concrete.
///
/// Key realization: **the calendar-day boundary IS the session boundary** — no
/// session-id field is needed. Snoozing hides a note for the rest of the current
/// sitting and it reappears at the first Triage open on a *later calendar day*,
/// which is exactly "due once we pass the start of the next local day."
///
/// Pure functions with an injectable `Calendar`, so the day/timezone logic is
/// unit-testable across a rollover without touching `Date.now`.
enum SnoozeSchedule {
    /// The instant a note snoozed at `snoozedAt` becomes due again: the start of
    /// the NEXT local calendar day.
    static func reappearBoundary(snoozedAt: Date, calendar: Calendar = .current) -> Date {
        let startOfSnoozeDay = calendar.startOfDay(for: snoozedAt)
        return calendar.date(byAdding: .day, value: 1, to: startOfSnoozeDay)!
    }

    /// Due once we're at or past the boundary. Plain date compare (no calendar) so
    /// it is predicate-friendly and trivially testable.
    static func isDue(snoozedUntil: Date, now: Date) -> Bool { now >= snoozedUntil }
}
