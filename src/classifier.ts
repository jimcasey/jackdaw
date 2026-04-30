import type { LocalChange, RemoteChange, LocalChangeType, RemoteChangeType, ClassifyAction, ClassifiedPath } from './sync-engine-types';
import type { SyncState } from './state-store';
import { gitBlobSha1 } from './hash';

// ClassifierLogger is sync so classify() callers can wrap an async logger inline
// (e.g. (e, d) => void logger.warn(e, d)).
export interface ClassifierLogger {
	warn(event: string, data?: Record<string, unknown>): void;
}

export async function classify(
	localChanges: Map<string, LocalChange>,
	remoteChanges: Map<string, RemoteChange>,
	_state: SyncState,
	logger?: ClassifierLogger,
): Promise<ClassifiedPath[]> {
	const allPaths = new Set([...localChanges.keys(), ...remoteChanges.keys()]);
	const result: ClassifiedPath[] = [];

	for (const path of allPaths) {
		const localChange = localChanges.get(path);
		const remoteChange = remoteChanges.get(path);
		const localType: LocalChangeType = localChange?.type ?? 'unchanged';
		const remoteType: RemoteChangeType = remoteChange?.type ?? 'unchanged';
		let action = resolveAction(localType, remoteType, path, logger);

		// §4.4 staleness: both sides differ from state but local content matches remote
		if (action === 'conflict' && localChange?.bytes && remoteChange?.blobSha) {
			const localBlobSha = await gitBlobSha1(localChange.bytes);
			if (localBlobSha === remoteChange.blobSha) {
				action = 'state-refresh';
			}
		}

		result.push({ path, action, local: localType, remote: remoteType });
	}

	return result;
}

function resolveAction(
	local: LocalChangeType,
	remote: RemoteChangeType,
	path: string,
	logger?: ClassifierLogger,
): ClassifyAction {
	if (local === 'unchanged') {
		// Remote drives: pull anything that changed, no-op if both unchanged
		if (remote === 'unchanged') return 'no-op';
		return 'pull';
	}

	if (local === 'added') {
		if (remote === 'unchanged') return 'push';
		// Both added: hash comparison (sha256 vs git blob sha1) deferred to pull phase
		if (remote === 'added') return 'conflict';
		// Impossible: path not in state, so remote can't be modified or deleted
		logger?.warn('classifier:impossible-cell', { path, local, remote });
		return 'no-op';
	}

	if (local === 'modified') {
		if (remote === 'unchanged') return 'push';
		// Impossible: path in state, so remote can't be newly added
		if (remote === 'added') {
			logger?.warn('classifier:impossible-cell', { path, local, remote });
			return 'no-op';
		}
		// Both modified or local modified + remote deleted
		return 'conflict';
	}

	// local === 'deleted'
	if (remote === 'unchanged') return 'push';
	if (remote === 'deleted') return 'no-op';
	// Impossible: path in state, so remote can't be newly added
	if (remote === 'added') {
		logger?.warn('classifier:impossible-cell', { path, local, remote });
		return 'no-op';
	}
	// remote === 'modified'
	return 'conflict';
}
