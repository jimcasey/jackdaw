---
name: slice-2-spec
description: Slice 2 spec decisions — thin capture + SwiftData; Note model shape, MVVM↔SwiftData reconciliation (reads-in-view/writes-in-VM), AUTOSAVE-as-you-type capture model (lazy-create/prune-on-abandon), tab-shell-now, schema-evolution stance.
metadata:
  type: project
---

**Slice 2 spec lives in `docs/slices/slice-2-capture-swiftdata.md`** (tech-lead, 2026-07-14). Introduces SwiftData persistence (ADR 0003) + the Capture screen. Honors design-lead's capture flow (`docs/design/capture-and-triage-flows.md` §1) and two-tab nav (`docs/design/navigation-and-screen-inventory.md` §2). **Simulator is sufficient to verify** (no entitlement / sandbox-crossing, unlike Slice 1). Prereq: Slice 1 PASSED, T2 ratified; Talon core in `Jackdaw/Talon/` (UNTOUCHED by Slice 2 — capture persists to SwiftData only, no vault/export).

**Note `@Model` (Slice 2 shape):** `final class Note { var id: UUID; var body: String; var createdAt: Date }`. `@Model` requires a class (SwiftData tracks by reference identity to observe mutations). `id` is a stable UUID separate from PersistentIdentifier (needed later for export/filename).

**Schema-evolution call (prevents drift):** ADD location (Slice 3) and lifecycle `status` (Slice 4) AT THEIR SLICES, not now. Reasoning: a field with no code to set it is dead weight + audit hazard; the changes are ADDITIVE so SwiftData does automatic LIGHTWEIGHT migration (optional property or property-with-default = no migration code); and pre-release single-user/zero-shipped-data means even a breaking change is a non-event (just RESET the local store = delete app). **Do NOT write a `SchemaMigrationPlan` until there is real data worth migrating (post-Slice-6 daily use).** Guidance: when location/status land, add as optional or with a default (keeps migration lightweight); prefer store-reset over migration pre-release.

**MVVM ↔ SwiftData reconciliation (the real architectural decision):** "Views own reads; a thin view-model owns write commands."
- `@Query` and `@Environment(\.modelContext)` are SwiftUI-View-only property wrappers; `@Query` = a live reactive fetch wired into SwiftUI's render loop (≈ useLiveQuery hook) — CANNOT be hoisted into a plain view-model without losing reactivity. Strict "all data access in the VM" MVVM fights the framework.
- READS stay in the View via `@Query` (Triage list, Slice 4 / the stub this slice). Don't launder reads through a VM.
- WRITES/business logic go through a small `@Observable CaptureViewModel` that is NOT SwiftUI-coupled and receives a `ModelContext` INJECTED per call (never reaches the environment) → stays off-device-testable.
- This is the pragmatic MVVM CLAUDE.md actually asks for (separation + testability without dogma).

**CAPTURE = AUTOSAVE-AS-YOU-TYPE (owner override 2026-07-14, replaced the earlier explicit-save model).** Three owner-confirmed rules, all owned by `@Observable CaptureViewModel` holding `private(set) var draft: Note?` + injected `ModelContext` per call:
- **Lazy row creation** on the FIRST non-whitespace char (NOT on focus) — no empty rows from just opening Capture. In `edit(_ text:in:)`: if `draft==nil` and trimmed non-empty → `context.insert(Note(body:text)); draft=note`; else `draft?.body = text`.
- **Debounced autosave + background flush** — RELY on SwiftData mainContext built-in autosave (`autosaveEnabled` default true) for as-you-type coalescing; do NOT `context.save()` per keystroke (jank + fights autosave). Add ONE explicit `try? context.save()` on `.background` for durability. Only if autosave latency is too loose, hand-roll a ~0.5s cancel/reschedule Task debounce AND set `context.autosaveEnabled=false` (one owner of save cadence — never both).
- **Prune-on-abandon** in `finishEditing(in:)` (idempotent, guards on draft): if draft body trimmed-empty → `context.delete`; then `draft=nil` (detach → next keystroke = fresh row); `try? context.save()`.

**Trigger wiring in CaptureView:** `.onChange(of: text)`→`vm.edit`; `.onChange(of: scenePhase)` `.background`→`vm.finishEditing` (covers swipe-kill, which happens after background); `.onDisappear`→`vm.finishEditing` + clear `text=""`. **iOS gotchas:** TabView `.onDisappear` on tab-switch is historically finicky — if a fragment survives a fast tab-switch, hoist a `selection`-bound `@State` in RootView and prune on `.onChange(of: selectedTab)`. `TextEditor` has NO placeholder (overlay a Text). Focus-on-launch: set `@FocusState` true in `.task` (NOT `.onAppear` — dropped). Full-bleed `TextEditor`, NOT bordered TextField (design forbids web-textarea look); Return = newline (don't remap). No Save button, no per-save haptic/confirmation (no discrete save event); field clears only on leave→return (commit-and-fresh).

**Seam contract (Slice 3 backfill, still honored):** note is created synchronously in `edit()` before any GPS fix; Slice 3 kicks off the async location request AT THE CREATE STEP bound to THAT specific `Note` instance, and writes the fix onto that instance when it arrives — even after `draft` detaches. No `await` in the capture path; no rewrite needed.

**App wiring:** `.modelContainer(for: Note.self)` on the app scene (default on-disk store in App Support — internal, unrelated to Talon vault bookmark). **Two-tab `Capture | Triage` shell built NOW** with throwaway `TriageStubView` (`@Query` list/count of notes) that doubles as the persistence-verification surface (Capture shows no list by design). Stub replaced by real inbox at Slice 4. Always launch to Capture. **`VaultProofView` PARKED** (unreferenced; Talon core `Jackdaw/Talon/` UNTOUCHED).

**Testing:** off-device Swift Testing, IN-MEMORY container (`ModelConfiguration(isStoredInMemoryOnly: true)`), drive `edit`/`finishEditing`: lazy-create (empty/whitespace→0 rows; first non-ws→1), update-in-place (not a 2nd row), prune-empty-on-finish→0, commit-non-empty→1+detach, idempotent finish, fresh-session-after-commit→2 distinct ids. Simulator-only: keyboard-up/focus/placeholder; autosave durability across relaunch (type → background → relaunch → Triage stub shows it; also swipe-kill variant); prune-on-abandon (type-then-clear-then-leave → no empty row); commit-and-fresh.

**ALL FOUR owner calls now SETTLED (2026-07-14):** (1) tab shell now = YES; (2) defer location/status fields = YES; (3) VaultProofView = PARK; (4) capture = AUTOSAVE (not explicit-save).

**Design-alignment items OUTSTANDING (design-lead updating its capture-flow doc in parallel — align to it, flag disagreement):**
- **Rapid multi-capture** (design §1.5 "three thoughts in a row"): autosave model = ONE continuous Capture session is ONE note (field resets only on leave→return). Three-in-a-row WITHOUT leaving needs an in-session "new note" trigger/gesture — DESIGN's to define; VM supports it (finishEditing + clear on that gesture). This is the sharpest divergence from the old design doc.
- Leave-mid-edit: commit-and-fresh (implemented) vs resume-draft — design's call.
- Exact prune leave-set (tab-switch/background/cleared-then-leave) must match design's updated flow.

See [[slice-1-spec]] (Talon seed + T2), [[stack-recommendations]] (ADR 0003 SwiftData), [[build-order]] (Slice 2 context + seam contracts).
