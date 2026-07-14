---
name: stack-recommendations
description: The two ratified stack ADRs — ADR 0002 min iOS target = iOS 26, ADR 0003 persistence = SwiftData; when each is load-bearing, the reasoning, and their coupling.
metadata:
  type: project
---

Both TBD stack items are now DECIDED and WRITTEN as ADRs (owner-ratified 2026-07-14). ADRs are authoritative; this is the quick-reference.

**ADR 0002 — Min iOS target = iOS 26** (`docs/adr/0002-min-ios-deployment-target.md`, Accepted).
- **Load-bearing at Slice 0** (set at Xcode project creation; gates every API).
- **Why:** deployment target = OLDEST OS supported. Lower = more devices, fewer APIs (need `@available` fallbacks). Higher = modern APIs freely. Jackdaw is single-user on the owner's own phone → NO install base → take the highest target the device runs, buy cleanest API surface + most mature SwiftData. iOS 26 is the current major as of 2026-07 (Apple renumbered iOS 18→26 in 2025 to align OS names with the year; iOS 27 ships fall 2026). Raising the target later is free; lowering strands APIs — chose the easy-to-relax direction.

**ADR 0003 — Persistence = SwiftData** (`docs/adr/0003-persistence-swiftdata.md`, Accepted).
- **Load-bearing at Slice 2** (first growing collection of structured mutable records across launches). NOT needed for Slice 0/1 (bookmark = single blob).
- **Why:** our data = modest single-device note collection WITH a lifecycle state machine (captured→kept/snoozed/discarded→pending→…→deleted), queried for inbox, mutated at triage. UserDefaults DISQUALIFIED (prefs, not record collections); files/JSON viable but hand-roll query/observation/migration; Core Data mature but heavier + weaker SwiftUI fit; SwiftData = SwiftUI-native, closest to web-eng model (`@Model` ≈ ORM entity; `@Query` ≈ live reactive query binding), fits MVVM/SwiftUI default, least boilerplate.
- **HARD COUPLING:** SwiftData requires **iOS 17+**; ADR 0002's iOS 26 clears it. 0002 is a prerequisite of 0003.

**How to apply:** Do not relitigate — both ratified. If a slice reaches for an API, we can call it directly (no `@available` gymnastics under iOS 26). If SwiftData ever hits a limit, it's built on Core Data so interop is possible (not a one-way door). Confirm the current iOS major before asserting a version number (checked 26.x on 2026-07-14). See [[build-order]] for slice context.
