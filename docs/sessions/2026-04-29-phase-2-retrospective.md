# Phase 2 Retrospective — Sync Engine

**Date:** 2026-04-29
**Milestone:** Phase 2 — Sync engine
**Issues closed:** #36, #39–#46

---

## 1. What was built

All nine implementation issues shipped. The table below summarises each module, its issue, its test file, and its test count.

| Module | Issue | LOC | Tests | Notes |
|---|---|---|---|---|
| `src/file-scanner.ts` | #36 | 120 | 20 | `FileScanner` class; `.gitignore` parse + glob compiler; `.git/` directory-level exclusion |
| `src/sync-engine-types.ts` | #39 | 115 | — | Shared type file: `LocalChange`, `RemoteChange`, `ClassifiedPath`, `ConflictItem`, `FirstSyncSummary`, `SyncReport`, `SyncResult`, `VaultAdapter`, `ConflictResolver`, `FirstSyncResolver`, `PolicyBasedResolver`, `SyncStateInconsistencyError`, `SyncNeedsUIError` |
| `src/classifier.ts` | #40 | 71 | 20 | Pure `classify()` function; full 4×4 §5.5 matrix; impossible cells logged and returned as no-op |
| `src/local-change-set.ts` | #41 | 64 | 12 | `buildLocalChangeSet()`; delegates scanning to `FileScanner`; computes SHA-256; identifies deletions from state |
| `src/remote-change-set.ts` | #42 | 82 | 10 | `buildRemoteChangeSet()`; recursive tree fetch; truncated-tree fallback via BFS subtree walk |
| `src/apply-pull.ts` | #43 | 77 | 6 | `applyPull()`; size-limit skip; binary/text branch; remote-deleted hash guard; `SyncStateInconsistencyError` on mismatch |
| `src/apply-push.ts` | #44 | 118 | 9 | `applyPush()` + `formatCommitMessage()`; serial blob creation; 50-file truncation in commit message |
| `src/first-sync.ts` | #45 | 73 | 13 | `buildLocalInventory()` + `buildFirstSyncSummary()`; `gitBlobSha1()` used for identical-file detection without download |
| `src/sync-engine.ts` | #46 | 361 | 43 | `SyncEngine` orchestrator; pre-flight; sync lock; normal sync loop; GHFastForwardError retry (max 2); first-sync branch; logging |

**Quality gates at close:**
- `npm test`: 187 tests, 13 files, all pass
- `npm run lint`: no findings
- `npm run typecheck`: no errors
- `SyncEngine` is constructable and invocable in Vitest with zero Obsidian imports

---

## 2. Divergences from the design spec

### 2.1 Multiple narrow logger interfaces instead of one

**Spec:** §3 and §9 imply a single `Logger` class is used everywhere. §6.1 defines a minimal `GHLogger` (warn only) for the GitHub client.

**What shipped:** Five distinct logger interfaces, each scoped to its module:
- `Logger` in `state-store.ts` (info + warn)
- `ClassifierLogger` in `classifier.ts` (warn only, synchronous)
- `PullLogger` in `apply-pull.ts` (debug + warn + error)
- `PushLogger` in `apply-push.ts` (debug only)
- `SyncLogger` in `sync-engine.ts` (debug + info + warn + error)

**Resolution:** All five are duck-typed; the `Logger` from `src/logger.ts` satisfies every one of them. Splitting per-module keeps each file self-contained and testable without importing the real logger. No spec update needed — this is an implementation detail below the spec's level of detail.

### 2.2 `sync-engine-types.ts` as a dedicated shared type file

**Spec:** §3 does not mention a separate types module; types are documented inline with their owning module.

**What shipped:** Issue #39 created `src/sync-engine-types.ts` as an explicit shared contract file so that `classifier.ts`, `apply-pull.ts`, `apply-push.ts`, and `first-sync.ts` can all import from a single canonical source without circular dependencies.

**Resolution:** Good architectural decision; CLAUDE.md §Architecture was updated when #39 landed. No further action needed.

### 2.3 `PolicyBasedResolver` implements both resolver interfaces

**Spec:** §7 and §8.4 describe the first-sync resolver and conflict resolver as separate modal flows. The spec doesn't specify a shared policy-based implementation.

**What shipped:** `PolicyBasedResolver` in `sync-engine-types.ts` implements both `ConflictResolver` and `FirstSyncResolver`. When `conflictPolicy === 'always-ask'` it throws `SyncNeedsUIError` rather than trying to open a modal. This keeps the engine functional for `always-prefer-local` and `always-prefer-remote` users before Phase 4 ships the modals.

**Resolution:** Intentional design (documented in Phase 2 planning). The Phase 4 modal classes will implement the same two interfaces and be injected in place of `PolicyBasedResolver`. No spec update needed.

### 2.4 Staleness detection (§4.4) not implemented

**Spec:** §4.4 ¶3 describes a staleness pattern: when local content matches remote content despite both differing from the state record (caused by Obsidian Sync delivering a stale `sync-state.json` to a second device). The classifier should detect this and treat as a no-op.

**What shipped:** The `classify()` function accepts a `_state` parameter but does not use it. The parameter is prefixed with `_` and carries an inline comment: `reserved — staleness comparison (§4.4) is deferred to the pull phase`. The pull phase also does not implement the comparison.

