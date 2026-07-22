# Jackdaw — Project Status & Session Handoff

> **Read this first when resuming Jackdaw in a new or remote Claude Code session.**
> The git repo is the single source of truth. Anything not committed and pushed
> does **not** follow you to another machine or a cloud session (see "What travels"
> below). Refresh this file with `/handoff` before switching sessions.

**Last updated:** 2026-07-22 — **🎉 v1 is FEATURE-COMPLETE and validated on-device.**

---

## Where we are

Jackdaw is an iOS quick-capture inbox: **Capture → Triage → Export to Obsidian**.
Built in thin end-to-end slices per the de-risking rule.

**v1 is feature-complete and validated on the owner's iPhone.** The full funnel
works end to end on-device: a kept note is written into the Obsidian vault,
**byte-verified**, deleted from Jackdaw, and syncs to Obsidian. Both bottom
confirmations were confirmed on-device — **"Saved to Obsidian"** on keep and the
**"Note discarded — Undo"** banner on discard. All feature slices (0–7) are merged
to `main` through the PR + tripod-review flow, on a live **Xcode Cloud CI/CD**
pipeline (`PR CI` on PRs, automated TestFlight on merge). What remains is optional
**v1.x** polish (below), not v1 work.

### Slice progress

| # | Slice | Status |
|---|-------|--------|
| 0 | Walking skeleton on TestFlight | ✅ done, on device |
| 1 | Vault bookmark write+verify (Talon `ExportDestination` seed) | ✅ done, **T2 proven on-device** |
| 2 | In-app capture + SwiftData | ✅ done (then reworked in Slice 3) |
| 3 | Capture rework → Triage-root + auto-presented Capture **sheet** | ✅ done |
| 4 | Real Triage inbox (Keep/Snooze/Discard, undo, editor) | ✅ done |
| 5 | Location context (in-app precise GPS, async backfill) | ✅ done |
| 6 | **Apple Notes export** (intermediate milestone) | ✅ merged (#9 + follow-up #11) |
| 7 | **Obsidian export → v1 complete** | ✅ **done, validated on-device** (#12; toast fix #13–#14) |

**Numbering caveat:** implementation slice numbers run **one ahead** of the
at-a-glance table in `docs/build-order.md` (the capture rework became its own
slice). Trust the table there for the canonical order; the `docs/slices/slice-N-*.md`
files are the detailed specs.

### What's built vs. not
- **Built:** capture (autosave-as-you-type, sheet), Triage inbox with the three
  actions + deferred-delete undo + calendar-day snooze + light editing, location
  attachment.
- **Slice 6 — Apple Notes export — MERGED (#9), PR CI green.** The export half above
  the seam is live: `NoteSerializer` (markdown + YAML frontmatter; reused by Obsidian),
  `RetentionMachine` (pure `kept → pending → writing → confirmed → deleted`; delete
  only on confirm) + `ExportCoordinator`, `AppleNotesDestination` (share-sheet;
  **degraded** confirm), the `ExportDestination` seam evolved to **batch / async /
  per-note outcome**, `Note` gained `pending/writing/confirmed` + `exportFailureRaw`,
  and Triage gained the outbox count + "Export N to Notes". Off-device suite in
  `JackdawTests/ExportTests.swift`. **A tech-lead-review follow-up PR adds:** launch
  `writing → pending` reconciliation (`ExportReconciler`), off-device tests for
  `ObsidianFolderDestination.writeBatch` (Slice 7's real path), and do/`catch` on the
  kill-safety save.
- **Slice 7 — Obsidian export — MERGED (#12), validated on-device.** Triage points at
  `ObsidianFolderDestination` (reuses `VaultAccess`/`FolderWriter`/`VaultBookmarkStore`
  from Slice 1); **Hybrid** trigger (auto-export on Keep once a vault exists) +
  **counts-only** surfacing via `OutboxSummary`; lazy vault setup + stale-bookmark
  re-grant via one `.fileImporter`; `returnToInbox` escape; `ExportReconciler` runs at
  launch **and** on foreground. A **"Saved to Obsidian"** confirmation (overlay toast +
  VoiceOver announcement, #13–#14) is the at-a-glance "it reached the vault" signal.
  `VaultProofView` deleted; `AppleNotesDestination` retained (unused) as the seam's
  documented second adapter.

### Immediate next step — v1 is done
No remaining v1 work. Optional **v1.x** items (all deferred, none blocking), rough
priority:
- **Real app icon + marketable name** — replace the placeholder icon and the
  "JackdawNotes" store name (branding: product-lead + design-lead). See "Open/deferred".
- **Reduce-Motion gating** for the toast / undo-banner transitions — design-lead polish
  (neither is gated on `accessibilityReduceMotion`; flagged in the #13 review).
- **Per-note stuck list** — only if the counts-only outbox proves too blunt in real
  use; `returnToInbox` logic already ships, just needs the list UI.
- **External capture surfaces** (Action button / Shortcuts / widget) via a
  `CaptureNoteIntent` over the existing `CaptureService` seam — deferred per ADR 0005.

### Recently landed
**PRs #1–#15 are all merged to `main`.** The v1 funnel shipped across the feature
slices — Apple Notes export (#9, follow-up #11) → Obsidian export (#12), with the
"Saved to Obsidian" confirmation + its render fix (#13–#14). The dev workflow itself
was hardened: **auto-open PRs** and a **durable 5-minute CI check-back** (#10, #15;
session-only crons were silently dying on the remote runner — see `docs/dev-workflow.md`).
The Obsidian export path and both confirmations are **confirmed working on-device.**

---

## Key decisions (and where they're recorded)

| Decision | Value | Source |
|----------|-------|--------|
| Obsidian write mechanism | **T2** — folder-write into local vault; Obsidian Sync propagates. Proven on-device. Git = fallback. | ADR 0001 |
| Min iOS target | **iOS 26** | ADR 0002 |
| Persistence | **SwiftData** (additive lightweight migration; no migration plan pre-release) | ADR 0003 |
| Navigation | **Triage-root + auto-presented Capture sheet** (reversed the earlier two-tab shell) | ADR 0004 |
| External capture | **Deferred to v1.x.** Clean `CaptureService` seam built; no external surface in v1. A no-launch App Intent **cannot get precise GPS** (platform rule). | ADR 0005, `docs/feasibility/external-capture-precise-gps.md` |
| Capture model | **Autosave-as-you-type** (lazy create, prune-on-abandon; overrode explicit-save) | `docs/slices/slice-2-*.md`, design capture flow |
| Retention | **Hold-until-sync-confirmed** (delete only after verified write) | PRD, ADR 0001 |
| Snooze | Calendar-day boundary = session boundary; reappears next local day | `docs/slices/slice-4-triage.md`, `SnoozeSchedule.swift` |
| Discard | Deferred hard-delete + undo banner (kill-safe toward keep) | `docs/slices/slice-4-triage.md` |
| Location | Precise GPS, in-app only; priming sheet kept, reduced-accuracy nudge cut, place names lazy-at-display | `docs/slices/slice-5-location.md` |
| **Dev workflow** | **PRs, not direct pushes to `main`.** Branch → `/open-pr` → `/checkpoint-review` (reuse the tripod + built-in `/code-review`, no separate reviewer agent) → merge. ADRs land as their own PR first; specs/persona-memory ride with the code. | `docs/dev-workflow.md` |
| **CI / distribution** | **Xcode Cloud — LIVE.** `PR CI` (build + `JackdawTests` on PR-to-`main`) is a **required status check**; `TestFlight` (archive + distribute to Internal Testing on merge-to-`main`, docs-only merges skipped) is validated on-device. Internal testers only. Agent never triggers/reconfigures cloud builds. | ADR 0006, `docs/ci/xcode-cloud-setup.md` |

Full scope in `docs/prd/mvp-scope.md`. Governing principle: **funnel, not archive** —
notes flow Capture → Triage → Export and leave; "home is never a growing browsable
library." No browsing/search/history of exported notes.

**Open/deferred (do not treat as settled):**
- **Marketable name is still TBD.** "Jackdaw" is taken on the App Store, so the
  store display name is a placeholder **"JackdawNotes"**; the codename `Jackdaw` and
  bundle ID `com.jimcodes.Jackdaw` are unaffected. Revisit near release — a
  product-lead call. See `.claude/agent-memory/product-lead/project_marketable-name.md`.
- **App icon is a placeholder** (charcoal + pale circle, added to fix a TestFlight
  ITMS icon-missing rejection). Needs a real design — a design-lead/branding task,
  alongside the name. File: `Jackdaw/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- **Discard-undo banner** was shipped (Slice 4); the older "open call" in
  `docs/build-order.md` is settled.

### Field notes — on-device issues (watch for recurrence)
- **2026-07-21 → largely RESOLVED 2026-07-22 — Obsidian export "not landing" on the
  first on-device pass.** During the first Slice 7
  on-device pass, kept notes did **not** appear in Obsidian **nor in the Files app**
  (so nothing was written — *not* an Obsidian external-refresh/display issue, which
  was explicitly ruled out), and Jackdaw showed **no export bar**. The notes were
  still *in Jackdaw* (hold-until-confirmed protected them). It **healed** after the
  owner renamed the destination folder, kept a new note, saw a **"Retry"** bar, and
  tapped it — a deliberate `exportAll` that drained *all* the stuck notes into the
  (renamed) folder; auto-export on subsequent keeps then worked.
  - **What that fingerprint means:** a note invisible with no bar is stuck either
    `.kept` (→ `OutboxSummary.draining` → silent by design) or `.writing` (excluded
    from *every* `@Query`). So **auto-export-on-keep did not write and did not advance
    the note to a `pending` failure** (which would have shown a bar). Leading
    hypotheses: a stale/never-configured vault bookmark that auto-export hit without
    surfacing; or notes stranded `.writing` and never reconciled until a full relaunch.
  - **Mitigations shipped in the follow-up PR:** (1) a **"Saved to Obsidian"**
    confirmation toast on a verified write — so a silent non-export is now immediately
    visible (*no toast = nothing landed*); (2) the interrupted-write reconciler now
    also runs **on foreground** (was cold-launch only), so a stranded `.writing` note
    resurfaces as a Retry bar without needing a relaunch.
  - **Resolution (2026-07-22):** on a later on-device pass, export **works** — notes
    write to the vault and sync to Obsidian. Two things had made it *look* broken:
    (a) the **"Saved to Obsidian" toast wasn't rendering** (a separate UI bug — the
    transient shared the bottom inset and didn't surface; fixed in #14 by moving it to
    an overlay, **confirmed on-device**), so there was no positive signal that anything
    happened; and (b) the original stuck notes traced to a **vault-folder setup
    mismatch**, cleared by the rename + Retry. The exact first-pass trigger was never
    reproduced, so keep the fingerprint below — but the failure mode is now **guarded**:
    a confirmed write shows the toast (*no toast = nothing landed*), and the reconciler
    runs on foreground as well as launch.
  - **If it recurs:** capture the export bar text (if any), whether the `.md` is in
    the Files app at the picked folder, and the vault-setup state; consider adding a
    temporary on-screen diagnostic (resolved vault path + last export outcome/error).

---

## How to build & verify (learned the hard way)

### Local (the inner loop — unchanged)
- **Full Xcode is at `/Applications/Xcode.app`** (26.x). The default `xcode-select`
  points at CommandLineTools, so CLI builds need:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **Run the tests:**
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -scheme Jackdaw -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:JackdawTests -derivedDataPath /tmp/jackdaw-derived
  ```
  (Use a real `-derivedDataPath` — a literal `<placeholder>` trips zsh's redirect
  parsing. `Jackdaw` is now a **shared** scheme whose Test action is scoped to
  `JackdawTests` only.)
- **Build only:** `xcodebuild build -scheme Jackdaw -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>`
- **STALE-BUILD GOTCHA:** multiple DerivedData dirs exist (Xcode's + CLI). Always
  build with an explicit `-derivedDataPath` and install THAT `.app`.
- **Sim launch/screenshot:** `xcrun simctl install/launch/io "iPhone 17" …`;
  bundle id **`com.jimcodes.Jackdaw`**. Grant location:
  `xcrun simctl privacy "iPhone 17" grant location com.jimcodes.Jackdaw`; set a
  coordinate: `xcrun simctl location "iPhone 17" set <lat>,<lon>`.
- **Can't be automated headlessly (owner must check on sim/device):** typing a note,
  swipe gestures, permission prompts, real precise GPS, TestFlight/signing.

### CI/CD (Xcode Cloud — LIVE; owner-configured in App Store Connect)
- **`PR CI`** — on Pull Request → `main`: builds `Jackdaw` + runs `JackdawTests`
  (~3 min). It is a **required status check**, so no PR merges red. Runs on all PRs
  (docs included — deliberately; skipping conflicts with the required-check).
- **`TestFlight`** — on merge → `main`: archives (Release) + distributes to
  **TestFlight Internal Testing** (owner's device). ~15–20 min. Skips docs-only
  merges (`docs/`, `.claude/`, `CLAUDE.md` excluded).
- **Repo pieces that make CI/CD work:** shared `Jackdaw.xcscheme` (Test = `JackdawTests`
  only), `ci_scripts/ci_post_clone.sh` (unique build number), app-target
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, and the app icon. No other
  `ci_scripts` — the project has no external deps.
- **Guardrails:** cloud compute is a finite owner-managed quota (25 h/mo free; real
  use ≈ a few hours). **The agent never triggers or reconfigures Xcode Cloud
  workflows** — builds are a consequence of git events the owner configured. Full
  setup runbook + gotchas: `docs/ci/xcode-cloud-setup.md`.
- **Version note:** `MARKETING_VERSION` is **1.0.1** (bumped past Slice 0's manual
  `1.0 (2)`); `ci_post_clone.sh` stamps the build number.

---

## Development workflow (how changes land)

- **PRs, not direct pushes to `main`.** `main` is branch-protected and stays green.
- **Flow:** branch → commit → `/open-pr` → `PR CI` + `/checkpoint-review` → merge.
- **Commands:** `/open-pr` (scaffold a PR from the branch), `/checkpoint-review`
  (route the diff to the relevant tripod personas + built-in `/code-review`),
  `/handoff`, `/adr`, `/prd`.
- **Recording decisions:** a real architectural decision gets its **own ADR PR
  first**; persona-memory + slice specs ride **in the same PR** as the code.
- Full process: `docs/dev-workflow.md`.

---

## The tripod (personas) & memory

Three subagents in `.claude/agents/` — `product-lead`, `design-lead`, `tech-lead` —
own why/what, experience, and how respectively. Invoke by name ("have the tech-lead
spec Slice 6"). They also staff PR reviews, each on its dimension. Their memory lives
in `.claude/agent-memory/` and **is committed**, so a fresh session's personas reload
their state — just re-invoke them.

---

## What travels to a new/remote session — and what doesn't

**Travels (in git):** `CLAUDE.md`, everything in `docs/` (PRD, ADRs, design,
build-order, slices, dev-workflow, ci runbook, this file), `.claude/agent-memory/`,
`.claude/agents/`, `.claude/commands/`, all code + tests, the shared `.xcscheme`,
and `ci_scripts/`.

**Does NOT travel (machine-local):**
- Claude Code's per-project auto-memory. This STATUS.md is the in-repo replacement.
- The conversation transcript. A remote session starts fresh — this file orients it.
- Local build scratch (DerivedData) — disposable.
- **Xcode Cloud workflow config** lives in **App Store Connect**, not the repo — it's
  owner-managed and already set up (both workflows). See the runbook.

**Before switching sessions:** run `/handoff` to refresh this file, then **commit and
push your branch and open/update its PR** — a remote/cloud session only sees pushed
commits, and changes land via PR, not direct pushes to `main` (see
`docs/dev-workflow.md`). The build environment on the far side needs **Xcode 26.x +
the iOS 26 SDK** to build/verify.
