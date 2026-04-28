# Phase 1 Planning — Core Libraries

**Date:** 2026-04-28
**Milestone:** Phase 1 — Core libs
**Modules in scope:** `src/github-client.ts`, `src/state-store.ts`, `src/logger.ts`, plus supporting `src/hash.ts`, `src/settings.ts`, `src/constants.ts`

---

## Goal

Build the three foundation libraries that the Phase 2 sync engine will compose: a GitHub REST client, a state store for `sync-state.json`, and a JSONL logger. None of these modules know anything about the sync algorithm — they are pure libraries with unit-tested public surfaces.

---

## Decisions

### Test runner: Vitest

Phase 1 deliverables are pure libraries whose value is measured by unit tests. Phase 2's §5.5 classifier matrix is also untestable without a runner. Picked Vitest over Jest for ESM-native support and faster startup. Wired into CI alongside `lint` and `typecheck`.

### GitHub client split into two PRs

The §6.1 surface plus retries, error taxonomy, header injection, and chunked base64 encoding is a lot of code for a single review. Split into:

1. **Transport layer** — `request()` private method, auth, retries, errors, rate-limit handling, chunked base64 helper.
2. **REST methods** — thin wrappers (`getBranch`, `getTree`, `getBlob`, `createBlob`, `createTree`, `createCommit`, `updateRef`) on top of the transport.

Both ship as separate small PRs against the same module file. The second issue depends on the first.

### Settings type pinned in Phase 1

Other Phase 1 modules (especially the GitHub client) need a typed view of settings. Defining the `Settings` interface and `DEFAULT_SETTINGS` in `src/settings.ts` now means Phase 3's UI work just reads/writes the same shape — no refactor of the consumers when the UI lands.

### Self-exclusion constants in `src/constants.ts`

`SELF_EXCLUDED_PATHS` (the plugin's own `data.json`, `sync-state.json`, `sync.log` and their tmp/rotation siblings) and `BINARY_EXTENSIONS` (per §4.3) live in a leaf `constants.ts` so the future file scanner (Phase 2) can import without circular dependencies on `state-store` or `logger`.

### Hash utilities as a separate module

`sha256` and `gitBlobSha1` are used by both `state-store` (content hashing) and the future engine (first-sync identical detection per §7). A small `src/hash.ts` keeps them out of the consumers' bundles and makes their fixture tests trivial.

---

## Issues created

Phase 1 work (`phase: 1`):

1. **#18** — Add Vitest test runner and wire into CI *(chore)*
2. **#19** — Define Settings type and self-exclusion constants *(chore)*
3. **#20** — Hash utilities (`src/hash.ts`) *(feature)*
4. **#21** — Logger (`src/logger.ts`) — JSONL with rotation and PAT scrubbing *(feature)*
5. **#22** — State store (`src/state-store.ts`) — atomic `sync-state.json` with `.tmp` recovery *(feature)*
6. **#23** — GitHub client transport layer *(feature)*
7. **#24** — GitHub REST methods on top of transport *(feature; depends on #23)*
8. **#26** — Phase 1 retrospective — update docs and design spec with findings *(docs; closes the phase)*

Phase 2 prep (`needs: planning`):

9. **#25** — (planning) Handle `.git` folder exclusion when a vault is inside a git working tree

### Recommended order

Issues #18 and #19 unblock everything else. After those, #20–#22 can run in parallel. #23 must land before #24. #26 runs last, before the Phase 2 milestone opens. #25 is a planning placeholder for a future session.

---

## Open questions deferred

- **`.git/` exclusion** (issue #25) — needs its own planning session before Phase 2's file scanner. Decisions on hard-exclude vs default-exclude, UX on detection, and performance of skipping a large `.git/` are all unresolved.
- **Schema migrations** — Phase 1 ships `SCHEMA_VERSION = 1` and a forward-compat hook (mismatch returns `null`, logs a warning). No actual migrations until v1.1+.
- **Pretty vs minified state file** — `state-store.save()` takes a constructor flag. The decision on whether release builds default to minified, and how that flag is wired, can wait for the Phase 3 settings work or earlier if it surfaces during Phase 1 implementation.

---

## Definition of done for Phase 1

- All eight Phase 1 issues (#18–#24, #26) closed.
- `npm test`, `npm run lint`, `npm run typecheck` all pass on `main`.
- Each module has unit tests covering the acceptance criteria in its issue.
- Issue #26 (retrospective) confirms `docs/design-specification.md` and `CLAUDE.md` reflect what was actually built, and any divergences have follow-up issues.

---

## Human gates remaining for Phase 1

Per `docs/human-interactions.md`:

1. **Phase planning sign-off** — review this summary and the eight issues; assign milestones; confirm readiness.
2. **Per-PR review** — for each of the eight Phase 1 PRs: read `/review` findings, review the diff, squash-merge.
3. **Phase gate** — confirm Phase 1 is done before requesting Phase 2 planning.
