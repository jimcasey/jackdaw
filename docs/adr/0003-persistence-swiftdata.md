# ADR 0003 — Persistence = SwiftData

> **Status:** Accepted — local persistence is **SwiftData**.
> **Date:** 2026-07-14
> **Owner of decision:** tech-lead, arbitrated and ratified by owner.
> **Load-bearing at:** Slice 2 (thin capture) — the first slice that persists a
> growing collection of structured, mutable records across launches. Slices 0–1
> do **not** need it. See `docs/build-order.md`.
> **Depends on:** ADR 0002 (min target iOS 26) — SwiftData requires an iOS 17+
> floor, which iOS 26 clears.

## Context

CLAUDE.md marks persistence as TBD (SwiftData vs. Core Data vs. files/UserDefaults)
and requires an ADR before we rely on it. It becomes load-bearing at Slice 2,
where captured notes must be queued locally and survive relaunch (offline
capture, per the PRD).

**What Jackdaw's data actually is:** a modest, single-device collection of note
records that carry a **lifecycle state machine** — `captured → kept | snoozed |
discarded → pending → writing → confirmed → deleted` (see ADR 0001's retention
model). The data is *queried* for the triage inbox and *mutated* as notes move
through that machine. This is "small relational store with observation," not
"key-value blob" and not "opaque document."

Candidates:
- **`UserDefaults`** — a key-value store for small preference values. Wrong tool
  for a collection of records with lifecycle. **Disqualified.**
- **Files (Codable JSON on disk)** — workable at our low volume, but we would
  hand-roll querying, change-observation, and migration. Viable but rebuilds what
  a store gives for free.
- **Core Data** — mature and battle-tested, but a heavier API with more ceremony
  than we need, and a weaker fit with SwiftUI's declarative/observation model.
- **SwiftData** — Apple's SwiftUI-native persistence framework, introduced in
  iOS 17 and hardened since.

## Decision

**Adopt SwiftData as the local persistence layer.**

Rationale:
1. **SwiftUI-native, and closest to the owner's mental model.** You declare a
   model with the `@Model` macro (analogous to an ORM entity), and SwiftUI views
   observe it with `@Query` (analogous to a live, auto-updating reactive query
   binding — the kind of data hook the owner knows from the web/React side). This
   fits the SwiftUI + MVVM stack default with the least boilerplate.
2. **Right shape for our data.** A small collection of records with a lifecycle
   state machine is exactly SwiftData's sweet spot — declare the note model,
   query the inbox, mutate state as notes advance through retention.
3. **Maturity via the target.** With ADR 0002 setting the target at iOS 26, we get
   SwiftData well past its iOS 17 debut — no weak-linking or availability
   workarounds.

## Consequences

**Positive**
- Minimal boilerplate; models and queries read cleanly, easing owner audit.
- Native SwiftUI observation — the triage inbox updates reactively as notes change
  state, without manual glue.
- The retention state machine (ADR 0001) persists naturally as a field on the note
  model.

**Negative / accepted**
- **Hard floor: iOS 17+.** SwiftData does not run below iOS 17. This constrains
  ADR 0002 — satisfied there by the iOS 26 target. If the min target were ever
  lowered below 17, this decision would have to be revisited (Core Data fallback).
- SwiftData is younger than Core Data; some advanced scenarios (complex
  migrations, fine-grained concurrency) are less battle-tested. **Accepted** — our
  schema is small and single-user; we are not in the hard-migration regime. If we
  ever hit a SwiftData limitation, SwiftData is built on Core Data and interop is
  possible, so this is not a one-way door.

## Related
- ADR 0002 (min target iOS 26) — provides the required iOS 17+ floor.
- ADR 0001 (Obsidian write / retention state machine) — the note lifecycle this
  store persists.
- Build order: `docs/build-order.md` (load-bearing at Slice 2).
- CLAUDE.md stack defaults (persistence was TBD; this ratifies it).