**Resolution:** Create a follow-up issue. The staleness case is low-frequency (requires two Obsidian Sync devices syncing faster than Obsidian Sync propagates state) and the consequence of missing it is an unnecessary conflict prompt rather than data loss. Safe to defer to Phase 3 or a dedicated follow-up.

### 2.5 Remote-deleted + local hash mismatch raises an error, not a conflict

**Spec:** §5.7: "If hash mismatch, treat as a conflict that should have been caught earlier; bail and report."

**What shipped:** `applyPull` throws `SyncStateInconsistencyError` which bubbles through the engine's `catch` block and is returned as `{ status: 'error', error }`. This is "bail and report" but surfaced as an error rather than a UI conflict.

**Resolution:** The spec's phrasing is ambiguous ("treat as a conflict... bail and report"). An error return is the correct observable behaviour — there is no clean pull path for this file because the local bytes are unknown to the resolver. The spec will be clarified in a minor wording update: "bail and surface as a sync error."

### 2.6 `applyPush` early-return when `paths` is empty

**Spec:** §5.8 says the engine should "skip the push entirely and update `lastSyncCommitSha` to the current remote head" when no local changes remain.

**What shipped:** When `paths.length === 0`, `applyPush` returns `{ newCommitSha: remoteHeadSha, updatedState: state }` immediately without calling any API. The engine handles the `lastSyncCommitSha` update in its own no-push branch. The spec's responsibility split is therefore: engine decides *whether* to push, `applyPush` handles *how*. The implementation is correct; the spec is silent on this boundary.

**Resolution:** No change needed. The split is a natural internal boundary.

### 2.7 `VaultAdapter` provides `writeText` + `writeBinary` (not `vault.create`/`vault.modify`)

**Spec:** §5.7 mentions `vault.modify`, `vault.create`, `vault.modifyBinary`, `vault.createBinary` as the Obsidian APIs to use.

**What shipped:** `VaultAdapter` exposes a single `writeText(path, content)` and `writeBinary(path, content)`, abstracting the create-vs-modify distinction. The production implementation (to be wired in Phase 3) will map these to the correct Obsidian APIs.

**Resolution:** Noted in Phase 2 planning as intentional. The production `VaultAdapter` implementation is Phase 3 work. No spec update needed.

---

## 3. Surprising decisions and patterns to carry into Phase 3

**Pure classifier with a synchronous logger.** The `classify()` function is stateless and side-effect-free, which made it trivially testable (every cell of the 4×4 matrix in one file). The trade-off — a synchronous `ClassifierLogger` that callers must wrap — is minor. Prefer this pattern for any logic that can be expressed purely.

**Duck-typed logger interfaces per module.** Keeping each module's logger interface minimal (only the methods it actually calls) means test stubs are three-liners. Carry this into Phase 3 UI modules.

**`bytes` carried in `LocalChange` from scan through push.** Loading file bytes once during the local scan and keeping them in memory avoids re-reads during push. For Phase 3, the production `VaultAdapter` should mirror this: scan once, write once, no redundant reads.

**`PolicyBasedResolver` as a Phase 4 seam.** The injected resolver pattern works cleanly. Phase 3 can ship the ribbon and settings tab without Phase 4's modals because `PolicyBasedResolver` handles the auto-resolve policies. Phase 4 only needs to provide concrete modal implementations of the same interfaces.

**Truncated remote tree fallback as BFS.** The `buildRemoteChangeSet` fallback for `truncated: true` uses a visited-set BFS, not naive recursion. This is the right choice — deeply nested vaults are unlikely but the code is still safe.

---

## 4. Items explicitly deferred

| Item | Deferred to | Notes |
|---|---|---|
| Staleness detection (§4.4) | Follow-up issue | Low-frequency edge case; no data-loss risk |
| Integration tests (§11.2) | Phase 5 | Requires CI-owned GitHub account and per-run fresh branches |
| Per-directory `.gitignore` | v1.1 | Explicitly out of scope per ADR 002 |
| UI ribbon, status bar, settings tab | Phase 3 | `SyncEngine` is wired up in Phase 3 |
| Conflict resolution modal | Phase 4 | `ConflictResolver` interface is the seam |
| First-sync modal | Phase 4 | `FirstSyncResolver` interface is the seam |
| `always-ask` conflict policy | Phase 4 | Throws `SyncNeedsUIError` until modal ships |
| Android unsupported marker | Phase 3 / release | Manifest and README note |
| Production `VaultAdapter` wrapping `app.vault` | Phase 3 | `writeText`/`writeBinary` → `vault.create`/`vault.modify` distinction |

---

## 5. Phase 3 readiness

**Confirmed.** All Phase 2 issues (#36, #39–#46) are closed. Quality gates pass: 187 tests green, lint clean, typecheck clean. `SyncEngine` is constructable and invocable in Vitest with no Obsidian dependency.

Phase 3 scope: ribbon icon wired to `SyncEngine.sync()`, settings tab, status bar, production `VaultAdapter` and `StateAdapter` implementations, and the `main.ts` plugin entry point. The engine, client, state store, and all sync logic are complete and need no changes to enable Phase 3.
