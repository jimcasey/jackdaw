import { describe, test, expect, vi, type Mock } from 'vitest';
import { applyPull, type PullLogger } from '../src/apply-pull';
import { SyncStateInconsistencyError } from '../src/sync-engine-types';
import type { ClassifiedPath, VaultAdapter } from '../src/sync-engine-types';
import type { RemoteChange } from '../src/sync-engine-types';
import type { SyncState } from '../src/state-store';
import type { Settings } from '../src/settings';
import type { GitHubClient } from '../src/github-client';
import { sha256 } from '../src/hash';

function toBytes(s: string): ArrayBuffer {
	return new TextEncoder().encode(s).buffer as ArrayBuffer;
}

interface MockClient {
	getBlob: Mock;
}

function makeClient(): MockClient {
	return { getBlob: vi.fn() };
}

function asClient(mock: MockClient): GitHubClient {
	return mock as unknown as GitHubClient;
}

interface MockVault {
	readBinary: Mock;
	readText: Mock;
	writeText: Mock;
	writeBinary: Mock;
	delete: Mock;
	listFiles: Mock;
	listDirectory: Mock;
	exists: Mock;
}

function makeVault(): MockVault {
	return {
		readBinary: vi.fn(),
		readText: vi.fn(),
		writeText: vi.fn().mockResolvedValue(undefined),
		writeBinary: vi.fn().mockResolvedValue(undefined),
		delete: vi.fn().mockResolvedValue(undefined),
		listFiles: vi.fn(),
		listDirectory: vi.fn(),
		exists: vi.fn(),
	};
}

function asVault(mock: MockVault): VaultAdapter {
	return mock as unknown as VaultAdapter;
}

function makeLogger(): MockLogger & PullLogger {
	return {
		debug: vi.fn().mockResolvedValue(undefined),
		warn: vi.fn().mockResolvedValue(undefined),
		error: vi.fn().mockResolvedValue(undefined),
	};
}

interface MockLogger {
	debug: Mock;
	warn: Mock;
	error: Mock;
}

function makeState(overrides: Partial<SyncState> = {}): SyncState {
	return {
		schemaVersion: 1,
		lastSyncCommitSha: 'abc123',
		lastSyncAt: '2026-04-29T00:00:00.000Z',
		files: {},
		...overrides,
	};
}

function makeSettings(overrides: Partial<Settings> = {}): Settings {
	return {
		owner: 'test-owner',
		repo: 'test-repo',
		branch: 'main',
		pat: 'test-pat',
		conflictPolicy: 'always-ask',
		perFileSizeLimitMb: 25,
		deviceName: 'test',
		includeObsidianConfig: false,
		excludePatterns: [],
		verboseLogging: false,
		...overrides,
	};
}

function makeClassified(
	path: string,
	action: ClassifiedPath['action'],
	remote: ClassifiedPath['remote'],
	local: ClassifiedPath['local'] = 'unchanged',
): ClassifiedPath {
	return { path, action, remote, local };
}

