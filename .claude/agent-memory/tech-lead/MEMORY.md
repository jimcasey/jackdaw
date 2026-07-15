# Memory Index

- [Obsidian write mechanism decision](decision-obsidian-write.md) — ADR 0001: folder-write via security-scoped bookmark; git-push is the fallback.
- [iOS platform gotchas](ios-gotchas.md) — Verified sandbox/URL-scheme/bookmark facts to avoid re-deriving or misciting.
- [Walking-skeleton build order](build-order.md) — Ratified slice sequence in docs/build-order.md; lazy vault setup, two-tab nav, Talon seam contracts, open owner calls.
- [Stack ADRs 0002/0003](stack-recommendations.md) — Ratified: min iOS target = iOS 26 (ADR 0002), persistence = SwiftData (ADR 0003); load-bearing at Slice 0 / Slice 2.
- [Slice 1 spec](slice-1-spec.md) — Vault bookmark write+verify harness in docs/slices/; Talon seam seed, UserDefaults storage, no-iOS-entitlement fact, T2/T1 PASS/FAIL protocol. PASSED on-device; T2 ratified.
- [Slice 2 spec](slice-2-spec.md) — Thin capture + SwiftData in docs/slices/; Note model, MVVM↔SwiftData, AUTOSAVE-as-you-type (lazy-create/prune-on-abandon), additive migration. Nav flipped to sheet (see below).
- [Capture nav pivot + external capture](capture-nav-and-external.md) — Nav flip to Triage-root + auto Capture sheet; CaptureNoteIntent seam; HARD FINDING: no-launch App Intent can't get precise GPS → external captures timestamp-only. ADR 0004/0005 recommended.
- [Slice 4 triage spec](slice-4-triage-spec.md) — Real Triage inbox in docs/slices/; NoteStatus enum (raw-string storage), calendar-day snooze model, discard-undo (deferred-delete, rec ADOPT), light editing, @Query+VM split.
- [Slice 5 location spec](slice-5-location-spec.md) — In-app precise GPS in docs/slices/; nullable coord fields (no persisted pending enum), mockable LocationProviding + async backfill bound to Note (pruned-note guard), When-In-Use precise + Info.plist, geocode-at-display.
