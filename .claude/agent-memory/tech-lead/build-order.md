---
name: build-order
description: Jackdaw v1 walking-skeleton build order (owner-ratified) — the ordered slice sequence that retires platform risk before features, plus the reconciled owner decisions (lazy vault setup, two-tab nav, kept Apple-Notes slice) and the Talon seam contracts.
metadata:
  type: project
---

**Build order lives in `docs/build-order.md`** (tech-lead; owner-RATIFIED, reconciled with design-lead, then REVISED 2026-07-14 for the capture-UX/nav pivot — see [[capture-nav-and-external]]).

**FINAL v1 slice order (2026-07-14, after nav pivot + external-capture DEFERRAL):** 0 skeleton ✅ · 1 bookmark/T2 ✅ · **2** in-app Capture SHEET + Triage-ROOT + SwiftData (incl. `CaptureService` seam; nav flip per ADR 0004) ▶ · **3** real Triage (inbox actions + retention early states) · **4** Location (IN-APP precise GPS only) · **5** Apple Notes export · **6** Obsidian export (v1 complete). External-capture surfaces = FAST-FOLLOW v1.x (ADR 0005), NOT in v1. The interim "external validation slice at 4′" was REMOVED; location returned to its natural post-Triage spot (in-app only). See [[capture-nav-and-external]].

**ORIGINAL (pre-pivot) slice sequence, for reference:**

- **Prereq:** paid Apple Developer Program enrollment (~$99/yr). Free Apple ID has 7-day provisioning + NO TestFlight. Hard gate on Slice 0.
- **Slice 0 — Walking skeleton:** near-empty SwiftUI app (shows build number), full toolchain path signing→provisioning→archive→App Store Connect→TestFlight internal→install on owner's iPhone. Internal TestFlight = NO Beta App Review, 0 review delay; builds expire after 90 days. Does NOT retire full App Store review.
- **Slice 1 — Proof-point #1 (ADR 0001 gate 2a):** writable-bookmark write+verify on a REAL DEVICE. Pick vault folder (doc picker `.folder`) → persist `url.bookmarkData()` → COLD RELAUNCH → resolve (handle `bookmarkDataIsStale`) → `startAccessingSecurityScopedResource` → write .md via `NSFileCoordinator` → read-back verify → stop. FAIL → triggers T1 (iCloud) fallback per ADR. Highest architectural unknown; comes as early as toolchain allows. Bookmark = single Data blob, does NOT need the main persistence store.
- **Slice 2 — Thin capture:** text + timestamp, offline queue. Persistence store first load-bearing here.
- **Slice 3 — Location context:** precise-GPS entitlement. `NSLocationWhenInUseUsageDescription` (When-In-Use only, never Always/background). Precise/coarse: check `accuracyAuthorization`; if `.reducedAccuracy`, `requestTemporaryFullAccuracyAuthorization` + `NSLocationTemporaryUsageDescriptionDictionary` key. Denied → capture STILL succeeds (timestamp only). Capture is the sacred path; location is enrichment.
- **Slice 4 — Triage:** batch inbox Discard/Snooze/Keep + edit text/context. Builds the retention state machine incl. the **kept-but-no-destination** pending sub-state (see lazy-setup below).
- **Slice 5 — Apple Notes export (intermediate milestone, NOT shipped):** serializer (md+YAML frontmatter) + retention state-machine tail (kept→pending→writing→confirmed→deleted) ABOVE the `ExportDestination` seam (reused verbatim); AppleNotesDestination via Share Sheet (degraded confirm — treats share-completion as confirm; scaffolding only). Proves seam has 2 real adapters.
- **Slice 6 — Obsidian export (real v1):** swap in ObsidianDestination, reuse Slice-5 serializer/state-machine + Slice-1 write. Full hold-until-confirmed. **Vault setup is LAZY (fires at first Keep, not first-run)**. v1 feature-complete.

**Why this order (de-risking rule):** toolchain first, then the single highest platform unknown (bookmark), then features down Capture→Triage→Export.

**Owner arbitration 2026-07-14 (reconciled into the doc):**
- **Vault setup = LAZY at first Keep, NOT a first-run gate.** Design-lead's position won over tech-lead's first-run-gate preference. Consequence absorbed: the **kept-but-no-destination** state is REAL — a valid `pending` reason ("no-destination-yet / awaiting setup"), NOT an error. First Keep with no vault triggers the picker; waiting notes then drain. Accepted tradeoff: one extra state for a friction-free first run. Do NOT relitigate.
- **Slice 5 (Apple Notes) KEPT** — tech-lead lean confirmed. Still the most cuttable slice if timeline compresses.
- **Navigation = two-tab tab bar `Capture | Triage`.** Slice 0 stubs the shell; capture under Capture tab, triage/export under Triage tab.

**Talon / `ExportDestination` seam CONTRACTS (design-lead surfaced; hard requirements on the layer above the seam — fold into any export/retention work):**
1. Per-note state must expose a **failure reason** distinguishing at least: offline / access-lost (stale bookmark) / write-error / no-destination-yet. UI keys off it: Retry (offline, write-error) vs Re-grant (access-lost) vs Set-up-vault (no-destination-yet). A single opaque "failed" is INSUFFICIENT.
2. **Capture persists the note BEFORE the GPS fix**, then backfills location ASYNC. Never block capture on location (lock can take seconds / never come). A note may legitimately have pending/absent location; correct it at triage.
3. Retention layer must expose per-note state + reason, an aggregate **count** of not-yet-exported notes, and a **retry / return-to-inbox** affordance per note.

**Still-open owner calls (NOT resolved — do not assume):**
- **Discard-undo banner** (Slice 4): design-lead wants it (mis-tap safety net), tech-lead resisted (friction vs fast keep-kill). DEFERRED — settle when Discard is built at Slice 4.
- **App Store vs TestFlight-forever** (Slice 0): tech-lead recommends deferring App Store submission indefinitely (single-user; TestFlight builds expire every 90 days → periodic re-upload).

**How to apply:** Don't reorder Slices 0→1 (platform-risk-first). Don't build export before the Slice-4 state machine. Design-lead dependency map: nav shell→Slice 0; location flow→Slice 3; snooze session def→Slice 4; lazy vault setup + re-grant recovery + pending/failed surfacing→Slice 6 (state/API for surfacing built at Slice 4). See [[decision-obsidian-write]] for the write mechanism, [[ios-gotchas]] for bookmark/entitlement facts, [[stack-recommendations]] for ADR 0002/0003.