describe('applyPull', () => {
	test('remote-added text file: fetches blob, writes text, updates state', async () => {
		const path = 'notes/hello.md';
		const blobSha = 'blob-sha-abc';
		const content = 'Hello, world!';
		const bytes = toBytes(content);

		const client = makeClient();
		client.getBlob.mockResolvedValue(bytes);
		const vault = makeVault();
		const logger = makeLogger();
		const state = makeState();
		const settings = makeSettings();

		const remote = new Map<string, RemoteChange>([
			[path, { path, type: 'added', blobSha, size: bytes.byteLength, isBinary: false }],
		]);
		const paths = [makeClassified(path, 'pull', 'added')];

		const result = await applyPull(paths, remote, asClient(client), asVault(vault), state, settings, logger);

		expect(client.getBlob).toHaveBeenCalledWith('test-owner', 'test-repo', blobSha);
		expect(vault.writeText).toHaveBeenCalledWith(path, content);
		expect(vault.writeBinary).not.toHaveBeenCalled();

		const expectedHash = await sha256(bytes);
		expect(result.updatedState.files[path]).toEqual({
			path,
			blobSha,
			contentHash: expectedHash,
			size: bytes.byteLength,
			isBinary: false,
		});
		expect(result.skipped).toEqual([]);
	});

	test('remote-modified binary file: fetches blob, writes binary, updates state', async () => {
		const path = 'images/photo.png';
		const blobSha = 'blob-sha-binary';
		const bytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47]).buffer as ArrayBuffer;

		const client = makeClient();
		client.getBlob.mockResolvedValue(bytes);
		const vault = makeVault();
		const logger = makeLogger();
		const state = makeState({
			files: {
				[path]: { path, blobSha: 'old-blob-sha', contentHash: 'old-hash', size: 100, isBinary: true },
			},
		});
		const settings = makeSettings();

		const remote = new Map<string, RemoteChange>([
			[path, { path, type: 'modified', blobSha, size: bytes.byteLength, isBinary: true }],
		]);
		const paths = [makeClassified(path, 'pull', 'modified')];

		const result = await applyPull(paths, remote, asClient(client), asVault(vault), state, settings, logger);

		expect(client.getBlob).toHaveBeenCalledWith('test-owner', 'test-repo', blobSha);
		expect(vault.writeBinary).toHaveBeenCalledWith(path, bytes);
		expect(vault.writeText).not.toHaveBeenCalled();

		const expectedHash = await sha256(bytes);
		expect(result.updatedState.files[path]).toEqual({
			path,
			blobSha,
			contentHash: expectedHash,
			size: bytes.byteLength,
			isBinary: true,
		});
		expect(result.skipped).toEqual([]);
	});

	test('remote-deleted with matching hash: deletes file, clears state entry', async () => {
		const path = 'notes/old.md';
		const content = 'Old content';
		const bytes = toBytes(content);
		const contentHash = await sha256(bytes);

		const client = makeClient();
		const vault = makeVault();
		vault.readBinary.mockResolvedValue(bytes);
		const logger = makeLogger();
		const state = makeState({
			files: {
				[path]: { path, blobSha: 'old-blob', contentHash, size: bytes.byteLength, isBinary: false },
			},
		});
		const settings = makeSettings();

		const remote = new Map<string, RemoteChange>([
			[path, { path, type: 'deleted', size: 0, isBinary: false }],
		]);
		const paths = [makeClassified(path, 'pull', 'deleted')];

		const result = await applyPull(paths, remote, asClient(client), asVault(vault), state, settings, logger);

		expect(vault.readBinary).toHaveBeenCalledWith(path);
		expect(vault.delete).toHaveBeenCalledWith(path);
		expect(result.updatedState.files[path]).toBeUndefined();
		expect(client.getBlob).not.toHaveBeenCalled();
		expect(result.skipped).toEqual([]);
	});

	test('remote-deleted with mismatched hash: throws SyncStateInconsistencyError', async () => {
		const path = 'notes/changed.md';
		const originalBytes = toBytes('original content');
		const originalHash = await sha256(originalBytes);
		const modifiedBytes = toBytes('locally modified content');

		const client = makeClient();
		const vault = makeVault();
		vault.readBinary.mockResolvedValue(modifiedBytes);
		const logger = makeLogger();
		const state = makeState({
			files: {
				[path]: { path, blobSha: 'old-blob', contentHash: originalHash, size: originalBytes.byteLength, isBinary: false },
			},
		});
		const settings = makeSettings();

		const remote = new Map<string, RemoteChange>([
			[path, { path, type: 'deleted', size: 0, isBinary: false }],
		]);
		const paths = [makeClassified(path, 'pull', 'deleted')];

		await expect(
			applyPull(paths, remote, asClient(client), asVault(vault), state, settings, logger),
		).rejects.toThrow(SyncStateInconsistencyError);

		expect(vault.delete).not.toHaveBeenCalled();
		expect(logger.error).toHaveBeenCalled();
	});

	test('file exceeding size limit: added to skipped, blob not fetched', async () => {
		const path = 'large/video.mp4';
		const blobSha = 'blob-sha-large';
		const sizeBytes = 30 * 1024 * 1024; // 30 MB, exceeds 25 MB limit

		const client = makeClient();
		const vault = makeVault();
		const logger = makeLogger();
		const state = makeState();
		const settings = makeSettings({ perFileSizeLimitMb: 25 });

		const remote = new Map<string, RemoteChange>([
			[path, { path, type: 'added', blobSha, size: sizeBytes, isBinary: true }],
		]);
		const paths = [makeClassified(path, 'pull', 'added')];

		const result = await applyPull(paths, remote, asClient(client), asVault(vault), state, settings, logger);

		expect(client.getBlob).not.toHaveBeenCalled();
		expect(vault.writeBinary).not.toHaveBeenCalled();
		expect(result.skipped).toEqual([path]);
		expect(logger.warn).toHaveBeenCalled();
		expect(result.updatedState.files[path]).toBeUndefined();
	});
});
