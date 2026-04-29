import { describe, test, expect, vi } from 'vitest';
import { classify } from '../src/classifier';
import type { LocalChange, RemoteChange } from '../src/sync-engine-types';
import type { SyncState } from '../src/state-store';

// Minimal SyncState for tests — classify() doesn't read state fields
const EMPTY_STATE: SyncState = {
	schemaVersion: 1,
	lastSyncCommitSha: 'abc123',
	lastSyncAt: '2026-01-01T00:00:00Z',
	files: {},
};

function makeLocal(path: string, type: LocalChange['type'], contentHash = 'hash-local'): Map<string, LocalChange> {
	return new Map([[path, { path, type, contentHash, size: 10, isBinary: false }]]);
}

function makeRemote(path: string, type: RemoteChange['type'], blobSha = 'blobsha-remote'): Map<string, RemoteChange> {
	return new Map([[path, { path, type, blobSha, size: 10, isBinary: false }]]);
}

function makeLogger() {
	return { warn: vi.fn<[string, (Record<string, unknown> | undefined)?], void>() };
}

const EMPTY = new Map<string, LocalChange>();
const EMPTY_REMOTE = new Map<string, RemoteChange>();

// ─── Row: local=unchanged ───────────────────────────────────────────────────

test('(unchanged, unchanged) — no-op (path in neither map, not returned)', () => {
	// A path in neither map is never included in the result
	const result = classify(EMPTY, EMPTY_REMOTE, EMPTY_STATE);
	expect(result).toHaveLength(0);
});

test('(unchanged, added) — pull', () => {
	const result = classify(EMPTY, makeRemote('a.md', 'added'), EMPTY_STATE);
	expect(result).toHaveLength(1);
	expect(result[0]).toMatchObject({ path: 'a.md', action: 'pull', local: 'unchanged', remote: 'added' });
});

test('(unchanged, modified) — pull', () => {
	const result = classify(EMPTY, makeRemote('a.md', 'modified'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'pull', local: 'unchanged', remote: 'modified' });
});

test('(unchanged, deleted) — pull', () => {
	const result = classify(EMPTY, makeRemote('a.md', 'deleted'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'pull', local: 'unchanged', remote: 'deleted' });
});

// ─── Row: local=added ────────────────────────────────────────────────────────

test('(added, unchanged) — push', () => {
	const result = classify(makeLocal('a.md', 'added'), EMPTY_REMOTE, EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'push', local: 'added', remote: 'unchanged' });
});

test('(added, added) — conflict (hash comparison deferred to pull phase)', () => {
	const result = classify(makeLocal('a.md', 'added', 'hash-x'), makeRemote('a.md', 'added', 'blobsha-x'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'conflict', local: 'added', remote: 'added' });
});

test('(added, added) always conflict — sha256 vs git blob sha1 cannot be compared without I/O', () => {
	// Hash comparison (same-content escape) is deferred to the pull phase; classifier has no I/O
	const result = classify(makeLocal('a.md', 'added', 'hash-a'), makeRemote('a.md', 'added', 'hash-b'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'conflict' });
});

test('(added, modified) — impossible: logs warning and returns no-op', () => {
	const logger = makeLogger();
	const result = classify(makeLocal('a.md', 'added'), makeRemote('a.md', 'modified'), EMPTY_STATE, logger);
	expect(result[0]).toMatchObject({ action: 'no-op', local: 'added', remote: 'modified' });
	expect(logger.warn).toHaveBeenCalledWith('classifier:impossible-cell', expect.objectContaining({ path: 'a.md' }));
});

test('(added, deleted) — impossible: logs warning and returns no-op', () => {
	const logger = makeLogger();
	const result = classify(makeLocal('a.md', 'added'), makeRemote('a.md', 'deleted'), EMPTY_STATE, logger);
	expect(result[0]).toMatchObject({ action: 'no-op', local: 'added', remote: 'deleted' });
	expect(logger.warn).toHaveBeenCalledWith('classifier:impossible-cell', expect.objectContaining({ path: 'a.md' }));
});

// ─── Row: local=modified ─────────────────────────────────────────────────────

test('(modified, unchanged) — push', () => {
	const result = classify(makeLocal('a.md', 'modified'), EMPTY_REMOTE, EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'push', local: 'modified', remote: 'unchanged' });
});

test('(modified, added) — impossible: logs warning and returns no-op', () => {
	const logger = makeLogger();
	const result = classify(makeLocal('a.md', 'modified'), makeRemote('a.md', 'added'), EMPTY_STATE, logger);
	expect(result[0]).toMatchObject({ action: 'no-op', local: 'modified', remote: 'added' });
	expect(logger.warn).toHaveBeenCalledWith('classifier:impossible-cell', expect.objectContaining({ path: 'a.md' }));
});

test('(modified, modified) — conflict', () => {
	const result = classify(makeLocal('a.md', 'modified'), makeRemote('a.md', 'modified'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'conflict', local: 'modified', remote: 'modified' });
});

test('(modified, deleted) — conflict', () => {
	const result = classify(makeLocal('a.md', 'modified'), makeRemote('a.md', 'deleted'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'conflict', local: 'modified', remote: 'deleted' });
});

// ─── Row: local=deleted ──────────────────────────────────────────────────────

test('(deleted, unchanged) — push', () => {
	const result = classify(makeLocal('a.md', 'deleted'), EMPTY_REMOTE, EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'push', local: 'deleted', remote: 'unchanged' });
});

test('(deleted, added) — impossible: logs warning and returns no-op', () => {
	const logger = makeLogger();
	const result = classify(makeLocal('a.md', 'deleted'), makeRemote('a.md', 'added'), EMPTY_STATE, logger);
	expect(result[0]).toMatchObject({ action: 'no-op', local: 'deleted', remote: 'added' });
	expect(logger.warn).toHaveBeenCalledWith('classifier:impossible-cell', expect.objectContaining({ path: 'a.md' }));
});

test('(deleted, modified) — conflict', () => {
	const result = classify(makeLocal('a.md', 'deleted'), makeRemote('a.md', 'modified'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'conflict', local: 'deleted', remote: 'modified' });
});

test('(deleted, deleted) — no-op', () => {
	const result = classify(makeLocal('a.md', 'deleted'), makeRemote('a.md', 'deleted'), EMPTY_STATE);
	expect(result[0]).toMatchObject({ action: 'no-op', local: 'deleted', remote: 'deleted' });
});

// ─── Multiple paths ───────────────────────────────────────────────────────────

test('multiple paths are each classified independently', () => {
	const localChanges: Map<string, LocalChange> = new Map([
		['added.md', { path: 'added.md', type: 'added', contentHash: 'h1', size: 5, isBinary: false }],
		['modified.md', { path: 'modified.md', type: 'modified', contentHash: 'h2', size: 5, isBinary: false }],
	]);
	const remoteChanges: Map<string, RemoteChange> = new Map([
		['remote-added.md', { path: 'remote-added.md', type: 'added', blobSha: 'b1', size: 5, isBinary: false }],
	]);

	const result = classify(localChanges, remoteChanges, EMPTY_STATE);
	expect(result).toHaveLength(3);

	const byPath = Object.fromEntries(result.map(r => [r.path, r]));
	expect(byPath['added.md'].action).toBe('push');
	expect(byPath['modified.md'].action).toBe('push');
	expect(byPath['remote-added.md'].action).toBe('pull');
});

test('no logger provided for impossible cell: still returns no-op without throwing', () => {
	const result = classify(makeLocal('a.md', 'added'), makeRemote('a.md', 'modified'), EMPTY_STATE);
	expect(result[0].action).toBe('no-op');
});
