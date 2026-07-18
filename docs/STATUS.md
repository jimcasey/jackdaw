# Jackdaw — Project Status & Session Handoff

> **Read this first when resuming Jackdaw in a new or remote Claude Code session.**
> The git repo is the single source of truth. Anything not committed and pushed
> does **not** follow you to another machine or a cloud session (see "What travels"
> below). Refresh this file with `/handoff` before switching sessions.

**Last updated:** 2026-07-18 (adopted PR-based dev workflow — see `docs/dev-workflow.md`).

---

## Where we are

Jackdaw is an iOS quick-capture inbox (Capture → Triage → Export to Obsidian).
Building in thin end-to-end slices per the de-risking rule. **Both the scariest
risks are already retired:** the iOS toolchain/TestFlight path (Slice 0) and the
Obsidian vault-write architecture (Slice 1, proven on a real device).

### Slice progress

| # | Slice | Status |
|---|-------|--------|
| 0 | Walking skeleton on TestFlight | ✅ done, on device |
| 1 | Vault bookmark write+verify (Talon `ExportDestination` seed) | ✅ done, **T2 proven on-device** |
| 2 | In-app capture + SwiftData | ✅ done (then reworked in Slice 3) |
| 3 | Capture rework → Triage-root + auto-presented Capture **sheet** | ✅ done |
| 4 | Real Triage inbox (Keep/Snooze/Discard, undo, editor) | ✅ done |
| 5 | Location context (in-app precise GPS, async backfill) | ✅ done |
| 6 | **Apple Notes export** (intermediate milestone) | ▶ **NEXT — not started** |
| 7 | Obsidian export → v1 complete | not started |

**Numbering caveat:** implementation slice numbers run **one ahead** of the
at-a-glance table in `docs/build-order.md` (the capture rework became its own
slice). Trust the table there for the canonical order; the `docs/slices/slice-N-*.md`
files are the detailed specs.

### What's built vs. not
- **Built:** capture (autosave-as-you-type, sheet), Triage inbox with the three
  actions + deferred-delete undo + calendar-day snooze + light editing, location
  attachment. 33 unit tests pass.
- **Not built yet — the export half:** the `Jackdaw/Talon/` core (`ExportDestination`,
  `VaultBookmarkStore`, `VaultAccess`, `FolderWriter`, `ObsidianFolderDestination`,
  `ExportFailure`) exists from Slice 1 but is currently **unused** (the `VaultProofView`
  harness that exercised it is parked/unreferenced). Slice 6/7 connect it via a note
  **serializer** (markdown + YAML frontmatter) and the retention **state machine**
  (`kept → pending → writing → confirmed → deleted`). `Note.status` already has `.kept`;
  the export states + an `exportFailure` field are added at the export slices.

### Immediate next step
Spec **Slice 6 — Apple Notes export** via the tech-lead (pattern: tech-lead writes
`docs/slices/slice-6-*.md`, then implement + verify). It proves the export pipeline
(serializer + retention state machine above the `ExportDestination` seam) against an
easy destination before Slice 7 wires the real Obsidian folder-write. Retention is
**hold-until-sync-confirmed**.

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
| CI / distribution | **Xcode Cloud** (Accepted) — 2 phased owner-configured workflows: PR CI (build + `JackdawTests` on PR-to-`main`) + TestFlight on merge-to-`main`; internal testers only; agent never triggers/reconfigures cloud builds. **Not wired yet** — owner sets up in App Store Connect. | ADR 0006 |

Full scope in `docs/prd/mvp-scope.md`. Governing principle: **funnel, not archive** —
notes flow Capture → Triage → Export and leave; "home is never a growing browsable
library." No browsing/search/history of exported notes.

---

## How to build & verify (learned the hard way)

- **Full Xcode is at `/Applications/Xcode.app`** (26.x). The default `xcode-select`
  points at CommandLineTools, so CLI builds need:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **Run the tests:**
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -scheme Jackdaw -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:JackdawTests -derivedDataPath <scratch>
  ```
- **Build only:** `xcodebuild build -scheme Jackdaw -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>`
- **STALE-BUILD GOTCHA:** multiple DerivedData dirs exist (Xcode's + CLI). A bare
  `find … Jackdaw.app | head -1` can grab an **old** build (symptom: the app shows
  the default "Hello, world!" template). Always build with an explicit
  `-derivedDataPath` and install THAT `.app` for a simulator launch/screenshot.
- **Sim launch/screenshot:** `xcrun simctl install/launch/io "iPhone 17" …`;
  bundle id **`com.jimcodes.Jackdaw`**. Grant location:
  `xcrun simctl privacy "iPhone 17" grant location com.jimcodes.Jackdaw`; set a
  coordinate: `xcrun simctl location "iPhone 17" set <lat>,<lon>`.
- **Can't be automated headlessly (owner must check on sim/device):** typing a note,
  swipe gestures, permission prompts, real precise GPS, TestFlight/signing. Unit
  tests cover the logic; the owner drives the UI.
- **iOS toolchain reality:** building, signing, TestFlight, and Instruments happen in
  **Xcode** — that context switch is unavoidable.

---

## The tripod (personas) & memory

Three subagents in `.claude/agents/` — `product-lead`, `design-lead`, `tech-lead` —
own why/what, experience, and how respectively. Invoke by name ("have the tech-lead
spec Slice 6"). Their memory lives in `.claude/agent-memory/` and **is committed**,
so a fresh session's personas reload their state. Prior *agent instances* don't
survive a session move, but they rebuild from that memory — just re-invoke them.

---

## What travels to a new/remote session — and what doesn't

**Travels (in git):** `CLAUDE.md`, everything in `docs/` (PRD, ADRs, design,
build-order, slices, this file), `.claude/agent-memory/`, `.claude/agents/`,
`.claude/commands/`, all code + tests.

**Does NOT travel (machine-local):**
- Claude Code's per-project auto-memory at `~/.claude/projects/-Users-jim-Code-jackdaw/memory/`
  (its `MEMORY.md` + fact files). This STATUS.md is the in-repo replacement for it.
- The conversation transcript (local `.jsonl`). A remote session starts fresh — this
  file is how it gets oriented.
- Local build scratch (DerivedData) — disposable.

**Before switching sessions:** run `/handoff` to refresh this file, then
**commit and push your branch and open/update its PR** — a remote/cloud session
only sees pushed commits, and as of 2026-07-18 changes land via PR, not direct
pushes to `main` (see `docs/dev-workflow.md`).
