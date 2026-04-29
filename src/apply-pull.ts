import type { ClassifiedPath, VaultAdapter } from './sync-engine-types';
import type { RemoteChange } from './sync-engine-types';
import type { SyncState, SyncedFileRecord } from './state-store';
import type { Settings } from './settings';
import type { GitHubClient } from './github-client';
import { SyncStateInconsistencyError } from './sync-engine-types';
import { sha256 } from './hash';

export interface PullLogger {
	debug(event: string, data?: Record<string, unknown>): Promise<void>;
	warn(event: string, data?: Record<string, unknown>): Promise<void>;
	error(event: string, data?: Record<string, unknown>): Promise<void>;
}

export async function applyPull(
	paths: ClassifiedPath[],
	remote: Map<string, RemoteChange>,
	client: GitHubClient,
	vault: VaultAdapter,
	state: SyncState,
	settings: Settings,
	logger: PullLogger,
): Promise<{ updatedState: SyncState; skipped: string[] }> {
	const skipped: string[] = [];
	const sizeLimitBytes = settings.perFileSizeLimitMb * 1024 * 1024;

	for (const classified of paths) {
		const { path } = classified;
		const remoteChange = remote.get(path);
		if (!remoteChange || remoteChange.type === 'unchanged') continue;

		if (remoteChange.type === 'added' || remoteChange.type === 'modified') {
			if (remoteChange.size > sizeLimitBytes) {
				await logger.warn('sync.pull.file', { path, reason: 'size-limit', size: remoteChange.size });
				skipped.push(path);
				continue;
			}

			const bytes = await client.getBlob(settings.owner, settings.repo, remoteChange.blobSha!);

			if (remoteChange.isBinary) {
				await vault.writeBinary(path, bytes);
			} else {
				await vault.writeText(path, new TextDecoder().decode(bytes));
			}

			const contentHash = await sha256(bytes);
			const record: SyncedFileRecord = {
				path,
				blobSha: remoteChange.blobSha!,
				contentHash,
				size: remoteChange.size,
				isBinary: remoteChange.isBinary,
			};
			state.files[path] = record;

			await logger.debug('sync.pull.file', { path, type: remoteChange.type });
		} else {
			// remote-deleted
			const localBytes = await vault.readBinary(path);
			const localHash = await sha256(localBytes);

			if (localHash !== state.files[path]?.contentHash) {
				await logger.error('sync.pull.file', { path, reason: 'hash-mismatch' });
				throw new SyncStateInconsistencyError(path);
			}

			await vault.delete(path);
			delete state.files[path];

			await logger.debug('sync.pull.file', { path, type: 'deleted' });
		}
	}

	return { updatedState: state, skipped };
}
