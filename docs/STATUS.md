# Jackdaw — Project Status & Session Handoff

> **Read this first when resuming Jackdaw in a new or remote Claude Code session.**
> The git repo is the single source of truth. Anything not committed and pushed
> does **not** follow you to another machine or a cloud session (see "What travels"
> below). Refresh this file with `/handoff` before switching sessions.

**Last updated:** 2026-07-23 — **v1 is COMPLETE; the v1.x "capture wave" is
PLANNED & RATIFIED.** The wave's plan (`docs/prd/capture-wave.md`) merged via
PR #28 after a full tripod checkpoint review; ADRs 0007 + 0008 are drafted (in
the current ADR PR); per-slice work is filed as issues #29–#35.

---

## Where we are

Jackdaw is an iOS quick-capture inbox: **Capture → Triage → Export to Obsidian**.
**v1 is feature-complete and validated on the owner's iPhone** — the full funnel
works end to end on-device (write byte-verified into the vault, note deleted,
both bottom confirmations shown), on a live **Xcode Cloud CI/CD** pipeline
(`PR CI` on PRs, TestFlight on merge). Slices 0–7 all merged.

### The v1.x capture wave (current work)

Three owner asks: **note types** ("visited this restaurant" / "thought about
this podcast"), **external capture surfaces** (Action button, Shortcuts,
widget, Control Center), **richer context** (song/podcast/location) tied to
types. The full plan — governing ruling, guardrails, feasibility verdicts,
surface model, slice order, all owner rulings — is
**`docs/prd/capture-wave.md`** (ratified 2026-07-23, PR #28). Load-bearing
facts a fresh session must know:

- **Types are capture-context bundles, never taxonomy** (5 guardrails, ADR
  0007). Two hardcoded types — `place`, `listening` — plus untyped default.
  No type management UI; extensibility ladder recorded for later.
- **The wave's feasibility verdict:** Apple Music now-playing is readable
  **in-app foreground only**; Apple Podcasts and system-wide playback are
  **dead to third-party apps**. Owner uses Apple Podcasts + no Spotify →
  podcast metadata arrives **only via the share route** (Shortcut as
  share-sheet target piping the episode URL into intent parameters).
  **External context = caller-supplied parameters, never background reads.**
- **Two surface lanes** (ADR 0008): parameter surfaces (Action button /
  Shortcuts / Siri — no-launch speed lane, untyped stays fastest) vs.
  launcher surfaces (widget / Control Center — deep-link into the foreground
  Capture sheet; Place-typed capture lives here). No App Group this wave
  (recorded deferral).
- **ADR 0004 flip ships in slice A:** auto-present off → bare Triage root;
  ~2-week revert-without-debate hatch clocked from Action-button-configured.
- `type:` frontmatter is **omitted for untyped** notes; golden tests assert
  key absence. Location cache (slice F) stamps **untyped** external captures
  only, marked approximate.

### Capture-wave slice progress

| # | Slice | Issue | Status |
|---|-------|-------|--------|
| S1 | Now-playing spike (foreground + no-launch read) — feeds media ADR | #29 | committed; **needs owner on device** |
| A | External skeleton: `CaptureNoteIntent` + Action button + ADR 0004 flip | #30 | committed; gated on ADR 0008 merge |
| B | NoteType end-to-end (Listening shortcut only; location backfill) | #31 | committed; gated on ADR 0007 merge |
| C | In-app now-playing (Apple Music) | #32 | ratified order, not committed; needs S1 + media ADR |
| D | Piped context via Shortcuts (Get Current Song + podcast share route) | #33 | ratified order, not committed |
| E | Launcher surfaces (widgets + Control Center) | #34 | **decide when B lands** (`needs-decision`) |
| F | Last-known-location cache (untyped external only) | #35 | floats; ships per §7.4 policy |

**v1 slice history (all ✅ done, on device):** 0 walking skeleton · 1 vault
bookmark write+verify · 2 capture + SwiftData · 3 capture rework (Triage-root
+ sheet) · 4 real Triage · 5 location · 6 Apple Notes export (milestone) ·
7 Obsidian export. Details: `docs/build-order.md` (numbering caveat noted
there), `docs/slices/slice-N-*.md`.

### Immediate next step

1. **Merge the open ADR PR** (ADR 0007 + ADR 0008 + amended-by stamps on
   ADRs 0004/0005 + this STATUS refresh).
2. **Run the S1 spike (#29)** — needs the owner, a device, and Xcode; its
   answer feeds the third ADR (media context), which should be written before
   slice C.
3. **Build slice A (#30)**, then **B (#31)** — the committed tranche.

**Open issues:** #17 icon, #18 name, #19 reduce-motion (now also covers the
wave's new transitions), #20 per-note outbox list, #22 snooze nudge,
#23 snooze midnight, #24 App Store decision, #25 export bug-watch,
**#29–#35 capture wave**. #21 closed as superseded by the plan.
Labels in use: `bug`, `enhancement`, `v1.x`, `needs-decision`, `a11y`,
`branding`.

---

## Key decisions (and where they're recorded)

| Decision | Value | Source |
|----------|-------|--------|
| Obsidian write mechanism | **T2** folder-write into local vault; proven on-device | ADR 0001 |
| Min iOS target | **iOS 26** | ADR 0002 |
| Persistence | **SwiftData** (additive lightweight migration) | ADR 0003 |
| Navigation | Triage-root + auto-presented Capture sheet; **auto-present turns OFF in capture-wave slice A** | ADR 0004 (amended by ADR 0008) |
| External capture | `CaptureService` seam (v1); **surfaces now scheduled**; no-launch = no live location stands | ADR 0005 (amended by ADR 0008), `docs/feasibility/external-capture-precise-gps.md` |
| CI / distribution | **Xcode Cloud LIVE** — `PR CI` required check; TestFlight on merge; agent never triggers cloud builds | ADR 0006, `docs/ci/xcode-cloud-setup.md` |
| **Note types** | Capture-context bundles + 5 guardrails; `place`/`listening` hardcoded + untyped; frontmatter contract v2 (`type:` omitted for untyped); extensibility ladder | **ADR 0007**, `docs/prd/capture-wave.md` §1–2 |
| **External-surface architecture** | Parameter vs launcher lanes; context-via-parameters; share route (3 guardrails, Listening-job-scoped); App Group deferred; location cache untyped-only; no foregrounding intent | **ADR 0008**, plan §4/§7 |
| **Media context** | Apple Music = sole live source (foreground); Apple Podcasts/system-wide dead; Spotify + MediaRemote rejected | plan §3/§7.5 → **third ADR pending S1** |
| Capture model | Autosave-as-you-type (lazy create, prune-on-abandon) | `docs/slices/slice-2-*.md` |
| Retention | Hold-until-sync-confirmed | PRD, ADR 0001 |
| Snooze / Discard | Calendar-day boundary / deferred hard-delete + undo | `docs/slices/slice-4-triage.md` |
| Location | Precise GPS, in-app; lazy place names | `docs/slices/slice-5-location.md` |
| Dev workflow | PRs only; branch → `/open-pr` → `/checkpoint-review` → merge; **agent auto-opens PRs then stops** — owner drives merges + error reports | `docs/dev-workflow.md` |
| Tracking | Backlog → **GitHub Issues**; `docs/` = decisions & specs only | `CLAUDE.md` |

Governing principle: **funnel, not archive** — no browsing/search/history.
Wave-specific non-goals (no type-based views, no type management UI, no
media picker, no note-content widgets, share amendment scoped to media-only):
`docs/prd/capture-wave.md` §9.

### Field notes — on-device issues (watch for recurrence)
- **Obsidian export "not landing" on first pass (2026-07-21, largely
  resolved):** guarded now by the "Saved to Obsidian" toast (*no toast =
  nothing landed*) and the foreground reconciler. Fingerprint + diagnostic
  checklist: **#25**.

---

## How to build & verify (learned the hard way)

### Local (the inner loop)
- **Full Xcode at `/Applications/Xcode.app`** (26.x); CLI builds need
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Run the tests:**
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -scheme Jackdaw -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:JackdawTests -derivedDataPath /tmp/jackdaw-derived
  ```
  (Real `-derivedDataPath` required; `Jackdaw` is a shared scheme, Test
  action scoped to `JackdawTests`.)
- **Test count: 76 `@Test` cases** (green on `PR CI`, 2026-07-22; unchanged —
  everything since has been docs-only). ExportTests 43, TriageTests 9,
  CaptureViewModelTests 8, LocationTests 6, Slice1VaultTests 6,
  CaptureServiceTests 3, JackdawTests 1.
- **STALE-BUILD GOTCHA:** multiple DerivedData dirs; always build with an
  explicit `-derivedDataPath` and install THAT `.app`.
- **Sim:** `xcrun simctl install/launch/io "iPhone 17" …`; bundle id
  `com.jimcodes.Jackdaw`; grant location via `simctl privacy`, set coords via
  `simctl location`.
- **Can't be automated headlessly:** typing, swipes, permission prompts, real
  GPS, TestFlight/signing — and the **S1 spike** (media-library permission +
  a real now-playing read) is in this category.

### CI/CD (Xcode Cloud — LIVE, owner-configured)
- **`PR CI`** on PR→`main`: build + `JackdawTests` (~3 min), **required
  status check**. Runs on all PRs including docs.
- **`TestFlight`** on merge→`main`: archive + distribute to Internal Testing
  (~15–20 min); skips docs-only merges (`docs/`, `.claude/`, `CLAUDE.md`).
- Repo pieces: shared `Jackdaw.xcscheme`, `ci_scripts/ci_post_clone.sh`
  (build number), `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`.
- **Guardrails:** cloud compute is owner-managed quota; **the agent never
  triggers or reconfigures Xcode Cloud.** Runbook:
  `docs/ci/xcode-cloud-setup.md`. `MARKETING_VERSION` = 1.0.1.

---

## Development workflow (how changes land)

- **PRs, not direct pushes to `main`** (branch-protected). Flow: branch →
  commit → `/open-pr` → `/checkpoint-review` → merge.
- **Agent PR automation:** the agent **auto-opens** the PR after a coherent
  push, then **stops** — no CI watching. The **owner** notifies of merges and
  reports CI/build errors back. See `docs/dev-workflow.md`.
- **ADR-first:** a real architectural decision gets its ADR ratified before
  its code (0007/0008 precede slices B/A accordingly; the media ADR precedes
  slice C and waits on S1).
- Commands: `/open-pr`, `/checkpoint-review`, `/handoff`, `/adr`, `/prd`.

---

## The tripod (personas) & memory

Three subagents in `.claude/agents/` — `product-lead`, `design-lead`,
`tech-lead` — own why/what, experience, how. Their committed memory in
`.claude/agent-memory/` now includes the **capture-wave position papers and
checkpoint-review takeaways** (the wave's full research trail — e.g. the
now-playing verdict with citations lives in
`tech-lead/now-playing-and-v1x-wave.md`). Re-invoke them in a fresh session;
they reload from memory. They also staff PR reviews (see the PR #28
checkpoint review for the pattern).

---

## What travels to a new/remote session — and what doesn't

**Travels (in git):** `CLAUDE.md`, everything in `docs/` (PRD incl.
`capture-wave.md`, ADRs 0001–0008, design, build-order, slices, dev-workflow,
CI runbook, this file), `.claude/agent-memory/`, `.claude/agents/`,
`.claude/commands/`, all code + tests, the shared `.xcscheme`, `ci_scripts/`.

**Backlog (on GitHub):** issues #17–#35 (see "Open issues" above) — any
session with repo access sees them.

**Does NOT travel:** Claude Code's machine-local auto-memory (this file is
the in-repo replacement); the conversation transcript; local DerivedData;
Xcode Cloud workflow config (lives in App Store Connect, owner-managed).

**Before switching sessions:** run `/handoff`, then **commit and push your
branch and open/update its PR** — a remote session only sees pushed commits;
changes land via PR, not direct pushes to `main`. The far side needs
**Xcode 26.x + the iOS 26 SDK** to build/verify (a sandbox without Xcode can
still edit code and drive the docs workflow — this handoff was written from
one).
