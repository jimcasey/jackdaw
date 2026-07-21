# Slice 7 — Obsidian export (the real v1 destination — v1 feature-complete)

> **Status:** Spec — not implemented. **Date:** 2026-07-21.
> **Owner of spec:** tech-lead. **Implements:** build-order's **Slice 6 — Obsidian
> export** (the real v1 destination). **Prereqs met:** Slice 1 proved the vault
> bookmark + folder-write on-device (ADR 0001 T2 ratified); Slice 6 built and
> tested the whole pipeline *above* the seam (serializer, machine, coordinator,
> reconciler) against Apple Notes and **already updated `ObsidianFolderDestination`
> to conform to the batch/async/per-note seam**.
>
> **Numbering (same confusion as Slice 6, stated once):** implementation numbering
> runs **one ahead** of `docs/build-order.md`. This is **build-order Slice 6 =
> implementation Slice 7**. The build-order section is titled "Slice 6 — Obsidian
> export"; this file uses impl numbering to sit next to `slice-6-apple-notes-export.md`.
>
> **This is v1 feature-complete.** After this slice a Kept note is verified into
> the Obsidian vault, deleted from Jackdaw, and appears in Obsidian on both devices
> via Obsidian Sync (T2). No shipped destination remains after Obsidian.

Owner-settled (build-order, ADR 0001): retention is **hold-until-sync-confirmed**
(delete only after a verified write); **lazy vault setup at first export, NOT a
first-run gate** (owner-ratified 2026-07-14, design-lead's position over the
tech-lead's). The serializer + machine + coordinator + reconciler from Slice 6 are
**reused verbatim** — this slice adds almost no logic *above* the seam and no logic
*below* it; it is overwhelmingly the **setup / recovery / surfacing UX** around an
adapter that is already done.

---

## 0. What ships this slice

| Piece | File | Testable off-device? |
|---|---|---|
| **Destination swap** (`AppleNotesDestination` → `ObsidianFolderDestination(access:)`) behind the unchanged coordinator | `TriageRootView.swift` | ❌ device/sim (view wiring) |
| **Outbox classifier** (pure): outbox notes → `{ empty, needsSetup, stuck(count, dominantReason), draining }` → drives label + action | new `Talon/OutboxSummary.swift` | ✅ pure |
| **Lazy vault-setup** presenter: `.fileImporter([.folder])` fired from the export path when `noVaultConfigured`, persists via `VaultAccess.setVault`, then re-drives export | `TriageRootView.swift` (+ small host) | ❌ device/sim (picker + bookmark) |
| **Re-grant** presenter: same picker, fired for `accessLost` | `TriageRootView.swift` | ❌ device/sim |
| **Bottom-bar export affordance** (moved off the leading toolbar slot) | `TriageRootView.swift` | ❌ device/sim (UI) |
| **Stuck-notes surface** (capped, act-only: count + reason + Retry / Return-to-inbox; no bodies, self-empties) | new small view | ❌ device/sim (UI); the state feeding it is pure |
| **Return-to-inbox** action (`pending → inbox`, exits the export tail) | `TriageViewModel` (or a small action) | ✅ pure-ish (SwiftData glue, same as existing) |
| **Announcements** (failure/cancel + shared success) | `TriageRootView.swift` | ❌ device/sim (VoiceOver) |
| **Delete throwaway harness** `VaultProofView.swift` (Slice 1, marked throwaway) | remove file | n/a |
| `ObsidianFolderDestination` / `VaultAccess` / `FolderWriter` | (unchanged) | ✅ already CI-tested (Slice 6 follow-up) |

The genuinely new *logic* CI can verify is small: the **outbox classifier** and the
**return-to-inbox** transition. Everything load-bearing and new is **UX that only
the device exercises** (picker, bookmark across cold launch, Obsidian ingest,
VoiceOver). That inversion — near-zero new testable logic, high device-only surface
— is the defining shape of this slice, and it is why the owner is on the hook for
the on-device pass.

---

## 1. What is already done vs. what Slice 7 adds (read this before estimating)

**Done, reused verbatim, do NOT rewrite:**
- `ObsidianFolderDestination.export(_:)` — one `withVaultURL` claim for the batch,
  `writeBatch` fold per note, vault-level failure fails the whole batch with the
  right `ExportFailure`. **Already conforms to the seam; already unit-tested
  off-device** (`ObsidianFolderDestinationTests`).
- `VaultAccess` (resolve / stale-recreate / start-stop) + `VaultBookmarkStore`
  (UserDefaults) + `FolderWriter` (coordinated atomic write **+ read-back verify**).
- `NoteSerializer`, `RetentionMachine`, `ExportCoordinator`, `ExportReconciler`,
  `Note` retention fields — all destination-agnostic, all shipped in Slice 6.

**So the adapter is done.** Slice 7 is: **(a)** point the view at it, **(b)** give
the two vault-acquisition failures (`noVaultConfigured`, `accessLost`) a UI that
re-drives export, **(c)** surface the stuck set honestly, **(d)** move the
affordance to the bottom bar, **(e)** announce outcomes. Plus **the one real product
decision below.**

---

## 2. THE fork (OWNER DECISION — options + recommendation, not decided here)

Obsidian's write is **silent** — no share sheet, no user interaction, just a fast
local file write + read-back verify. That removes the constraint that forced Apple
Notes into a manual, batched, once-per-tap flow. So a Kept note *could* export the
instant it is kept. This reopens **when export fires**, and it is the one genuinely
load-bearing product/architecture choice in the slice.

**Option A — Manual batch flush (Slice 6's current model).**
Kept notes rest as `kept` in the outbox; the user taps "Export N" to drain the
batch. The vault picker fires on the **first export tap**.
- *For:* one deliberate "clear the inbox" action (the ADR 0001 / funnel "batch"
  ethos); the picker only ever appears on an explicit export tap, never mid-triage;
  errors surface once, batched.
- *Against:* it is a manual step the silent destination doesn't require; the outbox
  mixes "happily queued" and "failed" notes, so any per-note surface must
  distinguish them (drift risk toward a browsable kept-list — the product-lead's
  exact non-goal).

**Option B — Auto-export on Keep.**
Each Keep immediately fires a silent export attempt for that note; the outbox then
holds **only failures**.
- *For:* strictly funnel-purest — "a Kept note leaves immediately" (product-lead's
  argument); the outbox becomes *definitionally the stuck set*, so a per-note
  surface **cannot** drift into a kept-library (it self-limits to failures — this
  actively enforces the non-goal rather than fighting it); no manual flush step.
- *Against:* naive auto-export would fire the **vault picker on the very first
  Keep**, interrupting a triage swipe with a document picker — against the design
  line "never interrupt Capture/triage"; a persistently broken vault (stale
  bookmark) could nag on every Keep if attempts aren't deduped.

**Option C — Hybrid (RECOMMENDED).**
Auto-export on Keep **once a vault exists**, but:
1. **The first Keep with no vault does NOT auto-launch the picker.** The note lands
   as `pending(.noVaultConfigured)` and the **bottom bar** shows "Set up vault to
   export N" — the user taps that *deliberately*. After the bookmark exists, every
   subsequent Keep exports silently and immediately.
2. **A note that fails is not auto-retried** on later Keeps. It rests in `pending`
   with its reason; only a deliberate **Retry** / **Re-grant** re-attempts it. This
   stops a broken vault from hammering.
3. **The bottom bar persists only as the deliberate surface for the residue** —
   "Set up vault", "Re-grant", or "Retry N stuck" — appearing *only* when the outbox
   is non-empty. In the healthy steady state the bar is absent and Kept notes vanish
   silently: empty and honest, the design-lead's "loud only when actionable" line.

**Recommendation: Option C.** It takes Option B's funnel purity and its best
structural property — the outbox becomes the stuck set, which makes the surfacing UI
*inherently* honest (§5) — while keeping every picker/re-grant prompt
**user-initiated**, never a surprise mid-triage. It is also the smallest departure
from Slice 6: the coordinator, machine, and bottom-bar affordance all survive; Keep
merely gains a fire-and-forget `Task { exportAll }` after a vault exists, and the bar
label changes from "Export N" to a reason-driven action.

**Concurrency note the owner should know (favours C being safe):** auto-export
firing a `Task` per Keep is **already race-safe** with no new locking. The
coordinator marks notes `.writing` and **saves synchronously before** the `await
destination.export`, and `exportable` excludes `.writing`; both the coordinator and
the mutation are `@MainActor`, so a second Keep's export run cannot re-claim a note
already in flight. This is an existing Slice 6 property (`export_persistsWriting
BeforeAwaitingDestination`), not new work — it is *why* auto-export is cheap here.

**Timing/background:** every option runs export in the **foreground** during a triage
session; each write is a sub-millisecond local file op + read-back. **No background
execution, no `BGTaskScheduler`, no background modes** are needed for v1 — call this
out so it doesn't get over-built. (Cross-device propagation after the local write is
Obsidian Sync's job, not Jackdaw's — ADR 0001.)

Whatever the owner picks, the pieces below (§§3–8) are required; only §6's label
text and §5's "does the outbox contain happy-kept notes" depend on the answer.

---

## 3. Lazy vault setup at first export (owner-RATIFIED — spec the trigger + home)

The mechanism was proven in Slice 1; this slice makes it **user-facing and lazily
triggered**, never a first-run wall.

- **Trigger:** an export run whose outcome is `noVaultConfigured` for the batch
  (`ObsidianFolderDestination.export` already returns exactly this when the store
  has no bookmark). Under Option A this is the first "Export N" tap; under Option C
  it is the deliberate tap on the "Set up vault" bottom bar. **In no option does the
  picker fire from `keep()` directly** — it fires from an export attempt that came
  back needing a destination, or from the explicit setup affordance.
- **Home:** presentation lives in `TriageRootView` (or a thin host it owns), because
  the SwiftUI picker (`.fileImporter(isPresented:allowedContentTypes:[.folder])`)
  must hang off a view. The *logic* is: on `noVaultConfigured`, present `.fileImporter`
  → on `.success(url)` call `VaultAccess.setVault(pickedURL:)` (persists the
  security-scoped bookmark, iOS `options: []`, per Slice 1) → **re-drive
  `exportAll`**. The waiting `pending(.noVaultConfigured)` notes then drain
  `pending → writing → confirmed → deleted`.
- **Reuse, don't reinvent:** `VaultProofView` already demonstrates the exact
  `.fileImporter` + `setVault` mechanics; port that call sequence into the real flow,
  then **delete `VaultProofView`** (Slice 1 marked it throwaway "deleted/replaced at
  Slice 6"; do it here).
- **Kill-safety while awaiting the picker:** a note kept before setup sits as
  `pending(.noVaultConfigured)` — a persisted, recoverable resting state, never lost.
  No `writing` note can strand on the picker, because we don't enter `writing` until
  a vault resolves. Good.

`noVaultConfigured` already maps to the "no-destination-yet" reason in the Slice 4
contract and to a **"Set up vault"** affordance — no enum change.

---

## 4. Stale-bookmark re-grant (`accessLost` → re-pick)

Security-scoped bookmarks go stale (OS update, vault moved) — ADR 0001 marks
graceful recovery "required, not optional." The plumbing already classifies it:
`VaultAccess.resolve()` throws `ExportFailure.accessLost` when the bookmark won't
resolve or the OS refuses `startAccessingSecurityScopedResource()`, and
`ObsidianFolderDestination.export` maps that to `.failed(reason: .accessLost)` for
the whole batch.

- **Contract mapping:** `accessLost` → **"Re-grant"** affordance (Slice 4 contract,
  design memo `export-status-surfaces`). Presentation is the *same* `.fileImporter`
  as §3 — re-pick the folder, `setVault`, re-drive export. The only difference from
  setup is copy/framing: routine re-confirmation ("Reconnect your vault"), **not**
  user error, and never blocking capture.
- **No data loss:** the batch that hit `accessLost` is back in `pending(.accessLost)`
  — queued, visible, retryable. Nothing is deleted (delete is confirmed-only).
- **Auto-recreate first:** `VaultAccess` already silently recreates a *merely stale*
  (but still resolvable) bookmark inside `withVaultURL`; the user only sees "Re-grant"
  when resolution genuinely fails. So the loud path is rare by construction — good.

---

## 5. Pending/failed surfacing (count + per-note action) — funnel guardrails

The outbox already **stores** reasons (`Note.exportFailure`); Slice 7 **surfaces**
them and offers the right action. **Product-lead non-goal, honored as a hard
constraint: this is act-on-stuck-notes ONLY — never a browsable list of kept notes,
never per-note history, never re-readable bodies.**

- **The pure seam (CI-testable, the one valuable new unit):** `OutboxSummary`
  classifies the outbox into a small enum the UI renders:
  - `empty` → no affordance (funnel clear).
  - `needsSetup(count)` → "Set up vault to export N" (dominant reason
    `noVaultConfigured`).
  - `stuck(count, dominantReason)` → `accessLost` → "Re-grant"; `writeFailed` /
    `verifyMismatch` → "Retry N". Pick the dominant/most-actionable reason for the
    bar label; the per-note surface disambiguates.
  - `draining(count)` (Option A only) → "Export N" for the happily-queued `kept`
    set. **Under Option C this case does not exist** — the outbox is only ever the
    stuck set, which is precisely why C makes the surface inherently non-archival.
- **The per-note surface (capped, self-emptying):** on tapping the bar, a short list
  of the stuck notes only: truncated first line + reason + relative time + **Retry**
  and **Return to inbox**. **No full bodies, no edit-in-place, no search/sort, no
  confirmed/sent history.** It shows *only* `pending` notes and empties itself as they
  drain. This matches the design memo's capped-list fallback and the product-lead's
  act-only bound. (If the owner wants to be maximally strict, ship **counts-only**
  first and add the capped list later — the classifier supports both.)
- **Return to inbox:** a stuck note the owner gives up exporting goes back to Triage
  (`pending → inbox`, clearing `exportFailureRaw`). This **exits the export tail**, so
  it is a plain `Note.status` mutation in the view-model, **not** a `RetentionMachine`
  event (the machine's domain is `kept…deleted`; re-triage is outside it). Keep it a
  one-line action; do not extend the machine.
- **Loudness (design memo):** `pending(nil)`/offline-style waiting is calm (no loud
  badge); **loud only for `accessLost` / `writeFailed` / `verifyMismatch`** — an
  actionable state. Under Option C the bar's mere presence is the signal.

---

## 6. Export affordance placement (design-lead: bottom, not leading)

Currently the affordance is a `ToolbarItem(placement: .topBarLeading)` labelled
"Export N to Notes". Move it to the **bottom bar** — `.toolbar { ToolbarItem
(placement: .bottomBar) { … } }` or a `.safeAreaInset(edge: .bottom)` control,
coordinated with the existing discard-undo banner that already occupies the bottom
inset (don't let them collide — the undo banner is transient; the export bar is
steady-state, so gate visibility so only one shows at a time).

- Label is **reason-driven** from `OutboxSummary` (§5), not a fixed "Export N to
  Notes": "Set up vault to export N" / "Re-grant · N waiting" / "Retry N" / (Option A)
  "Export N". Shown only when the outbox is non-empty; absent when the funnel is
  clear.
- The leading slot is freed; the trailing/primary slot already holds "Capture"
  (`RootView`). The bottom bar is the natural home for a batch action over the list.

---

## 7. Announcements + shared confirmation (VoiceOver + visible)

Slice 6 announces only the **success** count. Slice 7 must also announce **failure /
cancel**, visibly and via VoiceOver (checklist item 5).

- **Success:** keep the existing `AccessibilityNotification.Announcement("Exported N
  notes.")` and add a brief visible confirmation (a transient toast/label sharing the
  bottom inset). Under Option C, silent auto-export of a single Kept note should
  **not** fire a per-note announcement each time (noise) — the visible confirmation
  is the Keep swipe itself leaving the row; reserve the spoken/visible "Exported N"
  for a deliberate batch drain (Retry / setup completion).
- **Failure:** announce + show. On a whole-batch vault failure: "Couldn't reach your
  vault — re-grant access" (`accessLost`) or "Vault not set up yet" (`noVault
  Configured`). On partial: "Exported N; M need attention." The message keys off
  `OutboxSummary`'s dominant reason so speech and the visible bar agree.
- **Obsidian has no cancel** (unlike the Apple Notes share sheet), so the Slice 6
  "cancel misreads as `writeFailed`" gotcha **does not apply here** — one less edge.

---

## 8. Hold-until-sync-confirmed on the real path (verify; no new code)

Item 6 of the entry checklist — "write-then-read-back verify, delete only on
confirmed" — is **already implemented and wired**: `FolderWriter.writeAndVerify`
writes atomically through `NSFileCoordinator` and **reads the bytes back**, throwing
`.verifyMismatch` on any difference; `ExportCoordinator` deletes a note **only** on
`.confirmed` (ADR 0001 cardinal rule, enforced by `RetentionMachine`). The Apple
Notes slice ran this against a *degraded* confirm (share-sheet completion ≠ saved);
**Obsidian is the first destination where "confirmed" is a real, byte-verified
signal.** So this slice does not *add* the guarantee — it is the slice where the
guarantee finally means what it says. The only work is confirming it end-to-end
**on-device** (§10).

---

## 9. Does `ObsidianFolderDestination` need changes?

**No required changes.** It already conforms to the seam, claims one `withVaultURL`,
folds `writeBatch` per note, and returns the correct per-note / whole-batch failures.
CI already covers `writeBatch` (all-success, one-bad-filename partial) and the
`noVaultConfigured` whole-batch path.

**One deferred, optional refinement (not blocking v1):** the file I/O currently runs
on `@MainActor` via the seam. For a batch drain or a single silent auto-export
(Option C), a local write + read-back is sub-millisecond, so this is fine for v1.
**Only if on-device profiling shows a hitch** during a large drain should the I/O be
offloaded off the main actor — which would reintroduce `Sendable` friction across the
seam and is not worth paying pre-emptively. Record as deferred; do not do it now.

---

## 10. Testable off-device (CI) vs. device-only (owner)

Be blunt about this, because the split is stark this slice.

**CI (`PR CI`, no Xcode) can verify:**
- `OutboxSummary` classification: empty / needsSetup / stuck(reason) / draining;
  dominant-reason selection when reasons are mixed; count correctness. (New, pure.)
- **Return-to-inbox** transition: `pending(reason) → inbox` clears the failure reason
  and re-enters Triage's `inbox||snoozed` query; does not touch other notes.
- Everything already green from Slice 6 that Slice 7 leans on: serializer, machine
  (incl. delete-only-on-confirmed), coordinator (partial failure keeps `pending` +
  reason; retries `pending`; ignores inbox/snoozed; persists `writing` before await),
  reconciler, and **`ObsidianFolderDestination.writeBatch` / `noVaultConfigured`**.
- (If Option C) a coordinator-level test that a second `exportAll` while one note is
  `.writing` does not re-claim it — the auto-export race-safety property, already
  expressible with the in-memory container + `MockDestination`.

**Device / simulator only (owner must sign off — CI cannot touch these):**
- The **document picker** actually presents from the export path and vends a
  **persistently writable** security-scoped bookmark into `On My iPhone/Obsidian/
  <vault>` (Slice 1 proved the mechanism once; this proves it from the *real* lazy
  trigger).
- The bookmark **survives a cold relaunch** (killed from the app switcher) and a
  later Keep exports with **no** setup prompt.
- A verified `.md` (frontmatter: time + GPS) **lands in Obsidian on both iPhone and
  Mac via Obsidian Sync**, no ignore/duplicate — the real "confirmed" end-to-end.
- **Re-grant** actually recovers: a genuinely stale/unresolvable bookmark surfaces
  "Re-grant", re-picking restores writes, queued notes drain. **Caveat — hardest
  thing to test anywhere:** you cannot easily *force* bookmark staleness on demand;
  the practical device check is "Clear vault" (or delete/rename the vault folder) →
  confirm the `accessLost` path lights up and re-pick heals it. Flag this as the
  weakest-tested path even after the owner's pass.
- **VoiceOver**: failure/cancel and success are actually announced and the bar/label
  is legible to the rotor.
- Bottom-bar affordance placement, and that it doesn't collide with the undo banner.

**Bottom line for a PR:** CI can prove the classifier and the transition and that the
reused pipeline still holds; it **cannot** prove a single byte reaches the vault, that
the bookmark persists, or that re-grant works. The v1 "done" bar is an **owner
on-device checklist**, not a green CI run.

---

## 11. Testing plan (extend `JackdawTests/ExportTests.swift`)

Add two suites; everything else is already covered.

- **`OutboxSummaryTests`** (pure): empty outbox → `.empty`; all `pending
  (.noVaultConfigured)` → `.needsSetup(count)`; mixed `accessLost` + `writeFailed`
  → `.stuck` with the **more-actionable dominant reason** and full count; (Option A)
  all `kept` → `.draining(count)`; a `kept` + `pending(.accessLost)` mix classifies
  per the chosen fork (under C, `kept` shouldn't appear — assert the invariant that
  the summary never reports a happy-kept note as stuck).
- **`ReturnToInboxTests`** (in-memory container): a `pending(.writeFailed)` note →
  return-to-inbox → `status == .inbox`, `exportFailure == nil`, appears in the
  `inbox||snoozed` set; sibling notes untouched; a non-`pending` note is a no-op
  (guard).
- **(Option C only) `AutoExportRaceTests`**: mark note A `.writing` mid-flight (via
  `MockDestination.onExport`), fire a second `exportAll`, assert A is **not**
  re-serialized/double-claimed and no note is deleted twice.

Reuse the existing `MockDestination`, in-memory `ModelContext`, and `keptNote`
helpers verbatim — no new test infrastructure. Do **not** attempt to unit-test the
picker, bookmark, or `VaultAccess.withVaultURL` (device-only by construction — Slice
1 established this and `FolderWriter`/`writeBatch` are the CI-reachable substitute).

---

## 12. Decisions — SETTLED vs OPEN

**SETTLED (do not relitigate):**
1. **Obsidian folder-write via security-scoped bookmark** is the v1 mechanism; T2
   topology (local vault + Obsidian Sync) ratified on-device (ADR 0001).
2. **Lazy vault setup at first export, not a first-run gate** (owner-ratified). The
   picker fires from an export attempt that needs a destination / the deliberate
   "Set up vault" affordance — never from `keep()` directly, never at launch.
3. **Hold-until-sync-confirmed with a *real* verify** (write + read-back) and
   delete-only-on-confirmed — already implemented; Slice 7 is where it becomes
   honest (vs Apple Notes' degraded confirm).
4. **Failure taxonomy is sufficient** — `noVaultConfigured`→Set up, `accessLost`→
   Re-grant, `writeFailed`/`verifyMismatch`→Retry. No enum change.
5. **Surfacing is act-on-stuck-only** (product-lead non-goal) — no browsable
   kept-list, no history, no re-readable bodies; capped and self-emptying.
6. **Affordance moves to the bottom bar** (design-lead).
7. **`ObsidianFolderDestination` needs no changes**; `VaultProofView` is deleted.
8. **No background execution for v1** — export runs in the foreground; sync
   propagation is Obsidian Sync's job.

**RESOLVED by the owner (2026-07-21):**
- **A. THE fork (§2) → Option C (Hybrid).** Auto-export on Keep once a vault exists;
  the first Keep with no vault rests as `pending(.noVaultConfigured)` and waits for a
  deliberate "Set up vault" tap (no picker mid-swipe); failed notes rest until a
  deliberate Retry/Re-grant. Implemented: `keep()` fires `autoExportKept`; launch
  drains lingering `kept`; the bottom bar is reason-driven.
- **B. Surfacing depth (§5) → counts-only first.** The bottom bar shows count + the
  right action (Set up / Re-grant / Retry); no per-note list yet. The `returnToInbox`
  transition + its test ship now (logic-ready) but the per-note stuck list is deferred
  until counts prove too blunt in real use.

## Related
- Mechanism + topology + on-device gates: `docs/adr/0001-obsidian-write-mechanism.md`
- Pipeline above the seam (reused verbatim): `docs/slices/slice-6-apple-notes-export.md`
- Vault bookmark mechanics (reference for the picker/re-grant): `docs/slices/slice-1-vault-bookmark.md`
- Build order + numbering: `docs/build-order.md` §"Slice 6 — Obsidian export"
- Surfacing / re-grant UX + funnel guardrails: `.claude/agent-memory/design-lead/{export-status-surfaces,funnel-nav-constraint}.md`
- Failure-reason contract: `docs/slices/slice-4-triage.md`
</content>
</invoke>
