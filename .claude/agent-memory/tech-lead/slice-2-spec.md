---
name: slice-2-spec
description: Slice 2 spec decisions — thin capture + SwiftData; the Note model shape, the MVVM↔SwiftData reconciliation (reads-in-view / writes-in-viewmodel), tab-shell-now call, and schema-evolution stance.
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

**Capture flow (honors design §1):** launch-to-Capture keyboard-up; full-bleed `TextEditor` (NOT bordered TextField — design forbids web-textarea look); Return = newline (do NOT remap to save); explicit top-bar Save button disabled-when-empty (not Return, not auto-save); on Save persist immediately, clear field, KEEP focus, quiet haptic/checkmark, STAY on Capture (rapid multi-capture is first-class). iOS gotchas noted: `TextEditor` has NO placeholder (overlay a Text); focus-on-appear is flaky in `.onAppear` — set focus in `.task`. **Seam contract:** `CaptureViewModel.save(text:in:) -> Note?` persists synchronously BEFORE any GPS fix and RETURNS the note so Slice 3 backfills location async on the same context — do NOT add `await` to the capture path. Uncommitted in-progress text is intentionally NOT draft-saved (design's explicit-save choice).

**App wiring calls:**
- `.modelContainer(for: Note.self)` on the app scene (default on-disk store in App Support, internal — unrelated to the Talon vault bookmark).
- **Two-tab `Capture | Triage` shell introduced NOW** (recommended): building CaptureView into its real home avoids a Slice-4 re-wire, AND the throwaway `TriageStubView` (a `@Query` list/count of captured notes) solves the Slice-2 verification gap (Capture shows no list by design, so the stub is how you SEE persistence across relaunch). Stub is replaced by the real inbox at Slice 4. Always launch to Capture (don't restore last tab). Keyboard-hides-floating-tab-bar wrinkle is intentional (design), no fix needed.
- **`VaultProofView`:** park (keep file, unreference from root) until Slice 6 supersedes it; deleting also fine (git preserves). Talon core untouched.

**Testing:** off-device Swift Testing with an IN-MEMORY container (`ModelConfiguration(isStoredInMemoryOnly: true)`): CaptureViewModel.save happy path (1 note, trimmed body, createdAt~now, id set), empty/whitespace guard (nil, no insert), trimming, multiple-saves-accumulate. Simulator-only: keyboard-up-on-launch/focus/editor feel/Save enable-disable/haptic, and persistence-across-relaunch (capture → Triage stub shows it → relaunch → still there; simulator suffices — no device needed, all in-container).

**Open owner confirmations:** (1) tab shell now (rec yes); (2) defer location/status fields to their slices (rec yes); (3) VaultProofView park vs delete (rec park); (4) uncommitted text not draft-saved is acceptable (rec yes).

See [[slice-1-spec]] (Talon seed + T2), [[stack-recommendations]] (ADR 0003 SwiftData), [[build-order]] (Slice 2 context + seam contracts).
