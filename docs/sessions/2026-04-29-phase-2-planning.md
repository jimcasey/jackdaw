# Phase 2 Planning — Sync Engine

**Date:** 2026-04-29
**Milestone:** Phase 2 — Sync engine
**Modules in scope:** `src/sync-engine.ts`

---

## Goal

Implement the sync engine that drives a single user-initiated sync. Phase 2 delivers a fully-testable engine with no Obsidian dependency (all vault I/O injected via interface). Phase 3 wires the ribbon/UI. Phase 4 adds the modals.

---

## Decisions

### VaultAdapter interface (mirror of StateAdapter pattern)

The sync engine takes a `VaultAdapter` rather than `app.vault` directly — the same pattern that `StateStore` uses for `StateAdapter`. This enables unit tests with no Obsidian environment. The production implementation wraps `app.vault` + `app.vault.adapter`. Benefit: the entire sync algorithm can be exercised in Node/Vitest without an Obsidian instance.

### Injectable resolver interfaces

Two places in the engine require user interaction:

- **`ConflictResolver`** — called when ordinary sync detects conflicts (§5.6). Phase 4 provides the modal; Phase 2 ships a `PolicyBasedResolver` stub.
- **`FirstSyncResolver`** — called for the mass-conflict flow (§7). Same shape, same deferral.

`PolicyBasedResolver` handles `always-prefer-local` and `always-prefer-remote` without a modal. When `conflictPolicy === 'always-ask'` and no modal is wired up, it throws `SyncNeedsUIError` — a typed sentinel the caller can surface as a human-readable notice.

This keeps the engine decoupled from Obsidian UI while still being usable in Phase 3 for the common case (no conflicts, or auto-resolve policies).

### Classifier as a pure function

The §5.5 4×4 matrix lives in a standalone `classify()` function — pure, no I/O, no side effects. This makes it trivially unit-testable (every cell, in one test file) and gives the AI reviewer a clear correctness target.

### First-sync algorithm is Phase 2; modal is Phase 4

The §7 cross-classification (local-only / remote-only / identical / conflict) is engine logic, not UI logic. It belongs in Phase 2. The `FirstSyncResolver` interface defers the modal to Phase 4. The engine is complete without the modal: it just can't handle first-sync when `conflictPolicy === 'always-ask'`.

### Blob creation is always serial

Per §5.8 — GitHub's secondary rate limit tolerates serial creation and rejects concurrent bursts. This is a hard constraint, not a convenience. The push phase issues blob uploads one at a time.

### Max 2 retries on fast-forward failure

On `GHFastForwardError` (422 from `updateRef`), the engine re-runs the full sync from the remote-head fetch (step 3 of the state machine). Maximum two retries across a single `sync()` invocation. After two failures, surface an error.

### Local bytes kept in-memory from scan through push

`LocalChange.bytes` is populated during the local scan and reused by the push phase. This avoids re-reading files. The trade-off is higher peak memory use, which is acceptable for v1's target vault profile (few thousand notes, individual files < 25 MB).

### Device name fallback

`os.hostname()` is unreliable in Obsidian's iOS webview. The commit message formatter uses `settings.deviceName` if set, and falls back to `'Obsidian'` rather than trying to detect the hostname. The Phase 3 settings tab will expose the device name field.

---

## Issues created

Phase 2 work (`phase: 2`):

| # | Title | Type | Depends on |
|---|---|---|---|
| #36 | `.git/` hard-exclusion + `.gitignore` support *(pre-existing)* | feature | — |
| #39 | Sync engine types and interfaces | chore | — |
| #40 | Classifier (§5.5 matrix) | feature | #39 |
| #41 | Local change set builder | feature | #36, #39 |
| #42 | Remote change set builder | feature | #39 |
| #43 | Pull phase | feature | #39 |
| #44 | Push phase and commit message formatter | feature | #39 |
| #45 | First-sync cross-classifier (§7) | feature | #39 |
| #46 | SyncEngine orchestrator | feature | #36, #39–#45 |
| #47 | Phase 2 retrospective | docs | #46 |

### Recommended order

Issue #39 (types) unblocks everything else and should land first.

After #39, issues #36, #40, #42, #43, #44, and #45 can run in parallel — they are independent of each other.

Issue #41 (local scanner) depends on both #36 (exclusion filter) and #39 (types).

Issue #46 (orchestrator) depends on all preceding issues. It is the integration point.

Issue #47 (retrospective) runs last.

---

## Open questions deferred

- **Integration tests (§11.2)** — deferred to Phase 5 (BRAT release). The scenarios require a CI-owned GitHub account and fresh branches per run; wiring this up during Phase 2 would slow down implementation. Phase 5 is the right time.
- **Per-directory `.gitignore` support** — explicitly out of scope for v1 per ADR 002. If users request it, it becomes a v1.1 issue.
- **`always-ask` conflict policy before Phase 4** — users who set `conflictPolicy: 'always-ask'` will encounter `SyncNeedsUIError` until Phase 4 ships the modals. This is acceptable; the settings tab (Phase 3) can note that the conflict modal requires a future update, or we can default-disable `always-ask` in the UI until Phase 4.
- **Obsidian's vault create vs modify API** — the `VaultAdapter` interface wraps both as `writeText`/`writeBinary`. The production implementation handles the `vault.create` vs `vault.modify` distinction. This detail is left to the Phase 3 wiring work.

---

## Definition of done for Phase 2

- All Phase 2 issues (#36, #39–#47) closed.
- `npm test` covers every cell of the §5.5 classifier matrix.
- `npm run lint` and `npm run typecheck` pass on `main`.
- `SyncEngine` is constructable and invocable in a unit test environment (no Obsidian dependency).
- Issue #47 (retrospective) confirms `docs/design-specification.md` and `CLAUDE.md` reflect what was actually built.

---

## Human gates remaining for Phase 2

Per `docs/human-interactions.md`:

1. **Phase planning sign-off** — review this summary and the ten issues; confirm readiness.
2. **Per-PR review** — for each Phase 2 PR: read `/review` findings (with focus on classifier matrix coverage and retry logic per workflow.md Phase 2 guidance), review the diff, squash-merge.
3. **Phase gate** — confirm Phase 2 is done before requesting Phase 3 planning.
