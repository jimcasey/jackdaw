# Jackdaw — Project Status & Session Handoff

> **Read this first when resuming Jackdaw in a new or remote Claude Code session.**
> The git repo is the single source of truth. Anything not committed and pushed
> does **not** follow you to another machine or a cloud session (see "What travels"
> below). Refresh this file with `/handoff` before switching sessions.

**Last updated:** 2026-07-21 (dev workflow is now PR-based + Xcode Cloud CI/CD is live — see `docs/dev-workflow.md`, ADR 0006).

---

## Where we are

Jackdaw is an iOS quick-capture inbox (Capture → Triage → Export to Obsidian).
Building in thin end-to-end slices per the de-risking rule. **Both the scariest
risks are already retired:** the iOS toolchain/TestFlight path (Slice 0) and the
Obsidian vault-write architecture (Slice 1, proven on a real device).

**New since the last handoff — how we work changed (no product code changed):**
the project now lands changes via **pull request, not direct pushes to `main`**,
with **tripod checkpoint reviews**, and a **live Xcode Cloud CI/CD pipeline**
(PR CI on PRs + automated TestFlight on merge). Details below and in
`docs/dev-workflow.md`. The next *product* slice (Slice 6) has not started.

### Slice progress

| # | Slice | Status |
|---|-------|--------|
| 0 | Walking skeleton on TestFlight | ✅ done, on device |
| 1 | Vault bookmark write+verify (Talon `ExportDestination` seed) | ✅ done, **T2 proven on-device** |
| 2 | In-app capture + SwiftData | ✅ done (then reworked in Slice 3) |
| 3 | Capture rework → Triage-root + auto-presented Capture **sheet** | ✅ done |
| 4 | Real Triage inbox (Keep/Snooze/Discard, undo, editor) | ✅ done |
| 5 | Location context (in-app precise GPS, async backfill) | ✅ done |
| 6 | **Apple Notes export** (intermediate milestone) | ▶ **implemented on branch `claude/slice-5-ftbwen`, pending build/verify** |
| 7 | Obsidian export → v1 complete | not started |

**Numbering caveat:** implementation slice numbers run **one ahead** of the
at-a-glance table in `docs/build-order.md` (the capture rework became its own
slice). Trust the table there for the canonical order; the `docs/slices/slice-N-*.md`
files are the detailed specs.

### What's built vs. not
- **Built:** capture (autosave-as-you-type, sheet), Triage inbox with the three
  actions + deferred-delete undo + calendar-day snooze + light editing, location
  attachment. **33 unit tests** as of last merge to `main`.
- **New on `claude/slice-5-ftbwen` (Slice 6 — Apple Notes export, unbuilt here):**
  the export half above the seam is now written —
  - `Talon/NoteSerializer.swift` (markdown + YAML frontmatter; reused by Obsidian),
  - `Talon/RetentionMachine.swift` (pure `kept → pending → writing → confirmed →
    deleted`; delete only on confirm),
  - `Talon/ExportCoordinator.swift` (drives notes through the machine against an
    `ExportDestination`),
  - `Talon/AppleNotesDestination.swift` (share-sheet adapter; **degraded** confirm),
  - the `ExportDestination` seam evolved to **batch / async / per-note outcome**
    (`SerializedNote`, `ExportOutcome`; `ExportFailure` now `String`-backed),
  - `Note` gained `pending/writing/confirmed` statuses + `exportFailureRaw`,
  - `TriageRootView` gained the outbox count + "Export N to Notes" batch action,
  - `JackdawTests/ExportTests.swift` (serializer / machine / coordinator).
  **Not yet compiled or run** (sandbox has no Xcode) — `PR CI` / the local recipe is
  the gate.
- **Reused from Slice 1 (unchanged logic):** `VaultAccess`, `FolderWriter`,
  `VaultBookmarkStore` — `ObsidianFolderDestination` was updated to the new seam
  (still wraps `FolderWriter` write+verify) and is Slice 7's real destination; the
  `VaultProofView` harness stays parked/throwaway.

### Immediate next step
**Slice 6 — Apple Notes export is implemented** on branch `claude/slice-5-ftbwen`
(spec: `docs/slices/slice-6-apple-notes-export.md`) but was authored in a **sandbox
with no Xcode**, so it is **not yet compiled or tested here.** Next:
1. **Build + run `JackdawTests`** with the recipe below (or let `PR CI` do it) — the
   new off-device suite is `JackdawTests/ExportTests.swift` (serializer, retention
   machine, coordinator). Expect the total to rise from 33.
2. **On-device/sim verify** the two device-only pieces: the batch "Export N to Notes"
   share sheet from Triage, and a frontmatter'd note landing in Apple Notes (§7 of
   the spec).
3. Open the PR for `claude/slice-5-ftbwen` → `PR CI` + `/checkpoint-review` → merge →
   automatic TestFlight. **This is the first *feature* slice through the new flow.**

Then **Slice 7 — Obsidian export**: swap `AppleNotesDestination` → an
`ObsidianDestination` behind the *same* `ExportCoordinator`; reuse the serializer +
retention machine **verbatim** and the Slice-1 `VaultAccess`/`FolderWriter`
write+verify; add lazy vault setup, stale-bookmark re-grant, and the pending/failed
surfacing UI (this slice only *stores* the reason).

### Recently landed
**PRs #1–#7 are all merged to `main`** — the PR-based workflow, the tripod-review
setup, and the full **Xcode Cloud CI/CD pipeline** are in place and **validated
on-device** (a real TestFlight build shipped after clearing a missing-icon rejection).
The owner has applied the TestFlight **docs-only skip** (`docs/`, `.claude/`,
`CLAUDE.md` excluded from the `TestFlight` start condition). No product code is in
flight; the next work is Slice 6.

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
