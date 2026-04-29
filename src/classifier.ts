import type { LocalChange, RemoteChange, LocalChangeType, RemoteChangeType, ClassifyAction, ClassifiedPath } from './sync-engine-types';
import type { SyncState } from './state-store';

export interface ClassifierLogger {
	warn(event: string, data?: Record<string, unknown>): void;
}

export function classify(
	localChanges: Map<string, LocalChange>,
	remoteChanges: Map<string, RemoteChange>,
	_state: SyncState,
	logger?: ClassifierLogger,
): ClassifiedPath[] {
	const allPaths = new Set([...localChanges.keys(), ...remoteChanges.keys()]);
	const result: ClassifiedPath[] = [];

	for (const path of allPaths) {
		const localType: LocalChangeType = localChanges.get(path)?.type ?? 'unchanged';
		const remoteType: RemoteChangeType = remoteChanges.get(path)?.type ?? 'unchanged';
		const action = resolveAction(localType, remoteType, path, logger);
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
